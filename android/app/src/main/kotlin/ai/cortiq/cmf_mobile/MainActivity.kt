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
        // The NPU lane: the directory holding the Hexagon half of the module,
        // which the DSP can only read as a real file. Null when this APK has
        // no module for this device's ABI.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cmf/native_dir")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "npuDir" -> Thread {
                        val dir = try { npuModuleDir() } catch (e: Exception) { null }
                        runOnUiThread { result.success(dir) }
                    }.start()
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

    /// Where `libcortiq_hvx_skel.so` is as a file: the native library
    /// directory when the libraries were extracted, else a copy in
    /// `files/npu` taken from the APK (or its ABI split, from Play), refreshed
    /// when the app is updated. ~18 KB, copied once per version.
    private fun npuModuleDir(): String? {
        val name = "libcortiq_hvx_skel.so"
        val native = java.io.File(applicationInfo.nativeLibraryDir ?: "", name)
        if (native.isFile) return native.parent
        val out = java.io.File(filesDir, "npu")
        val dst = java.io.File(out, name)
        val stamp = java.io.File(out, "version")
        val version = packageManager.getPackageInfo(packageName, 0).let {
            "${it.lastUpdateTime}"
        }
        if (dst.isFile && stamp.isFile && stamp.readText() == version) return out.path
        val apks = listOf(applicationInfo.sourceDir) + (applicationInfo.splitSourceDirs?.toList() ?: emptyList())
        for (abi in Build.SUPPORTED_ABIS) {
            for (apk in apks) {
                java.util.zip.ZipFile(apk).use { zip ->
                    val entry = zip.getEntry("lib/$abi/$name") ?: return@use
                    out.mkdirs()
                    val tmp = java.io.File(out, "$name.tmp")
                    zip.getInputStream(entry).use { input -> tmp.outputStream().use { input.copyTo(it) } }
                    if (!tmp.renameTo(dst)) throw java.io.IOException("cannot place $name")
                    stamp.writeText(version)
                    return out.path
                }
            }
        }
        return null
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
