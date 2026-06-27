// MainActivity.kt - 安卓原生入口
package com.translatortools.screen_translator

import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.translatortools.screen_translator/methods"
    private val EVENT_CHANNEL = "com.translatortools.screen_translator/capture_events"
    private val PERMISSION_REQUEST_CODE = 1001
    private val SYSTEM_ALERT_WINDOW_REQUEST_CODE = 1002
    
    private var pendingResult: MethodChannel.Result? = null
    private var pendingIntent: Intent? = null
    
    private var mediaProjectionResultCode: Int = -1
    private var mediaProjectionResultData: Intent? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        createNotificationChannel()
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkOverlayPermission" -> {
                    result.success(Settings.canDrawOverlays(this))
                }
                "requestOverlayPermission" -> {
                    pendingResult = result
                    val intent = Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        android.net.Uri.parse("package:$packageName")
                    )
                    startActivityForResult(intent, SYSTEM_ALERT_WINDOW_REQUEST_CODE)
                }
                "requestScreenshotPermission" -> {
                    pendingResult = result
                    val mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                    pendingIntent = mediaProjectionManager.createScreenCaptureIntent()
                    startActivityForResult(pendingIntent!!, PERMISSION_REQUEST_CODE)
                }
                "getStatusBarHeight" -> {
                    result.success(getStatusBarHeight())
                }
                "getStatusBarHeightWithInsets" -> {
                    result.success(getStatusBarHeightWithInsets())
                }
                "getScreenWidth" -> {
                    result.success(getScreenWidth())
                }
                "getScreenHeight" -> {
                    result.success(getScreenHeight())
                }
                "getManufacturer" -> {
                    result.success(Build.MANUFACTURER)
                }
                "getModel" -> {
                    result.success(Build.MODEL)
                }
                "getAndroidVersion" -> {
                    result.success(Build.VERSION.SDK_INT)
                }
                "isLowRamDevice" -> {
                    val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
                    result.success(activityManager.isLowRamDevice)
                }
                "getCpuCores" -> {
                    result.success(Runtime.getRuntime().availableProcessors())
                }
                "getTotalMemoryMb" -> {
                    val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
                    val memoryInfo = android.app.ActivityManager.MemoryInfo()
                    activityManager.getMemoryInfo(memoryInfo)
                    result.success((memoryInfo.totalMem / (1024 * 1024)).toInt())
                }
                "openAppSettings" -> {
                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    intent.data = android.net.Uri.parse("package:$packageName")
                    startActivity(intent)
                    result.success(true)
                }
                "openBatteryOptimization" -> {
                    val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                    startActivity(intent)
                    result.success(true)
                }
                "openVendorOverlaySettings" -> {
                    openVendorOverlaySettings()
                    result.success(true)
                }
                "checkNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val hasPermission = checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) == android.content.pm.PackageManager.PERMISSION_GRANTED
                        result.success(hasPermission)
                    } else {
                        result.success(true)
                    }
                }
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 1003)
                    }
                    result.success(true)
                }
                "startTranslationService" -> {
                    if (mediaProjectionResultCode != -1 && mediaProjectionResultData != null) {
                        startTranslationService(mediaProjectionResultCode, mediaProjectionResultData!!)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "stopTranslationService" -> {
                    stopService(Intent(this, TranslationService::class.java))
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    TranslationService.getInstance()?.setEventSink(sink)
                }
                
                override fun onCancel(arguments: Any?) {
                    TranslationService.getInstance()?.setEventSink(null)
                }
            }
        )
    }

    private fun openVendorOverlaySettings() {
        val manufacturer = Build.MANUFACTURER.toLowerCase()
        
        val intent = when (manufacturer) {
            "xiaomi", "redmi", "mi" -> {
                Intent("miui.intent.action.APP_PERMISSIONS").apply {
                    putExtra("extra_pkgname", packageName)
                }
            }
            "vivo", "iqoo" -> {
                Intent("com.vivo.permissionmanager.intent.action.MAIN").apply {
                    putExtra("packagename", packageName)
                }
            }
            "oppo", "realme" -> {
                Intent("com.coloros.safecenter.intent.action.start").apply {
                    putExtra("type", 1)
                    putExtra("packagename", packageName)
                }
            }
            "oneplus" -> {
                Intent("com.oneplus.security.intent.action.permission").apply {
                    putExtra("packagename", packageName)
                }
            }
            "huawei", "honor" -> {
                Intent("com.huawei.systemmanager.intent.action.main").apply {
                    putExtra("packagename", packageName)
                }
            }
            "samsung" -> {
                Intent("com.samsung.android.app.galaxyfinder.intent.action.BROWSER").apply {
                    putExtra("query", packageName)
                }
            }
            else -> {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = android.net.Uri.parse("package:$packageName")
                }
            }
        }
        
        try {
            startActivity(intent)
        } catch (e: Exception) {
            val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            fallback.data = android.net.Uri.parse("package:$packageName")
            startActivity(fallback)
        }
    }

    private fun startTranslationService(resultCode: Int, resultData: Intent?) {
        val intent = Intent(this, TranslationService::class.java).apply {
            putExtra("resultCode", resultCode)
            if (resultData != null) {
                putExtra("resultData", resultData)
            }
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == PERMISSION_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                mediaProjectionResultCode = resultCode
                mediaProjectionResultData = data
                startTranslationService(resultCode, data)
            }
            
            pendingResult?.let { result ->
                result.success(resultCode == Activity.RESULT_OK && data != null)
                pendingResult = null
            }
        } else if (requestCode == SYSTEM_ALERT_WINDOW_REQUEST_CODE) {
            pendingResult?.let { result ->
                result.success(Settings.canDrawOverlays(this))
                pendingResult = null
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "translation_channel",
                "翻译服务",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "屏幕翻译服务通知"
                setShowBadge(false)
            }

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun getStatusBarHeight(): Int {
        var result = 0
        val resourceId = resources.getIdentifier("status_bar_height", "dimen", "android")
        if (resourceId > 0) {
            result = resources.getDimensionPixelSize(resourceId)
        }
        return result
    }

    private fun getStatusBarHeightWithInsets(): Int {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val windowMetrics = windowManager.currentWindowMetrics
            val insets = windowMetrics.windowInsets.getInsetsIgnoringVisibility(
                android.view.WindowInsets.Type.statusBars()
            )
            return insets.top
        }
        
        return getStatusBarHeight()
    }

    private fun getScreenWidth(): Int {
        val displayMetrics = resources.displayMetrics
        return displayMetrics.widthPixels
    }

    private fun getScreenHeight(): Int {
        val displayMetrics = resources.displayMetrics
        return displayMetrics.heightPixels
    }

    override fun onResume() {
        super.onResume()
        val prefs = getSharedPreferences("app_prefs", Context.MODE_PRIVATE)
        val hasShownGuide = prefs.getBoolean("has_shown_permission_guide", false)
        if (!hasShownGuide && !Settings.canDrawOverlays(this)) {
            prefs.edit().putBoolean("has_shown_permission_guide", true).apply()
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                android.net.Uri.parse("package:$packageName")
            )
            startActivity(intent)
        }
    }
}