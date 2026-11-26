package com.au7md.thalab_app

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

// =============================================================================
// نظام الأذان الأصلي (Native): منبه دقيق -> مستقبل -> خدمة أمامية تشغّل الصوت.
// يحترم وضع الصامت/الاهتزاز عبر AudioManager.ringerMode وقناة الإشعارات.
// =============================================================================

private const val TAG = "ThalabAdhan"

data class AdhanEntry(
    val id: Int,
    val whenMs: Long,
    val title: String,
    val body: String,
    val muezzin: String,
    val followRinger: Boolean
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("id", id)
        put("whenMs", whenMs)
        put("title", title)
        put("body", body)
        put("muezzin", muezzin)
        put("followRinger", followRinger)
    }

    companion object {
        fun fromJson(o: JSONObject) = AdhanEntry(
            o.getInt("id"),
            o.getLong("whenMs"),
            o.optString("title"),
            o.optString("body"),
            o.optString("muezzin"),
            o.optBoolean("followRinger", true)
        )
    }
}

object AdhanScheduler {
    private const val PREFS = "thalab_adhan"
    private const val KEY_ENTRIES = "entries"
    const val ACTION_FIRE = "com.au7md.thalab_app.ADHAN_FIRE"

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun load(ctx: Context): List<AdhanEntry> {
        val raw = prefs(ctx).getString(KEY_ENTRIES, null) ?: return emptyList()
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).map { AdhanEntry.fromJson(arr.getJSONObject(it)) }
        } catch (e: Exception) {
            Log.e(TAG, "load failed", e)
            emptyList()
        }
    }

    private fun save(ctx: Context, list: List<AdhanEntry>) {
        val arr = JSONArray()
        list.forEach { arr.put(it.toJson()) }
        prefs(ctx).edit().putString(KEY_ENTRIES, arr.toString()).apply()
    }

    private fun pending(ctx: Context, e: AdhanEntry, create: Boolean): PendingIntent? {
        val intent = Intent(ctx, AdhanReceiver::class.java).apply {
            action = ACTION_FIRE
            putExtra("id", e.id)
            putExtra("title", e.title)
            putExtra("body", e.body)
            putExtra("muezzin", e.muezzin)
            putExtra("followRinger", e.followRinger)
        }
        val flags = if (create) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        }
        return PendingIntent.getBroadcast(ctx, e.id, intent, flags)
    }

    fun arm(ctx: Context, e: AdhanEntry) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = pending(ctx, e, true) ?: return
        val showPi = PendingIntent.getActivity(
            ctx, 7, Intent(ctx, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        // setAlarmClock: دقيق، يتجاوز Doze، ولا يحتاج إذن المنبهات الدقيقة.
        am.setAlarmClock(AlarmManager.AlarmClockInfo(e.whenMs, showPi), pi)
    }

    fun schedule(ctx: Context, entries: List<AdhanEntry>): Int {
        cancelAll(ctx)
        val now = System.currentTimeMillis()
        val future = entries.filter { it.whenMs > now }
        save(ctx, future)
        future.forEach { arm(ctx, it) }
        return future.size
    }

    fun rearm(ctx: Context) {
        val now = System.currentTimeMillis()
        val future = load(ctx).filter { it.whenMs > now }
        save(ctx, future)
        future.forEach { arm(ctx, it) }
    }

    fun cancelAll(ctx: Context) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        load(ctx).forEach { e ->
            pending(ctx, e, false)?.let {
                am.cancel(it)
                it.cancel()
            }
        }
        save(ctx, emptyList())
    }
}

class AdhanReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val title = intent.getStringExtra("title") ?: "الأذان"
        val body = intent.getStringExtra("body") ?: ""
        val svc = Intent(context, AdhanService::class.java).apply {
            action = AdhanService.ACTION_PLAY
            intent.extras?.let { putExtras(it) }
        }
        try {
            ContextCompat.startForegroundService(context, svc)
        } catch (e: Exception) {
            Log.e(TAG, "startForegroundService failed", e)
            AdhanService.postFallback(context, title, body)
        }
    }
}

class AdhanBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            AdhanScheduler.rearm(context)
        } catch (e: Exception) {
            Log.e(TAG, "rearm failed", e)
        }
    }
}

class AdhanService : Service() {
    companion object {
        const val ACTION_PLAY = "com.au7md.thalab_app.ADHAN_PLAY"
        const val ACTION_STOP = "com.au7md.thalab_app.ADHAN_STOP"
        const val CHANNEL_ID = "thalab_adhan_native_v1"
        const val FALLBACK_CHANNEL_ID = "thalab_adhan_fallback_v1"
        const val NOTIF_ID = 7001

        fun ensureChannels(ctx: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val main = NotificationChannel(CHANNEL_ID, "الأذان", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "تشغيل الأذان في وقته (يحترم وضع الصامت)"
                setSound(null, null)
                enableVibration(true)
            }
            nm.createNotificationChannel(main)
            val fb = NotificationChannel(FALLBACK_CHANNEL_ID, "الأذان (احتياطي)", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "يُستعمل فقط إذا منع النظام تشغيل خدمة الأذان"
            }
            nm.createNotificationChannel(fb)
        }

        fun postFallback(ctx: Context, title: String, body: String) {
            ensureChannels(ctx)
            val open = PendingIntent.getActivity(
                ctx, 8, Intent(ctx, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            val n = NotificationCompat.Builder(ctx, FALLBACK_CHANNEL_ID)
                .setSmallIcon(ctx.applicationInfo.icon)
                .setContentTitle(title)
                .setContentText(body)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(open)
                .build()
            try {
                NotificationManagerCompat.from(ctx).notify(NOTIF_ID + 1, n)
            } catch (e: SecurityException) {
                Log.e(TAG, "no notification permission", e)
            }
        }
    }

    private var player: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var focusRequest: AudioFocusRequest? = null
    private var curTitle = "الأذان"
    private var curBody = ""
    private var useRinger = true

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            finish(keepNotification = false)
            return START_NOT_STICKY
        }
        curTitle = intent?.getStringExtra("title") ?: "الأذان"
        curBody = intent?.getStringExtra("body") ?: ""
        val muezzin = intent?.getStringExtra("muezzin") ?: ""
        useRinger = intent?.getBooleanExtra("followRinger", true) ?: true

        ensureChannels(this)
        cleanup() // لو كان أذان سابق يعمل

        try {
            val n = buildNotification(withStop = true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(NOTIF_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
            } else {
                startForeground(NOTIF_ID, n)
            }
        } catch (e: Exception) {
            Log.e(TAG, "startForeground failed", e)
            postFallback(this, curTitle, curBody)
            stopSelf()
            return START_NOT_STICKY
        }

        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "thalab:adhan").apply {
                acquire(10 * 60 * 1000L)
            }
        } catch (e: Exception) {
            Log.e(TAG, "wakelock failed", e)
        }

        val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (useRinger && audio.ringerMode != AudioManager.RINGER_MODE_NORMAL) {
            // صامت أو اهتزاز: إشعار بصري فقط (الاهتزاز تتكفل به قناة الإشعارات).
            Log.i(TAG, "ringer mode not normal -> no sound")
            finish(keepNotification = true)
            return START_NOT_STICKY
        }

        play(muezzin)
        return START_NOT_STICKY
    }

    private fun play(muezzin: String) {
        try {
            val attrs = AudioAttributes.Builder()
                .setUsage(if (useRinger) AudioAttributes.USAGE_NOTIFICATION else AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build()
            requestFocus(attrs)

            val mp = MediaPlayer()
            mp.setAudioAttributes(attrs)
            val resId = if (muezzin.isNotEmpty()) resources.getIdentifier(muezzin, "raw", packageName) else 0
            if (resId != 0) {
                val afd = resources.openRawResourceFd(resId)
                mp.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()
            } else {
                Log.w(TAG, "raw resource not found for '" + muezzin + "' -> default sound")
                mp.setDataSource(this, RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION))
            }
            mp.setOnCompletionListener { finish(keepNotification = true) }
            mp.setOnErrorListener { _, what, extra ->
                Log.e(TAG, "player error " + what + "/" + extra)
                finish(keepNotification = true)
                true
            }
            mp.setOnPreparedListener { it.start() }
            mp.prepareAsync()
            player = mp
        } catch (e: Exception) {
            Log.e(TAG, "play failed", e)
            finish(keepNotification = true)
        }
    }

    private fun requestFocus(attrs: AudioAttributes) {
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val req = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(attrs)
                .build()
            focusRequest = req
            am.requestAudioFocus(req)
        } else {
            @Suppress("DEPRECATION")
            am.requestAudioFocus(null, AudioManager.STREAM_NOTIFICATION, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
        }
    }

    private fun abandonFocus() {
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let { am.abandonAudioFocusRequest(it) }
            focusRequest = null
        } else {
            @Suppress("DEPRECATION")
            am.abandonAudioFocus(null)
        }
    }

    private fun buildNotification(withStop: Boolean): Notification {
        val open = PendingIntent.getActivity(
            this, 8, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val b = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle(curTitle)
            .setContentText(curBody)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(open)
        if (withStop) {
            val stop = PendingIntent.getService(
                this, 9, Intent(this, AdhanService::class.java).setAction(ACTION_STOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            b.addAction(0, "إيقاف الأذان", stop)
        }
        return b.build()
    }

    private fun cleanup() {
        try { player?.stop() } catch (_: Exception) {}
        try { player?.release() } catch (_: Exception) {}
        player = null
        try { abandonFocus() } catch (_: Exception) {}
        try { wakeLock?.let { if (it.isHeld) it.release() } } catch (_: Exception) {}
        wakeLock = null
    }

    private fun finish(keepNotification: Boolean) {
        cleanup()
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(Service.STOP_FOREGROUND_DETACH)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(false)
        }
        if (keepNotification) {
            nm.notify(NOTIF_ID, buildNotification(withStop = false))
        } else {
            nm.cancel(NOTIF_ID)
        }
        stopSelf()
    }

    override fun onDestroy() {
        cleanup()
        super.onDestroy()
    }
}

// =============================================================================
// القناة بين Dart و Native
// =============================================================================
object AdhanChannel {
    private const val NAME = "com.au7md.thalab_app/adhan"

    fun register(engine: FlutterEngine, host: Context) {
        val ctx = host.applicationContext
        MethodChannel(engine.dartExecutor.binaryMessenger, NAME).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "schedule" -> {
                        val list = call.argument<List<Map<String, Any?>>>("entries") ?: emptyList()
                        val entries = list.map { m ->
                            AdhanEntry(
                                id = (m["id"] as Number).toInt(),
                                whenMs = (m["whenMs"] as Number).toLong(),
                                title = m["title"] as? String ?: "",
                                body = m["body"] as? String ?: "",
                                muezzin = m["muezzin"] as? String ?: "",
                                followRinger = m["followRinger"] as? Boolean ?: true
                            )
                        }
                        result.success(AdhanScheduler.schedule(ctx, entries))
                    }
                    "cancelAll" -> {
                        AdhanScheduler.cancelAll(ctx)
                        result.success(true)
                    }
                    "scheduleTest" -> {
                        val delay = (call.argument<Number>("delaySeconds") ?: 10).toLong()
                        val e = AdhanEntry(
                            id = 9999,
                            whenMs = System.currentTimeMillis() + delay * 1000L,
                            title = call.argument<String>("title") ?: "تجربة الأذان",
                            body = call.argument<String>("body") ?: "",
                            muezzin = call.argument<String>("muezzin") ?: "",
                            followRinger = call.argument<Boolean>("followRinger") ?: true
                        )
                        AdhanScheduler.arm(ctx, e)
                        result.success(true)
                    }
                    "playNow" -> {
                        val svc = Intent(ctx, AdhanService::class.java).apply {
                            action = AdhanService.ACTION_PLAY
                            putExtra("title", call.argument<String>("title") ?: "تجربة الأذان")
                            putExtra("body", call.argument<String>("body") ?: "")
                            putExtra("muezzin", call.argument<String>("muezzin") ?: "")
                            putExtra("followRinger", call.argument<Boolean>("followRinger") ?: true)
                        }
                        ContextCompat.startForegroundService(ctx, svc)
                        result.success(true)
                    }
                    "stop" -> {
                        ctx.stopService(Intent(ctx, AdhanService::class.java))
                        (ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                            .cancel(AdhanService.NOTIF_ID)
                        result.success(true)
                    }
                    "diagnostics" -> result.success(diagnostics(ctx, call.argument<List<String>>("muezzinIds") ?: emptyList()))
                    "openBatterySettings" -> result.success(openBattery(ctx))
                    "openAutoStart" -> result.success(openAutoStart(ctx))
                    "openAppSettings" -> result.success(openAppSettings(ctx))
                    "openExactAlarmSettings" -> result.success(openExactAlarm(ctx))
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                Log.e(TAG, "channel error: " + call.method, e)
                result.error("ADHAN_ERR", e.message, null)
            }
        }
    }

    private fun diagnostics(ctx: Context, muezzinIds: List<String>): HashMap<String, Any?> {
        val out = HashMap<String, Any?>()
        out["notificationsEnabled"] = NotificationManagerCompat.from(ctx).areNotificationsEnabled()

        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        out["canExact"] = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) am.canScheduleExactAlarms() else true

        val pm = ctx.getSystemService(Context.POWER_SERVICE) as PowerManager
        out["batteryIgnored"] = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            pm.isIgnoringBatteryOptimizations(ctx.packageName)
        } else true

        val audio = ctx.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        out["ringer"] = when (audio.ringerMode) {
            AudioManager.RINGER_MODE_NORMAL -> "normal"
            AudioManager.RINGER_MODE_VIBRATE -> "vibrate"
            else -> "silent"
        }

        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        out["dnd"] = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            nm.currentInterruptionFilter != NotificationManager.INTERRUPTION_FILTER_ALL
        } else false

        val entries = AdhanScheduler.load(ctx)
        out["scheduledCount"] = entries.size
        out["nextAlarmMs"] = entries.minByOrNull { it.whenMs }?.whenMs ?: 0L

        val raw = HashMap<String, Boolean>()
        muezzinIds.forEach { raw[it] = ctx.resources.getIdentifier(it, "raw", ctx.packageName) != 0 }
        out["rawFound"] = raw

        out["device"] = Build.MANUFACTURER + " " + Build.MODEL
        out["sdk"] = Build.VERSION.SDK_INT
        return out
    }

    private fun start(ctx: Context, i: Intent): Boolean = try {
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        ctx.startActivity(i)
        true
    } catch (e: Exception) {
        false
    }

    private fun openAppSettings(ctx: Context): Boolean =
        start(ctx, Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:" + ctx.packageName)))

    private fun openBattery(ctx: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (start(ctx, Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:" + ctx.packageName)))) return true
            if (start(ctx, Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))) return true
        }
        return openAppSettings(ctx)
    }

    private fun openExactAlarm(ctx: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return start(ctx, Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:" + ctx.packageName)))
        }
        return false
    }

    // شاشات "التشغيل التلقائي" الخاصة بـ Oppo / ColorOS / Realme
    private fun openAutoStart(ctx: Context): Boolean {
        val candidates = listOf(
            "com.coloros.safecenter" to "com.coloros.safecenter.permission.startup.StartupAppListActivity",
            "com.coloros.safecenter" to "com.coloros.safecenter.startupapp.StartupAppListActivity",
            "com.coloros.safecenter" to "com.coloros.safecenter.permission.startupapp.StartupAppListActivity",
            "com.oppo.safe" to "com.oppo.safe.permission.startup.StartupAppListActivity",
            "com.coloros.oppoguardelf" to "com.coloros.powermanager.fuelgaue.PowerUsageModelActivity"
        )
        for (c in candidates) {
            val i = Intent().setComponent(ComponentName(c.first, c.second))
            if (start(ctx, i)) return true
        }
        return false
    }
}
