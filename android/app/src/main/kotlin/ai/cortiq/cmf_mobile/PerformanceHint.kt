package ai.cortiq.cmf_mobile

import android.content.Context
import android.os.Build
import android.os.PerformanceHintManager

/**
 * ADPF work-duration hints for the engine's worker pool.
 *
 * The affinity mask keeps the workers on the big cores, but not at a useful
 * clock: the governor only sees short bursts and ramps lazily. A hint session
 * names the threads that do the work and the duration they are aiming for, so
 * reporting how long a batch of tokens actually took lets the system raise
 * the clocks while a reply is being generated — and drop them the moment the
 * session closes.
 *
 * API 31+; a no-op everywhere else.
 */
class PerformanceHint(private val context: Context) {
    private var session: PerformanceHintManager.Session? = null

    fun start(tids: IntArray, targetNanos: Long): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return false
        if (tids.isEmpty() || targetNanos <= 0) return false
        stop()
        val manager = context.getSystemService(PerformanceHintManager::class.java)
            ?: return false
        session = try {
            manager.createHintSession(tids, targetNanos)
        } catch (e: IllegalArgumentException) {
            // A tid that already exited, or one the app does not own.
            null
        }
        return session != null
    }

    fun report(actualNanos: Long) {
        if (actualNanos <= 0) return
        try {
            session?.reportActualWorkDuration(actualNanos)
        } catch (e: IllegalArgumentException) {
            // Session already invalid — nothing to salvage, just stop hinting.
            session = null
        }
    }

    fun stop() {
        session?.close()
        session = null
    }
}
