import 'dart:async';
import 'dart:io';
import 'package:alarm_cycle/constant.dart';
import 'package:alarm_cycle/services/permission_requester_service.dart';
import 'package:alarm_cycle/views/screen_mixin.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_size/window_size.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'viewmodels/alarm_vm.dart';
import 'views/alarm_page.dart';

// Pour s'assurer que le service d'arrière-plan est initialisé correctement
@pragma('vm:entry-point')
void onStart(ServiceInstance service) {
  // Appeler la méthode statique dans AlarmVM
  AlarmVM.onStart(service);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  PermissionRequesterService.requestMultiplePermissions();

  // Initialiser le service en arrière-plan
  await initializeService();

  // Configuration des fenêtres pour les plateformes desktop
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await _setWindowsAppSizeAndPosition(
      isTest: false,
    );
  }

  runApp(ChangeNotifierProvider(
    create: (context) => AlarmVM(),
    child: const MyApp(),
  ));
}

// Initialisation du service en arrière-plan déplacée ici pour plus de clarté
Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  // Créer un canal de notification
  // Cette partie est importante pour Android 8.0+
  if (Platform.isAndroid) {
    try {
      // S'assurer que le canal est créé avant de lancer le service
      final AndroidServiceInstance androidService = await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: true,
          isForegroundMode: true,
          notificationChannelId:
              'alarm_cycles_channel', // ID unique pour le canal
          initialNotificationTitle: 'Alarm Service',
          initialNotificationContent: 'Service is running',
          foregroundServiceNotificationId: 888,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: true,
          onForeground: onStart,
          onBackground: AlarmVM.onIosBackground,
        ),
      ) as AndroidServiceInstance;

      print("Service configured successfully");
    } catch (e) {
      print("Error configuring service: $e");
    }
  } else {
    // Configuration pour iOS ou autres plateformes
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'alarm_cycles_channel',
        initialNotificationTitle: 'Alarm Service',
        initialNotificationContent: 'Service is running',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: AlarmVM.onIosBackground,
      ),
    );
  }

  // Démarrer le service
  service.startService();
}

/// If app runs on Windows, Linux or MacOS, set the app size
/// and position.
Future<void> _setWindowsAppSizeAndPosition({
  required bool isTest,
}) async {
  if (ScreenMixin.isHardwarePc()) {
    await getScreenList().then((List<Screen> screens) {
      final Screen screen = screens.first;
      final Rect screenRect = screen.visibleFrame;
      double windowWidth = (isTest) ? 900 : 730;
      double windowHeight = (isTest) ? 1700 : 1480;
      final double posX = screenRect.right - windowWidth + 10;
      final double posY = (screenRect.height - windowHeight) / 2;
      final Rect windowRect =
          Rect.fromLTWH(posX, posY, windowWidth, windowHeight);
      setWindowFrame(windowRect);
    });
  }
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alarm App',
      navigatorKey: navigatorKey,
      home: const AlarmPage(),
    );
  }
}
