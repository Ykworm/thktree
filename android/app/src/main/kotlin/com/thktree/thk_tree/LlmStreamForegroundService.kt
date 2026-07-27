package com.thktree.thk_tree

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class LlmStreamForegroundService : Service() {
  override fun onBind(intent: Intent?): IBinder? = null

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    when (intent?.action) {
      ACTION_BEGIN -> {
        activeCount++
        if (activeCount == 1) {
          createNotificationChannel()
          startForeground(NOTIFICATION_ID, buildNotification())
        }
      }
      ACTION_END -> {
        activeCount = maxOf(0, activeCount - 1)
        if (activeCount == 0) {
          if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
          } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
          }
          stopSelf()
        }
      }
    }
    return START_STICKY
  }

  private fun createNotificationChannel() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val channel = NotificationChannel(
        CHANNEL_ID,
        "LLM streaming",
        NotificationManager.IMPORTANCE_LOW,
      ).apply {
        description = "Keeps chat generation running in background"
        setShowBadge(false)
      }
      val manager = getSystemService(NotificationManager::class.java)
      manager.createNotificationChannel(channel)
    }
  }

  private fun buildNotification(): Notification {
    val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
    val pendingIntent = PendingIntent.getActivity(
      this,
      0,
      launchIntent,
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
    return NotificationCompat.Builder(this, CHANNEL_ID)
      .setContentTitle("ThkTree")
      .setContentText("Generating reply…")
      .setSmallIcon(R.mipmap.ic_launcher)
      .setContentIntent(pendingIntent)
      .setOngoing(true)
      .setPriority(NotificationCompat.PRIORITY_LOW)
      .build()
  }

  companion object {
    const val CHANNEL_ID = "thktree_llm_stream"
    const val NOTIFICATION_ID = 1001
    const val ACTION_BEGIN = "com.thktree.thk_tree.action.BEGIN"
    const val ACTION_END = "com.thktree.thk_tree.action.END"

    @Volatile
    var activeCount: Int = 0
  }
}
