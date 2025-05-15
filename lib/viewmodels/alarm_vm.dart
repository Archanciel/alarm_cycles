import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:alarm_cycle/constant.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../models/alarm.dart';
import '../views/simple_edit_alarm_screen.dart';

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

  /// Nouvelle méthode de vérification des alarmes pour le Timer
  Future<void> checkAlarms() async {
    print('Checking alarms...');
    bool wasAlarmModified = false;

    DateTime now = DateTime.now();
    print('Current time: $now');

    for (Alarm alarm in alarms) {
      print('Checking alarm: ${alarm.name}, next time: ${alarm.nextAlarmTime}');
      if (alarm.nextAlarmTime.isBefore(now)) {
        print('Alarm triggered: ${alarm.name}');

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
        print(
            'Alarm updated: ${alarm.name}, new next time: ${alarm.nextAlarmTime}');
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
