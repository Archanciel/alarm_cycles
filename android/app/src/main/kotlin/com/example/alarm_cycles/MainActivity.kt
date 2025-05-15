package com.example.alarm_cycles

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.graphics.Color
import androidx.core.app.NotificationCompat
import android.app.PendingIntent
import android.content.Intent

class MainActivity: FlutterActivity() {
    companion object {
        const val CHANNEL_ID = "alarm_cycles_channel"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Créer le canal de notification au démarrage de l'application
        createNotificationChannel()
        
        // Créer un exemple de notification pour tester si les notifications fonctionnent
        testNotification()
    }

    private fun createNotificationChannel() {
        // Créer le canal de notification seulement pour Android 8.0 et supérieur
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Alarm Cycles"
            val descriptionText = "Notifications pour le service d'alarme"
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
                enableLights(false)
                enableVibration(false)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }
            
            // Enregistrer le canal auprès du système
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
            
            println("Notification channel created successfully: $CHANNEL_ID")
        }
    }
    
    private fun testNotification() {
        // Ne pas lancer la notification si nous sommes sur Android 7 ou moins
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        
        try {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // Intent pour ouvrir l'app quand on clique sur la notification
            val intent = Intent(this, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                this, 0, intent, 
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )

            // Créer la notification
            val builder = NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle("Test notification")
                .setContentText("Notification channel test")
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setContentIntent(pendingIntent)
                .setAutoCancel(true)

            // Afficher la notification
            notificationManager.notify(999, builder.build())
            println("Test notification created successfully")
        } catch (e: Exception) {
            println("Error creating test notification: ${e.message}")
            e.printStackTrace()
        }
    }
}