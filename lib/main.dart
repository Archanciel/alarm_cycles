import 'dart:async';
import 'dart:io';
import 'package:alarm_cycle/constant.dart';
import 'package:alarm_cycle/services/permission_requester_service.dart';
import 'package:alarm_cycle/views/screen_mixin.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_size/window_size.dart';
import 'viewmodels/alarm_vm.dart';
import 'views/alarm_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Demander les permissions
  PermissionRequesterService.requestMultiplePermissions();
  
  // Configuration des fenêtres pour les plateformes desktop
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await _setWindowsAppSizeAndPosition(
      isTest: false,
    );
  }
  
  // Créer un timer qui vérifie périodiquement les alarmes (au lieu d'un service en arrière-plan)
  _startAlarmCheckTimer();
  
  runApp(ChangeNotifierProvider(
    create: (context) => AlarmVM(),
    child: const MyApp(),
  ));
}

// Démarre un timer pour vérifier périodiquement les alarmes
void _startAlarmCheckTimer() {
  print("Starting alarm check timer");
  
  // Premier contrôle immédiat
  AlarmVM().checkAlarms();
  
  // Puis toutes les minutes
  Timer.periodic(const Duration(minutes: 1), (timer) {
    print("Checking alarms at ${DateTime.now()}");
    AlarmVM().checkAlarms();
  });
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
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AlarmPage(),
    );
  }
}
