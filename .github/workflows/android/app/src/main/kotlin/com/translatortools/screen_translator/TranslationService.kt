package com.translatortools.screen_translator

import android.app.*
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.*
import android.util.DisplayMetrics
import android.view.WindowManager
import androidx.annotation.RequiresApi
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer

class TranslationService : Service() {
    companion object {
        const val CHANNEL = "com.translatortools.screen_translator/screen_capture"
        const val EVENT_CHANNEL = "com.translatortools.screen_translator/capture_events"
        
        private var instance: TranslationService? = null
        fun getInstance(): TranslationService? = instance
    }

    private lateinit var mediaProjectionManager: MediaProjectionManager
    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var eventSink: EventChannel.EventSink? = null
    private var isCapturing = false
    
    private var screenWidth = 0
    private var screenHeight = 0
    private var screenDensity = 0
    private var statusBarHeight = 0

    override fun onCreate() {
        super.onCreate()
        instance = this
        mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        acquireWakeLock()
        getScreenInfo()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(1, createNotification())
        
        val resultCode = intent?.getIntExtra("resultCode", -1) ?: -1
        val resultData = intent?.getParcelableExtra<Intent>("resultData")
        
        if (resultCode != -1 && resultData != null) {
            savedResultCode = resultCode
            savedResultData = resultData
            startScreenCapture(resultCode, resultData)
        } else if (savedResultCode != -1 && savedResultData != null) {
            startScreenCapture(savedResultCode, savedResultData!!)
        }
        
        return START_STICKY
    }

    private var savedResultCode: Int = -1
    private var savedResultData: Intent? = null

    override fun onDestroy() {
        super.onDestroy()
        stopScreenCapture()
        releaseWakeLock()
        instance = null
    }
    
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        
        if (savedResultCode != -1 && savedResultData != null) {
            val restartIntent = Intent(this, TranslationService::class.java).apply {
                putExtra("resultCode", savedResultCode)
                putExtra("resultData", savedResultData)
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(restartIntent)
            } else {
                startService(restartIntent)
            }
        }
    }

    private fun acquireWakeLock() {
        val powerManager = getSystemService(POWER_SERVICE) as PowerManager
        if (powerManager.isWakeLockLevelSupported(PowerManager.PARTIAL_WAKE_LOCK)) {
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "ScreenTranslator::TranslationWakeLock"
            )
            wakeLock?.acquire(10 * 60 * 1000L)
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.release()
        wakeLock = null
    }

    private fun getScreenInfo() {
        val windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val display = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            windowManager.currentWindowMetrics.windowBounds
        } else {
            val metrics = DisplayMetrics()
            windowManager.defaultDisplay.getMetrics(metrics)
            android.graphics.Rect(0, 0, metrics.widthPixels, metrics.heightPixels)
        }
        
        screenWidth = display.width()
        screenHeight = display.height()
        screenDensity = resources.displayMetrics.densityDpi
        
        val resourceId = resources.getIdentifier("status_bar_height", "dimen", "android")
        statusBarHeight = if (resourceId > 0) resources.getDimensionPixelSize(resourceId) else 0
    }

    private fun startScreenCapture(resultCode: Int, resultData: Intent) {
        stopScreenCapture()
        
        mediaProjection = mediaProjectionManager.getMediaProjection(resultCode, resultData)
        
        imageReader = ImageReader.newInstance(
            screenWidth,
            screenHeight,
            PixelFormat.RGBA_8888,
            2
        )
        
        virtualDisplay = mediaProjection?.createVirtualDisplay(
            "ScreenTranslator",
            screenWidth,
            screenHeight,
            screenDensity,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            imageReader?.surface,
            null,
            Handler(Looper.getMainLooper())
        )
        
        imageReader?.setOnImageAvailableListener({ reader ->
            if (!isCapturing) return@setOnImageAvailableListener
            
            val image = reader.acquireLatestImage() ?: return@setOnImageAvailableListener
            
            try {
                val bytes = imageToByteArray(image)
                eventSink?.success(bytes)
            } catch (e: Exception) {
                // ignore
            } finally {
                image.close()
            }
        }, Handler(Looper.getMainLooper()))
        
        isCapturing = true
    }

    private fun imageToByteArray(image: Image): ByteArray {
        val planes = image.planes
        val plane = planes[0]
        val rowStride = plane.rowStride
        val pixelStride = plane.pixelStride
        val buffer = plane.buffer
        
        val bitmap = Bitmap.createBitmap(
            screenWidth,
            screenHeight,
            Bitmap.Config.ARGB_8888
        )
        
        val bitmapBuffer = ByteBuffer.allocate(bitmap.byteCount)
        bitmap.copyPixelsToBuffer(bitmapBuffer)
        bitmapBuffer.rewind()
        
        val rowBytes = screenWidth * 4
        
        for (y in 0 until screenHeight) {
            buffer.position(y * rowStride)
            
            val startPos = y * rowBytes
            for (x in 0 until screenWidth) {
                val bufferPos = x * pixelStride
                bitmapBuffer.putInt(startPos + x * 4, buffer.getInt(bufferPos))
            }
        }
        
        bitmapBuffer.rewind()
        bitmap.copyPixelsFromBuffer(bitmapBuffer)
        
        val safeStatusBarHeight = statusBarHeight.coerceAtMost(screenHeight - 1)
        val croppedBitmap = if (safeStatusBarHeight > 0) {
            Bitmap.createBitmap(
                bitmap,
                0,
                safeStatusBarHeight,
                screenWidth,
                screenHeight - safeStatusBarHeight
            )
        } else {
            bitmap
        }
        
        val out = ByteArrayOutputStream()
        croppedBitmap.compress(Bitmap.CompressFormat.JPEG, 75, out)
        
        bitmap.recycle()
        if (croppedBitmap !== bitmap) {
            croppedBitmap.recycle()
        }
        
        return out.toByteArray()
    }

    private fun stopScreenCapture() {
        isCapturing = false
        
        virtualDisplay?.release()
        virtualDisplay = null
        
        imageReader?.close()
        imageReader = null
        
        mediaProjection?.stop()
        mediaProjection = null
    }

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    fun isCapturing(): Boolean = isCapturing

    fun getScreenWidth(): Int = screenWidth
    fun getScreenHeight(): Int = screenHeight
    fun getStatusBarHeight(): Int = statusBarHeight

    private fun createNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.getActivity(
                this,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        } else {
            PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT)
        }

        return NotificationCompat.Builder(this, "translation_channel")
            .setContentTitle("屏幕翻译")
            .setContentText("正在运行中")
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .build()
    }
}