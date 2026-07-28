package ai.cortiq.cmf_mobile

import android.app.ActivityManager
import android.content.Context
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
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
}
