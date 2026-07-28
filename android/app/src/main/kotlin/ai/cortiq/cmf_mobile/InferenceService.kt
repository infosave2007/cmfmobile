package ai.cortiq.cmf_mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat

/**
 * Keeps inference running at foreground scheduling priority.
 *
 * Android moves a backgrounded process into the background cpuset, which is
 * usually the little cores only — and a cpuset outranks the affinity mask the
 * engine sets for its worker pool, so a chat left mid-reply or a serving
 * session with the screen off drops to little-core speed. A foreground
 * service keeps the process in the foreground cpuset; the partial wake lock
 * keeps the CPU from suspending once the screen goes off.
 *
 * Started only from user-visible actions (send a message, start the server),
 * which is also what Android 12+ requires — a background start would throw
 * ForegroundServiceStartNotAllowedException.
 */
class InferenceService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val reason = intent?.getStringExtra(EXTRA_REASON) ?: REASON_GENERATION
        startInForeground(reason)
        if (wakeLock == null) {
            val power = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = power
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "cmf:inference")
                .apply {
                    setReferenceCounted(false)
                    acquire(WAKE_LOCK_TIMEOUT_MS)
                }
        }
        // Deliberately not sticky: after a process death there is no
        // generation left to protect, and the model is gone with it.
        return START_NOT_STICKY
    }

    // Android 15 budgets dataSync services at six hours a day and then calls
    // one of these; the service has seconds to go away before the system
    // throws ForegroundServiceDidNotStopInTimeException. Inference keeps
    // running — just at background priority again.
    @Deprecated("Superseded by the two-argument overload on API 36+")
    override fun onTimeout(startId: Int) {
        stopSelf()
    }

    override fun onTimeout(startId: Int, fgsType: Int) {
        stopSelf()
    }

    override fun onDestroy() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        super.onDestroy()
    }

    private fun startInForeground(reason: String) {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    getString(R.string.fgs_channel_name),
                    NotificationManager.IMPORTANCE_LOW,
                ).apply { setShowBadge(false) }
            )
        }
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java)
                .setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val text = when (reason) {
            REASON_SERVER -> R.string.fgs_text_server
            else -> R.string.fgs_text_generation
        }
        val notification: Notification =
            NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle(getString(R.string.fgs_title))
                .setContentText(getString(text))
                .setSmallIcon(R.drawable.ic_stat_cortiq)
                .setContentIntent(open)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setOngoing(true)
                .build()

        ServiceCompat.startForeground(
            this,
            NOTIFICATION_ID,
            notification,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            } else {
                0
            },
        )
    }

    companion object {
        const val EXTRA_REASON = "reason"
        const val REASON_GENERATION = "generation"
        const val REASON_SERVER = "server"

        private const val CHANNEL_ID = "cmf_inference"
        private const val NOTIFICATION_ID = 1
        // A backstop only: the service releases the lock in onDestroy. Long
        // enough for a full-context reply on a slow device.
        private const val WAKE_LOCK_TIMEOUT_MS = 60L * 60L * 1000L

        fun start(context: Context, reason: String) {
            val intent = Intent(context, InferenceService::class.java)
                .putExtra(EXTRA_REASON, reason)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, InferenceService::class.java))
        }
    }
}
