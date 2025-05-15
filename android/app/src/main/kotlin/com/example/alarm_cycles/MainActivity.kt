package com.example.alarm_cycles

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Bundle

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Créer le canal de notification au démarrage de l'application
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        // Créer le canal de notification seulement pour Android 8.0 et supérieur
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "alarm_cycles_channel", // ID du canal
                "Alarm Cycles", // Nom du canal visible par l'utilisateur
                NotificationManager.IMPORTANCE_LOW) // Importance basse pour éviter les sons
            
            channel.description = "Notifications pour le service d'alarme"
            channel.enableVibration(false)
            channel.enableLights(false)
            
            // Enregistrer le canal auprès du système
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager?
            
            notificationManager?.createNotificationChannel(channel)
        }
    }
}