package ai.cortiq.cmf_mobile

import android.Manifest
import android.app.ActivityManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    /// Reason the foreground service was last started, kept so the
    /// notification can be re-posted once the user grants notifications.
    private var foregroundReason: String? = null
    private var notificationPermissionAsked = false
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cmf/keep_awake")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setKeepAwake" -> {
                        val on = call.arguments as? Boolean ?: false
                        if (on) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        val performanceHint = PerformanceHint(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cmf/perf_hint")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val tids = call.argument<List<Int>>("tids") ?: emptyList()
                        val target = call.argument<Number>("targetNanos")?.toLong() ?: 0L
                        result.success(
                            performanceHint.start(tids.toIntArray(), target)
                        )
                    }
                    "report" -> {
                        val actual = call.argument<Number>("actualNanos")?.toLong() ?: 0L
                        performanceHint.report(actual)
                        result.success(null)
                    }
                    "stop" -> {
                        performanceHint.stop()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cmf/foreground")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val reason = call.argument<String>("reason")
                            ?: InferenceService.REASON_GENERATION
                        foregroundReason = reason
                        // The service runs either way, but a suppressed
                        // notification would leave the work invisible — which
                        // is the one thing a foreground service must not be.
                        requestNotificationPermission()
                        try {
                            InferenceService.start(this, reason)
                            result.success(true)
                        } catch (e: Exception) {
                            // Android 12+ refuses a background start; the work
                            // still runs, just at background priority.
                            result.success(false)
                        }
                    }
                    "stop" -> {
                        foregroundReason = null
                        InferenceService.stop(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cmf/device_memory")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "memoryInfo" -> {
                        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                        val info = ActivityManager.MemoryInfo()
                        am.getMemoryInfo(info)
                        result.success(
                            mapOf(
                                "availBytes" to info.availMem,
                                "totalBytes" to info.totalMem,
                                "lowMemory" to info.lowMemory,
                            )
                        )
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /// Asks for POST_NOTIFICATIONS the first time work starts that the user
    /// has to be able to see. Asked once per process: the system stops
    /// showing the dialog after two refusals anyway, and the service does not
    /// depend on the answer.
    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (notificationPermissionAsked) return
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        notificationPermissionAsked = true
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQUEST_POST_NOTIFICATIONS,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_POST_NOTIFICATIONS) return
        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        // The service posted its notification while the permission was still
        // missing, so it was dropped. Start it again to post it for real —
        // onStartCommand is idempotent, and the reply keeps generating either
        // way.
        val reason = foregroundReason
        if (granted && reason != null) {
            try {
                InferenceService.start(this, reason)
            } catch (e: Exception) {
                // Nothing to recover: the service is already running.
            }
        }
    }

    private companion object {
        const val REQUEST_POST_NOTIFICATIONS = 1001
    }
}
