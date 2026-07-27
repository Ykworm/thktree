package com.thktree.thk_tree

import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class BackgroundTaskPlugin private constructor(
  private val context: Context,
) : MethodChannel.MethodCallHandler {

  companion object {
    private const val CHANNEL = "thktree/background_task"

    fun registerWith(flutterEngine: FlutterEngine) {
      val channel = MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        CHANNEL,
      )
      channel.setMethodCallHandler(
        BackgroundTaskPlugin(flutterEngine.applicationContext),
      )
    }
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "begin" -> {
        val intent = Intent(context, LlmStreamForegroundService::class.java).apply {
          action = LlmStreamForegroundService.ACTION_BEGIN
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
          context.startForegroundService(intent)
        } else {
          context.startService(intent)
        }
        result.success("android-fgs")
      }
      "end" -> {
        val intent = Intent(context, LlmStreamForegroundService::class.java).apply {
          action = LlmStreamForegroundService.ACTION_END
        }
        context.startService(intent)
        result.success(true)
      }
      "isActive" -> result.success(LlmStreamForegroundService.activeCount > 0)
      else -> result.notImplemented()
    }
  }
}
