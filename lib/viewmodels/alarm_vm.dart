import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:path_provider/path_provider.dart';

import '../models/alarm.dart';

class AudioPlayerVM extends ChangeNotifier {
  /// Play an audio file located in the assets folder.
  Future<void> playFromAssets(Alarm alarm) async {
    AudioPlayer? audioPlayer = alarm.audioPlayer;

    if (audioPlayer == null) {
      audioPlayer = AudioPlayer();
      alarm.audioPlayer = audioPlayer;
    }

    await audioPlayer.play(AssetSource(alarm.audioFilePathName));
    alarm.isPlaying = true;

    notifyListeners();
  }

  Future<void> pause(Alarm alarm) async {
    if (alarm.isPaused) {
      await alarm.audioPlayer!.resume();
    } else {
      await alarm.audioPlayer!.pause();
    }

    alarm.invertPaused();
    notifyListeners();
  }

  Future<void> stop(Alarm alarm) async {
    await alarm.audioPlayer!.stop();
    alarm.isPlaying = false;
    notifyListeners();
  }
}

/// The ViewModel of the AlarmPage is a singleton.
class AlarmVM with ChangeNotifier {
  List<Alarm> alarms = [];
  AudioPlayerVM audioPlayerVM = AudioPlayerVM();

  static const List<String> audioFileNames = [
    'Sirdalud.mp3',
    'Lioresal.mp3',
    'ArrosePlante.mp3',
    'LaveTesCh.mp3',
    // other audio files ...
  ];

  String _selectedAudioFile = audioFileNames.first;
  String get selectedAudioFile => _selectedAudioFile;
  set selectedAudioFile(String newValue) {
    _selectedAudioFile = newValue;
    notifyListeners();
  }

  static final AlarmVM _singleton = AlarmVM._internal();

  factory AlarmVM() {
    return _singleton;
  }

  AlarmVM._internal() {
    _loadAlarms();
  }

  // iOS background handler
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    
    // Access the AlarmVM singleton
    final alarmVM = AlarmVM();
    
    // Check alarms
    await alarmVM.checkAlarms();
    
    return true;
  }

  // Main background task handler
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // Ensure Flutter bindings are initialized
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    
    // Log that service is starting
    print('Background service starting: ${DateTime.now()}');
    
    // Access the AlarmVM singleton
    final alarmVM = AlarmVM();
    
    // Initial notification setup for Android
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "Alarm Manager",
        content: "Service running in background",
      );
    }

    // Handle notification events from the app
    service.on('showNotification').listen((event) {
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: event?['title'] ?? 'Alarm',
          content: event?['content'] ?? 'Your alarm is ringing',
        );
      }
    });

    // Configure periodic task - check alarms every 15 minutes
    Timer.periodic(const Duration(minutes: 15), (timer) async {
      print('Checking alarms at ${DateTime.now()}');
      
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "Alarm Manager",
          content: "Checking alarms at ${DateTime.now()}",
        );
      }
      
      // Check for alarms that need to be triggered
      await alarmVM.checkAlarms();
      
      // Send any updates to the app
      service.invoke('update', {
        'last_check': DateTime.now().toIso8601String(),
      });
    });
    
    // Also perform an immediate check when service starts
    await alarmVM.checkAlarms();
    
    print('Background service started successfully');
  }

  Future<void> _loadAlarms() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = File('${directory.path}/alarms.json');

      // Vérifiez si le fichier existe
      if (await filePath.exists()) {
        // Lisez et décodez le fichier
        final jsonData = await filePath.readAsString();
        final List<dynamic> loadedAlarms = json.decode(jsonData);

        alarms = loadedAlarms.map((alarmMap) {
          return Alarm.fromJson(alarmMap);
        }).toList();

        notifyListeners();
        print('Alarms loaded successfully: ${alarms.length} alarms');
      } else {
        print('No alarms file exists yet');
      }
    } catch (e) {
      print('Error loading alarms: $e');
    }
  }

  Future<void> _saveAlarms() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = File('${directory.path}/alarms.json');

      // Convert alarms to a list of maps
      final List<Map<String, dynamic>> jsonAlarms = alarms.map((alarm) {
        return alarm.toJson();
      }).toList();

      // Encode and write to the file
      await filePath.writeAsString(json.encode(jsonAlarms));
      print('Alarms saved successfully: ${alarms.length} alarms');
    } catch (e) {
      print('Error saving alarms: $e');
    }
  }

  /// Replacement for the checkAlarmsPeriodically method
  /// This is now called by the background service timer
  Future<void> checkAlarms() async {
    print('Checking alarms...');
    bool wasAlarmModified = false;

    DateTime now = DateTime.now();
    print('Current time: $now');

    for (Alarm alarm in alarms) {
      print('Checking alarm: ${alarm.name}, next time: ${alarm.nextAlarmTime}');
      if (alarm.nextAlarmTime.isBefore(now)) {
        print('Alarm triggered: ${alarm.name}');
        
        // Show notification using the background service
        final service = FlutterBackgroundService();
        service.invoke('showNotification', {
          'title': 'Alarm: ${alarm.name}',
          'content': 'Time to take your medication',
        });
        
        try {
          await audioPlayerVM.playFromAssets(alarm);
          print('Audio played successfully');
        } catch (e) {
          print('Error playing audio: $e');
        }

        // Update the nextAlarmTime
        updateAlarmDateTimes(
          alarm: alarm,
        );
        wasAlarmModified = true;
        print('Alarm updated: ${alarm.name}, new next time: ${alarm.nextAlarmTime}');
      }
    }

    if (wasAlarmModified) {
      await _saveAlarms();
      notifyListeners();
      print('Alarms saved after modifications');
    } else {
      print('No alarms needed updates');
    }
  }

  void updateAlarmDateTimes({
    required Alarm alarm,
  }) {
    DateTime nextAlarmDateTime = alarm.nextAlarmTime;
    Duration periodicDuration = alarm.periodicDuration;

    DateTime now = DateTime.now();

    while (nextAlarmDateTime.isBefore(now)) {
      nextAlarmDateTime = nextAlarmDateTime.add(periodicDuration);
    }

    alarm.lastAlarmTimePurpose = alarm.nextAlarmTime;
    alarm.lastAlarmTimeReal = now;
    alarm.nextAlarmTime = nextAlarmDateTime;
  }

  void addAlarm(Alarm alarm) {
    // Since the user selected the audio file name only, we need to add
    // the path to the assets folder
    alarm.audioFilePathName = 'audio/${alarm.audioFilePathName}';
    alarms.add(alarm);
    _saveAlarms();
    notifyListeners();
  }

  void editAlarm(Alarm alarm) {
    int index = alarms.indexWhere((element) => element.name == alarm.name);

    if (index == -1) {
      return;
    }

    alarm.audioFilePathName = 'audio/${alarm.audioFilePathName}';
    alarms[index] = alarm;
    _saveAlarms();
    notifyListeners();
  }

  void deleteAlarm(int index) {
    alarms.removeAt(index);
    _saveAlarms();
    notifyListeners();
  }
}