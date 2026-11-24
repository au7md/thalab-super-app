package com.au7md.thalab_app

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadata
import android.media.MediaMuxer
import android.media.MediaRecorder
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.nio.ByteBuffer

class MainActivity : FlutterActivity() {

    private val AUDIO_CHANNEL = "com.au7md.thalab_app/audio_studio"
    private val VOLUME_CHANNEL = "com.au7md.thalab_app/system_volume"
    private val NOTIF_CHANNEL_ID = "thalab_media_player_channel"
    private val NOTIF_ID = 9091

    private var audioMethodChannel: MethodChannel? = null
    private var mediaSession: MediaSession? = null

    private var mediaRecorder: MediaRecorder? = null
    private var currentRecordPath: String? = null
    private var currentRecordTitle: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        createNotificationChannel()
        initMediaSession()

        // قناة التحكم في صوت الجهاز (مشغل الفيديو)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOLUME_CHANNEL)
            .setMethodCallHandler { call, result ->
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC).toDouble()
                when (call.method) {
                    "getVolume" -> {
                        val cur = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC).toDouble()
                        result.success(if (maxVol > 0) cur / maxVol else 0.5)
                    }
                    "setVolume" -> {
                        val vol = (call.argument<Double>("volume") ?: 0.5).coerceIn(0.0, 1.0)
                        val target = (vol * maxVol).toInt()
                        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, target, 0)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // قناة استوديو الصوتيات والمشغل التفاعلي
        audioMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AUDIO_CHANNEL)
        audioMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceAudios" -> result.success(fetchDeviceAudios())
                "hasRecordPermission" -> result.success(checkAndRequestMicPermission())
                "startRecord" -> {
                    val path = call.argument<String>("path") ?: ""
                    val title = call.argument<String>("title") ?: "Thalab_Record"
                    result.success(startRecording(path, title))
                }
                "pauseRecord" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        mediaRecorder?.pause()
                    }
                    result.success(true)
                }
                "resumeRecord" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        mediaRecorder?.resume()
                    }
                    result.success(true)
                }
                "stopRecord" -> result.success(stopAndSaveRecording())
                "cancelRecord" -> {
                    cancelRecording()
                    result.success(true)
                }
                "getAmplitude" -> {
                    val amp = try {
                        (mediaRecorder?.maxAmplitude ?: 0) / 32767.0
                    } catch (_: Exception) {
                        0.2
                    }
                    result.success(amp.coerceIn(0.1, 1.0))
                }
                "exportToMusicFolder" -> {
                    val src = call.argument<String>("srcPath") ?: ""
                    val title = call.argument<String>("title") ?: "Thalab_Audio"
                    val subFolder = call.argument<String>("subFolder") ?: "Thalab Recordings"
                    result.success(saveToPublicMusic(src, title, subFolder))
                }
                "processAudioEdit" -> {
                    val src = call.argument<String>("srcPath") ?: ""
                    val dst = call.argument<String>("dstPath") ?: ""
                    val mode = call.argument<String>("mode") ?: "keep"
                    val startMs = call.argument<Int>("startMs") ?: 0
                    val endMs = call.argument<Int>("endMs") ?: 0
                    result.success(trimAudioFile(src, dst, mode, startMs.toLong(), endMs.toLong()))
                }
                "updateMediaNotification" -> {
                    val title = call.argument<String>("title") ?: "ملف صوتي"
                    val subtitle = call.argument<String>("subtitle") ?: "الثعلب"
                    val isPlaying = call.argument<Boolean>("isPlaying") ?: false
                    val durationMs = (call.argument<Number>("durationMs") ?: 0).toLong()
                    val positionMs = (call.argument<Number>("positionMs") ?: 0).toLong()
                    updateMediaNotification(title, subtitle, isPlaying, durationMs, positionMs)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    // =========================================================================
    // مشغل الإشعارات التفاعلي (MediaSession + شريط السحب + أزرار ±10 ثوانٍ)
    // =========================================================================
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIF_CHANNEL_ID,
                "مشغل صوتيات الثعلب",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "التحكم في تشغيل الصوتيات من شريط الإشعارات"
                setShowBadge(false)
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }

    private fun initMediaSession() {
        mediaSession = MediaSession(this, "ThalabAudioSession").apply {
            setCallback(object : MediaSession.Callback() {
                override fun onPlay() {
                    audioMethodChannel?.invokeMethod("onMediaAction", "play_pause")
                }

                override fun onPause() {
                    audioMethodChannel?.invokeMethod("onMediaAction", "play_pause")
                }

                override fun onSkipToNext() {
                    audioMethodChannel?.invokeMethod("onMediaAction", "next")
                }

                override fun onSkipToPrevious() {
                    audioMethodChannel?.invokeMethod("onMediaAction", "prev")
                }

                override fun onRewind() {
                    audioMethodChannel?.invokeMethod("onMediaAction", "rewind_10")
                }

                override fun onFastForward() {
                    audioMethodChannel?.invokeMethod("onMediaAction", "forward_10")
                }

                override fun onSeekTo(pos: Long) {
                    audioMethodChannel?.invokeMethod(
                        "onMediaAction",
                        mapOf("action" to "seekTo", "positionMs" to pos)
                    )
                }

                override fun onCustomAction(action: String, extras: Bundle?) {
                    when (action) {
                        "rewind_10", "forward_10" ->
                            audioMethodChannel?.invokeMethod("onMediaAction", action)
                    }
                }
            })
            isActive = true
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val action = intent.getStringExtra("media_action") ?: return
        audioMethodChannel?.invokeMethod("onMediaAction", action)
    }

    private fun buildActionIntent(action: String, reqCode: Int): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("media_action", action)
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getActivity(this, reqCode, intent, flags)
    }

    private fun updateMediaNotification(
        title: String,
        subtitle: String,
        isPlaying: Boolean,
        durationMs: Long,
        positionMs: Long
    ) {
        val session = mediaSession ?: return

        val stateCode = if (isPlaying) PlaybackState.STATE_PLAYING else PlaybackState.STATE_PAUSED
        val stateBuilder = PlaybackState.Builder()
            .setActions(
                PlaybackState.ACTION_PLAY or
                    PlaybackState.ACTION_PAUSE or
                    PlaybackState.ACTION_PLAY_PAUSE or
                    PlaybackState.ACTION_SKIP_TO_NEXT or
                    PlaybackState.ACTION_SKIP_TO_PREVIOUS or
                    PlaybackState.ACTION_SEEK_TO or
                    PlaybackState.ACTION_REWIND or
                    PlaybackState.ACTION_FAST_FORWARD
            )
            .setState(stateCode, positionMs, if (isPlaying) 1.0f else 0.0f)

        session.setPlaybackState(stateBuilder.build())
        session.setMetadata(
            MediaMetadata.Builder()
                .putString(MediaMetadata.METADATA_KEY_TITLE, title)
                .putString(MediaMetadata.METADATA_KEY_ARTIST, subtitle)
                .putLong(MediaMetadata.METADATA_KEY_DURATION, durationMs)
                .build()
        )

        val openAppIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, NOTIF_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        val playPauseIcon = if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
        val playPauseLabel = if (isPlaying) "إيقاف" else "تشغيل"

        builder.setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle(title)
            .setContentText(subtitle)
            .setContentIntent(openAppIntent)
            .setOngoing(isPlaying)
            .setOnlyAlertOnce(true)
            .addAction(
                Notification.Action.Builder(
                    android.R.drawable.ic_media_rew, "-10ث", buildActionIntent("rewind_10", 11)
                ).build()
            )
            .addAction(
                Notification.Action.Builder(
                    android.R.drawable.ic_media_previous, "السابق", buildActionIntent("prev", 12)
                ).build()
            )
            .addAction(
                Notification.Action.Builder(
                    playPauseIcon, playPauseLabel, buildActionIntent("play_pause", 13)
                ).build()
            )
            .addAction(
                Notification.Action.Builder(
                    android.R.drawable.ic_media_next, "التالي", buildActionIntent("next", 14)
                ).build()
            )
            .addAction(
                Notification.Action.Builder(
                    android.R.drawable.ic_media_ff, "+10ث", buildActionIntent("forward_10", 15)
                ).build()
            )
            .setStyle(
                Notification.MediaStyle()
                    .setMediaSession(session.sessionToken)
                    .setShowActionsInCompactView(1, 2, 3)
            )

        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIF_ID, builder.build())
    }

    // =========================================================================
    // جلب الصوتيات + التسجيل + الحفظ في Music + قص الصوت
    // =========================================================================
    private fun fetchDeviceAudios(): List> {
        val list = mutableListOf>()
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.DATE_ADDED
        )
        val selection = "${MediaStore.Audio.Media.IS_MUSIC} != 0"
        contentResolver.query(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            projection,
            selection,
            null,
            "${MediaStore.Audio.Media.DATE_ADDED} DESC"
        )?.use { cursor ->
            val idCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val titleCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
            val artistCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
            val dataCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)
            val durCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
            val dateCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_ADDED)

            while (cursor.moveToNext()) {
                val path = cursor.getString(dataCol) ?: continue
                val folder = File(path).parentFile?.name ?: "ملفات صوتية"
                list.add(
                    mapOf(
                        "id" to cursor.getLong(idCol).toString(),
                        "title" to (cursor.getString(titleCol) ?: "ملف صوتي"),
                        "artist" to (cursor.getString(artistCol) ?: folder),
                        "folder" to folder,
                        "path" to path,
                        "durationSec" to (cursor.getLong(durCol) / 1000L).toInt(),
                        "dateAdded" to cursor.getLong(dateCol).toInt()
                    )
                )
            }
        }
        return list
    }

    private fun checkAndRequestMicPermission(): Boolean {
        val granted = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        if (!granted) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.RECORD_AUDIO), 404)
        }
        return granted
    }

    private fun startRecording(path: String, title: String): Boolean {
        return try {
            currentRecordPath = path
            currentRecordTitle = title
            mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(this)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioEncodingBitRate(128000)
                setAudioSamplingRate(44100)
                setOutputFile(path)
                prepare()
                start()
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun stopAndSaveRecording(): String? {
        return try {
            mediaRecorder?.stop()
            mediaRecorder?.release()
            mediaRecorder = null
            val path = currentRecordPath
            val title = currentRecordTitle ?: "Thalab_Record"
            if (path != null) {
                saveToPublicMusic(path, title, "Thalab Recordings")
            }
            path
        } catch (_: Exception) {
            null
        }
    }

    private fun cancelRecording() {
        try {
            mediaRecorder?.stop()
        } catch (_: Exception) {}
        mediaRecorder?.release()
        mediaRecorder = null
        currentRecordPath?.let { File(it).delete() }
        currentRecordPath = null
    }

    private fun saveToPublicMusic(srcPath: String, title: String, subFolder: String): Boolean {
        val srcFile = File(srcPath)
        if (!srcFile.exists()) return false
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.Audio.Media.DISPLAY_NAME, "$title.m4a")
                    put(MediaStore.Audio.Media.MIME_TYPE, "audio/mp4")
                    put(
                        MediaStore.Audio.Media.RELATIVE_PATH,
                        "${Environment.DIRECTORY_MUSIC}/$subFolder"
                    )
                }
                val uri = contentResolver.insert(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, values)
                if (uri != null) {
                    contentResolver.openOutputStream(uri)?.use { out ->
                        FileInputStream(srcFile).use { input -> input.copyTo(out) }
                    }
                    return true
                }
            }
            val destDir = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC),
                subFolder
            )
            if (!destDir.exists()) destDir.mkdirs()
            srcFile.copyTo(File(destDir, "$title.m4a"), overwrite = true)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun trimAudioFile(
        srcPath: String,
        dstPath: String,
        mode: String,
        startMs: Long,
        endMs: Long
    ): Boolean {
        return try {
            val extractor = MediaExtractor()
            extractor.setDataSource(srcPath)
            var audioTrackIndex = -1
            var format: MediaFormat? = null
            for (i in 0 until extractor.trackCount) {
                val f = extractor.getTrackFormat(i)
                val mime = f.getString(MediaFormat.KEY_MIME) ?: ""
                if (mime.startsWith("audio/")) {
                    audioTrackIndex = i
                    format = f
                    break
                }
            }
            if (audioTrackIndex == -1 || format == null) {
                extractor.release()
                return false
            }

            extractor.selectTrack(audioTrackIndex)
            val muxer = MediaMuxer(dstPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            val muxTrack = muxer.addTrack(format)
            muxer.start()

            val buffer = ByteBuffer.allocate(256 * 1024)
            val info = android.media.MediaCodec.BufferInfo()
            val startUs = startMs * 1000L
            val endUs = endMs * 1000L

            if (mode == "keep") {
                extractor.seekTo(startUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
                while (true) {
                    val sampleSize = extractor.readSampleData(buffer, 0)
                    if (sampleSize < 0) break
                    val sampleTime = extractor.sampleTime
                    if (sampleTime > endUs) break
                    info.offset = 0
                    info.size = sampleSize
                    info.presentationTimeUs = (sampleTime - startUs).coerceAtLeast(0L)
                    info.flags = extractor.sampleFlags
                    muxer.writeSampleData(muxTrack, buffer, info)
                    extractor.advance()
                }
            } else {
                // وضع حذف الجزء المحدد (cut)
                var timeOffsetUs = 0L
                while (true) {
                    val sampleSize = extractor.readSampleData(buffer, 0)
                    if (sampleSize < 0) break
                    val sampleTime = extractor.sampleTime
                    if (sampleTime in startUs..endUs) {
                        extractor.advance()
                        continue
                    }
                    val adjustedTime = if (sampleTime > endUs) {
                        sampleTime - (endUs - startUs)
                    } else {
                        sampleTime
                    }
                    info.offset = 0
                    info.size = sampleSize
                    info.presentationTimeUs = adjustedTime.coerceAtLeast(timeOffsetUs)
                    timeOffsetUs = info.presentationTimeUs
                    info.flags = extractor.sampleFlags
                    muxer.writeSampleData(muxTrack, buffer, info)
                    extractor.advance()
                }
            }

            muxer.stop()
            muxer.release()
            extractor.release()
            true
        } catch (_: Exception) {
            false
        }
    }

    override fun onDestroy() {
        mediaSession?.release()
        super.onDestroy()
    }
}
