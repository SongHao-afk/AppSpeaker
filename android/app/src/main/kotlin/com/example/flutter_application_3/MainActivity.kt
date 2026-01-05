package com.example.flutter_application_3

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.*
import android.media.audiofx.AutomaticGainControl
import android.media.audiofx.NoiseSuppressor
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlin.math.*

class MainActivity : FlutterActivity() {
  private val CHANNEL = "loopback"
  private val EVENTS = "loopback_events"

  private lateinit var audioManager: AudioManager

  private val mainHandler = Handler(Looper.getMainLooper())

  private var thread: Thread? = null
  @Volatile private var running = false

  private var recorder: AudioRecord? = null
  private var player: AudioTrack? = null

  // AudioFX (for wired mic boost/cleanup)
  private var agc: AutomaticGainControl? = null
  private var ns: NoiseSuppressor? = null

  // EventChannel sink (RMS)
  @Volatile private var eventSink: EventChannel.EventSink? = null

  // Params from Flutter
  @Volatile private var eqEnabled: Boolean = true
  @Volatile private var outputGain: Double = 1.0
  @Volatile private var bandGains: DoubleArray =
    doubleArrayOf(1.0, 1.0, 1.0, 1.0, 1.0)

  // SCO wait
  private var scoReceiver: BroadcastReceiver? = null
  @Volatile private var pendingStartToken: Int = 0

  override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
      .setMethodCallHandler { call, result ->
        try {
          when (call.method) {
            "start" -> {
              val voiceMode = call.argument<Boolean>("voiceMode") ?: false
              startLoopback(voiceMode)
              result.success(null)
            }
            "stop" -> {
              stopLoopback()
              result.success(null)
            }
            "setParams" -> {
              val enabled = call.argument<Boolean>("eqEnabled") ?: true
              val outGain = (call.argument<Number>("outputGain") ?: 1.0).toDouble()
              val list = call.argument<List<Number>>("bandGains") ?: listOf(1, 1, 1, 1, 1)

              eqEnabled = enabled
              outputGain = outGain.coerceIn(0.0, 8.0)

              val arr = DoubleArray(5)
              for (i in 0 until 5) {
                val v = if (i < list.size) list[i].toDouble() else 1.0
                arr[i] = v.coerceIn(0.25, 3.0)
              }
              bandGains = arr
              result.success(null)
            }
            else -> result.notImplemented()
          }
        } catch (e: Exception) {
          result.error("ERR", e.message, null)
        }
      }

    EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENTS)
      .setStreamHandler(object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
          eventSink = events
        }
        override fun onCancel(arguments: Any?) {
          eventSink = null
        }
      })
  }

  private fun startLoopback(voiceMode: Boolean) {
    stopLoopback()
    pendingStartToken++

    // Always avoid forcing speakerphone when BT is expected
    try { audioManager.isSpeakerphoneOn = false } catch (_: Exception) {}

    if (!voiceMode) {
      // ✅ A2DP auto-route (stable for BT speakers)
      safeStopSco()
      safeSetModeNormal()
      startEngine(sampleRate = 48000, voicePath = false, token = pendingStartToken)
      return
    }

    // ✅ SCO realtime ~0.1s (headset)
    safeSetModeInCommunication()

    // Wait for SCO connected before starting engine
    val token = pendingStartToken

    val filter = IntentFilter(AudioManager.ACTION_SCO_AUDIO_STATE_UPDATED)
    scoReceiver = object : BroadcastReceiver() {
      override fun onReceive(context: Context?, intent: Intent?) {
        val state = intent?.getIntExtra(AudioManager.EXTRA_SCO_AUDIO_STATE, -1) ?: -1
        if (token != pendingStartToken) {
          try { unregisterReceiver(this) } catch (_: Exception) {}
          scoReceiver = null
          return
        }

        if (state == AudioManager.SCO_AUDIO_STATE_CONNECTED) {
          try { audioManager.isBluetoothScoOn = true } catch (_: Exception) {}
          try { unregisterReceiver(this) } catch (_: Exception) {}
          scoReceiver = null

          startEngine(sampleRate = 16000, voicePath = true, token = token)
        }
      }
    }

    try {
      registerReceiver(scoReceiver, filter)
      audioManager.startBluetoothSco()
    } catch (_: Exception) {
      // fallback A2DP
      try { scoReceiver?.let { unregisterReceiver(it) } } catch (_: Exception) {}
      scoReceiver = null
      safeStopSco()
      safeSetModeNormal()
      startEngine(sampleRate = 48000, voicePath = false, token = token)
    }
  }

  private fun startEngine(sampleRate: Int, voicePath: Boolean, token: Int) {
    if (token != pendingStartToken) return

    val channelIn = AudioFormat.CHANNEL_IN_MONO
    val channelOut = AudioFormat.CHANNEL_OUT_MONO
    val encoding = AudioFormat.ENCODING_PCM_16BIT

    val recMin = AudioRecord.getMinBufferSize(sampleRate, channelIn, encoding)
    val playMin = AudioTrack.getMinBufferSize(sampleRate, channelOut, encoding)
    val bufferSize = maxOf(recMin, playMin, sampleRate / 50) // ~20ms

    // ✅ Detect wired/USB headset (không đụng Bluetooth)
    val wiredOut = findWiredOutput()
    val wiredIn = findWiredInput()
    val wiredPresent = (!voicePath) && (wiredOut != null || wiredIn != null)

    // =========================
    // ✅ FIX CHÍNH:
    // Khi cắm tai nghe có dây, mic tai nghe thường "rè cực to" + giọng cực nhỏ.
    // -> Không dùng VOICE_RECOGNITION nữa trong case wired.
    // -> Giữ MIC, rồi ép INPUT về BUILTIN_MIC (mic máy).
    // =========================
    val audioSource =
      if (voicePath) MediaRecorder.AudioSource.VOICE_COMMUNICATION
      else MediaRecorder.AudioSource.MIC

    recorder = AudioRecord.Builder()
      .setAudioSource(audioSource)
      .setAudioFormat(
        AudioFormat.Builder()
          .setEncoding(encoding)
          .setSampleRate(sampleRate)
          .setChannelMask(channelIn)
          .build()
      )
      .setBufferSizeInBytes(bufferSize)
      .build()

    // ✅ Enable AGC/NS:
    // - Chỉ bật khi voicePath (SCO/voice processing) để tránh bơm noise ở wired
    // - Wired: tắt AGC/NS để khỏi "rè + hiss" (đặc biệt khi đường mic tai nghe bẩn)
    if (voicePath) {
      try {
        agc = AutomaticGainControl.create(recorder?.audioSessionId ?: 0)
        agc?.enabled = true
      } catch (_: Exception) {
        agc = null
      }
      try {
        ns = NoiseSuppressor.create(recorder?.audioSessionId ?: 0)
        ns?.enabled = true
      } catch (_: Exception) {
        ns = null
      }
    } else {
      // wired/normal: đảm bảo không giữ instance cũ
      try { agc?.release() } catch (_: Exception) {}
      agc = null
      try { ns?.release() } catch (_: Exception) {}
      ns = null
    }

    val attrs = AudioAttributes.Builder()
      .setUsage(
        if (voicePath) AudioAttributes.USAGE_VOICE_COMMUNICATION
        else AudioAttributes.USAGE_MEDIA
      )
      .setContentType(
        if (voicePath) AudioAttributes.CONTENT_TYPE_SPEECH
        else AudioAttributes.CONTENT_TYPE_MUSIC
      )
      .build()

    val format = AudioFormat.Builder()
      .setEncoding(encoding)
      .setSampleRate(sampleRate)
      .setChannelMask(channelOut)
      .build()

    player = AudioTrack.Builder()
      .setAudioAttributes(attrs)
      .setAudioFormat(format)
      .setTransferMode(AudioTrack.MODE_STREAM)
      .setBufferSizeInBytes(bufferSize)
      .build()

    // ✅ Ép route:
    // - OUTPUT: ra tai nghe có dây nếu có
    // - INPUT: nếu wiredPresent -> ép về BUILTIN_MIC (để giọng không bị nhỏ + rè)
    routeToWiredIfPresent(recorder, player, wiredPresent)

    // Optional: đảm bảo track volume không bị 0 ở vài ROM
    try { player?.setVolume(1.0f) } catch (_: Exception) {}

    val eq = Eq5Band(sampleRate.toDouble())

    running = true
    thread = Thread {
      Process.setThreadPriority(Process.THREAD_PRIORITY_AUDIO)

      val rec = recorder ?: return@Thread
      val out = player ?: return@Thread
      val buf = ShortArray(bufferSize / 2)

      var lastEqEnabled = eqEnabled
      var lastGain = outputGain
      var lastBands = bandGains.copyOf()

      fun refreshEqIfChanged() {
        val en = eqEnabled
        val g = outputGain
        val b = bandGains

        var changed = false
        if (en != lastEqEnabled || g != lastGain) changed = true
        else for (i in 0 until 5) if (b[i] != lastBands[i]) { changed = true; break }

        if (changed) {
          lastEqEnabled = en
          lastGain = g
          lastBands = b.copyOf()

          val db = DoubleArray(5) { i ->
            val gi = lastBands[i].coerceAtLeast(0.0001)
            20.0 * ln(gi) / ln(10.0)
          }
          eq.updateGainsDb(db)
        }
      }

      var lastMeterTs = 0L

      rec.startRecording()
      out.play()

      while (running) {
        val n = rec.read(buf, 0, buf.size, AudioRecord.READ_BLOCKING)
        if (n <= 0) continue

        refreshEqIfChanged()

        val en = lastEqEnabled
        val g = lastGain

        var sumSq = 0.0

        if (en) {
          for (i in 0 until n) {
            var x = buf[i].toDouble() / 32768.0
            x = eq.process(x)
            x *= g
            x = softClip(x)

            val y = (x * 32767.0).roundToInt().coerceIn(-32768, 32767).toShort()
            buf[i] = y

            val yf = y.toDouble() / 32768.0
            sumSq += yf * yf
          }
        } else {
          for (i in 0 until n) {
            var x = buf[i].toDouble() / 32768.0
            x *= g
            x = softClip(x)

            val y = (x * 32767.0).roundToInt().coerceIn(-32768, 32767).toShort()
            buf[i] = y

            val yf = y.toDouble() / 32768.0
            sumSq += yf * yf
          }
        }

        out.write(buf, 0, n)

        val now = System.currentTimeMillis()
        if (now - lastMeterTs > 50) {
          lastMeterTs = now
          val rms = sqrt(sumSq / n.toDouble()).coerceIn(0.0, 1.0)

          // ✅ FIX: EventChannel phải gọi trên MAIN thread
          mainHandler.post {
            eventSink?.success(rms)
          }
        }
      }

      try { rec.stop() } catch (_: Exception) {}
      try { out.stop() } catch (_: Exception) {}
    }.also { it.start() }
  }

  private fun stopLoopback() {
    pendingStartToken++

    running = false
    try { thread?.join(400) } catch (_: Exception) {}
    thread = null

    try { agc?.release() } catch (_: Exception) {}
    agc = null
    try { ns?.release() } catch (_: Exception) {}
    ns = null

    try { recorder?.release() } catch (_: Exception) {}
    recorder = null

    try { player?.release() } catch (_: Exception) {}
    player = null

    try { scoReceiver?.let { unregisterReceiver(it) } } catch (_: Exception) {}
    scoReceiver = null

    safeStopSco()
    safeSetModeNormal()
    try { audioManager.isSpeakerphoneOn = false } catch (_: Exception) {}
  }

  private fun safeStopSco() {
    try { audioManager.isBluetoothScoOn = false } catch (_: Exception) {}
    try { audioManager.stopBluetoothSco() } catch (_: Exception) {}
  }

  private fun safeSetModeNormal() {
    try { audioManager.mode = AudioManager.MODE_NORMAL } catch (_: Exception) {}
  }

  private fun safeSetModeInCommunication() {
    try { audioManager.mode = AudioManager.MODE_IN_COMMUNICATION } catch (_: Exception) {}
  }

  // ===== WIRED/USB ROUTE FIX =====
  private fun findWiredOutput(): AudioDeviceInfo? {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return null
    val outs = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
    return outs.firstOrNull { it.type == AudioDeviceInfo.TYPE_USB_HEADSET }
      ?: outs.firstOrNull {
        it.type == AudioDeviceInfo.TYPE_WIRED_HEADPHONES ||
        it.type == AudioDeviceInfo.TYPE_WIRED_HEADSET
      }
  }

  private fun findWiredInput(): AudioDeviceInfo? {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return null
    val ins = audioManager.getDevices(AudioManager.GET_DEVICES_INPUTS)
    return ins.firstOrNull { it.type == AudioDeviceInfo.TYPE_USB_HEADSET }
      ?: ins.firstOrNull { it.type == AudioDeviceInfo.TYPE_WIRED_HEADSET }
  }

  // ✅ NEW: tìm mic máy để ép input khi wiredPresent
  private fun findBuiltInMic(): AudioDeviceInfo? {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return null
    val ins = audioManager.getDevices(AudioManager.GET_DEVICES_INPUTS)
    return ins.firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_MIC }
  }

  // ✅ CHỈ THAY ĐỔI SIGNATURE (giữ logic cũ + thêm wiredPresent)
  private fun routeToWiredIfPresent(rec: AudioRecord?, out: AudioTrack?, wiredPresent: Boolean) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return

    val wiredOut = findWiredOutput()
    val wiredIn = findWiredInput()
    val builtInMic = findBuiltInMic()

    // OUTPUT: nếu có tai nghe có dây/USB -> ép output ra đó
    try {
      if (wiredOut != null && out != null) {
        out.preferredDevice = wiredOut
      }
    } catch (_: Exception) {}

    // INPUT:
    // - Nếu wiredPresent: ép về mic máy (BUILTIN_MIC) để tránh "rè cực to + giọng nhỏ"
    // - Nếu không wired: vẫn giữ behavior cũ (có wiredIn thì set)
    try {
      if (wiredPresent && builtInMic != null && rec != null) {
        rec.preferredDevice = builtInMic
      } else if (wiredIn != null && rec != null) {
        rec.preferredDevice = wiredIn
      }
    } catch (_: Exception) {}
  }

  private fun softClip(xIn: Double): Double {
    var x = xIn
    if (x > 1.2) x = 1.2
    if (x < -1.2) x = -1.2
    val y = x - (x * x * x) / 3.0
    return y.coerceIn(-1.0, 1.0)
  }
}

// ===== BIQUAD EQ =====

private class Biquad {
  private var b0 = 1.0
  private var b1 = 0.0
  private var b2 = 0.0
  private var a1 = 0.0
  private var a2 = 0.0
  private var z1 = 0.0
  private var z2 = 0.0

  fun process(x: Double): Double {
    val y = b0 * x + z1
    z1 = b1 * x - a1 * y + z2
    z2 = b2 * x - a2 * y
    return y
  }

  private fun setNorm(b0u: Double, b1u: Double, b2u: Double, a0u: Double, a1u: Double, a2u: Double) {
    val inv = 1.0 / a0u
    b0 = b0u * inv
    b1 = b1u * inv
    b2 = b2u * inv
    a1 = a1u * inv
    a2 = a2u * inv
  }

  fun setPeaking(fs: Double, f0: Double, q: Double, gainDb: Double) {
    val A = 10.0.pow(gainDb / 40.0)
    val w0 = 2.0 * Math.PI * (f0 / fs)
    val cw = cos(w0)
    val sw = sin(w0)
    val alpha = sw / (2.0 * q)

    val b0u = 1.0 + alpha * A
    val b1u = -2.0 * cw
    val b2u = 1.0 - alpha * A
    val a0u = 1.0 + alpha / A
    val a1u = -2.0 * cw
    val a2u = 1.0 - alpha / A
    setNorm(b0u, b1u, b2u, a0u, a1u, a2u)
  }

  fun setLowShelf(fs: Double, f0: Double, slope: Double, gainDb: Double) {
    val A = 10.0.pow(gainDb / 40.0)
    val w0 = 2.0 * Math.PI * (f0 / fs)
    val cw = cos(w0)
    val sw = sin(w0)
    val sqrtA = sqrt(A)
    val alpha = sw / 2.0 * sqrt((A + 1.0 / A) * (1.0 / slope - 1.0) + 2.0)

    val b0u = A * ((A + 1) - (A - 1) * cw + 2 * sqrtA * alpha)
    val b1u = 2 * A * ((A - 1) - (A + 1) * cw)
    val b2u = A * ((A + 1) - (A - 1) * cw - 2 * sqrtA * alpha)
    val a0u = (A + 1) + (A - 1) * cw + 2 * sqrtA * alpha
    val a1u = -2 * ((A - 1) + (A + 1) * cw)
    val a2u = (A + 1) + (A - 1) * cw - 2 * sqrtA * alpha
    setNorm(b0u, b1u, b2u, a0u, a1u, a2u)
  }

  fun setHighShelf(fs: Double, f0: Double, slope: Double, gainDb: Double) {
    val A = 10.0.pow(gainDb / 40.0)
    val w0 = 2.0 * Math.PI * (f0 / fs)
    val cw = cos(w0)
    val sw = sin(w0)
    val sqrtA = sqrt(A)
    val alpha = sw / 2.0 * sqrt((A + 1.0 / A) * (1.0 / slope - 1.0) + 2.0)

    val b0u = A * ((A + 1) + (A - 1) * cw + 2 * sqrtA * alpha)
    val b1u = -2 * A * ((A - 1) + (A + 1) * cw)
    val b2u = A * ((A + 1) + (A - 1) * cw - 2 * sqrtA * alpha)
    val a0u = (A + 1) - (A - 1) * cw + 2 * sqrtA * alpha
    val a1u = 2 * ((A - 1) - (A + 1) * cw)
    val a2u = (A + 1) - (A - 1) * cw - 2 * sqrtA * alpha
    setNorm(b0u, b1u, b2u, a0u, a1u, a2u)
  }
}

private class Eq5Band(private val fs: Double) {
  private val low = Biquad()
  private val m1 = Biquad()
  private val m2 = Biquad()
  private val m3 = Biquad()
  private val high = Biquad()

  fun updateGainsDb(db: DoubleArray) {
    low.setLowShelf(fs, 60.0, 1.0, db[0])
    m1.setPeaking(fs, 230.0, 1.0, db[1])
    m2.setPeaking(fs, 910.0, 1.0, db[2])
    m3.setPeaking(fs, 3600.0, 1.0, db[3])
    high.setHighShelf(fs, 14000.0, 1.0, db[4])
  }

  fun process(x: Double): Double {
    var y = x
    y = low.process(y)
    y = m1.process(y)
    y = m2.process(y)
    y = m3.process(y)
    y = high.process(y)
    return y
  }
}
