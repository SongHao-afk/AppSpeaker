// MainActivity.kt
package com.example.flutter_application_3

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothHeadset
import android.bluetooth.BluetoothProfile
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.*
import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.AutomaticGainControl
import android.media.audiofx.NoiseSuppressor
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlin.math.*

class MainActivity : FlutterActivity() {

  private val CHANNEL = "loopback"
  private val EVENTS = "loopback_events"

  companion object {
    private const val TAG = "MainActivity"
  }

  private lateinit var audioManager: AudioManager
  private val mainHandler = Handler(Looper.getMainLooper())

  private var thread: Thread? = null
  @Volatile private var running = false

  private var recorder: AudioRecord? = null
  private var player: AudioTrack? = null

  // AudioFX
  private var aec: AcousticEchoCanceler? = null
  private var agc: AutomaticGainControl? = null
  private var ns: NoiseSuppressor? = null

  // RMS sink
  @Volatile private var eventSink: EventChannel.EventSink? = null

  // Params from Flutter
  @Volatile private var eqEnabled: Boolean = true

  // ✅ IMPORTANT: allow bigger gain (real loudness comes from digital gain, not setVolume)
  @Volatile private var outputGain: Double = 1.0
  @Volatile private var bandGains: DoubleArray = doubleArrayOf(1.0, 1.0, 1.0, 1.0, 1.0)

  // ✅ ADDED: master boost knob (extra loudness)
  @Volatile private var masterBoost: Double = 1.0

  // SCO wait
  private var scoReceiver: BroadcastReceiver? = null
  @Volatile private var pendingStartToken: Int = 0

  // ===== Hot route on wired plug/unplug (ADDED) =====
  private var deviceCallback: AudioDeviceCallback? = null
  @Volatile private var lastVoiceModeRequested: Boolean = false
  @Volatile private var lastVoicePath: Boolean = false
  @Volatile private var lastSampleRate: Int = 48000

  // ===== INPUT SELECT (ADDED) =====
  @Volatile private var preferWiredMic: Boolean = false
  @Volatile private var headsetMicBoost: Double = 3.0

  // ================== ✅ Anti-feedback tuning for A2DP ==================
  // Lưu ý: muốn to hơn A2DP thì tăng cap nhẹ, nhưng vẫn giữ guard+duck để khỏi hú.
  private val A2DP_SAFE_GAIN_CAP = 0.55   // was 0.42 (too quiet)
  private val FEEDBACK_RMS_THRESHOLD = 0.22
  private val FEEDBACK_RISE_THRESHOLD = 0.05
  private val GUARD_MIN = 0.03

  private val A2DP_MUTE_MS = 40
  private val A2DP_HARD_MUTE_RMS = 0.55
  // ====================================================================

  // ================== ✅ Speaker default voice SR ==================
  private val SPEAKER_VOICE_SR = 48000
  // ================================================================

  // ================== ✅ A2DP "mixer style" noise/feedback controls ==================
  private val A2DP_HPF_HZ = 220.0

  private val A2DP_AFS_ANALYZE_MS = 100L
  private val A2DP_DUCK_MS = 450L
  private val A2DP_EARLY_MUTE_RMS = 0.30
  private val A2DP_EARLY_MUTE_RISE = 0.08

  private val A2DP_LPF_HZ = 8500.0
  private val A2DP_GATE_THR = 0.030
  private val A2DP_GATE_ATTACK_MS = 6.0
  private val A2DP_GATE_RELEASE_MS = 140.0
  // ====================================================================

  // ================== ✅ FIX: robust BT headset (HFP/HSP) detection via profile proxy ==================
  private var btHeadset: BluetoothHeadset? = null
  private var btHeadsetProxyReady: Boolean = false

  @Volatile private var lastBtHeadsetWithMic: Boolean? = null
  private fun logBtHeadsetWithMicOnce(state: Boolean, reason: String) {
    val prev = lastBtHeadsetWithMic
    if (prev == null || prev != state) {
      lastBtHeadsetWithMic = state
      Log.d(TAG, "BT headset-with-mic = $state ($reason)")
    }
  }

  private fun initBluetoothHeadsetProxy() {
    try {
      val adapter = BluetoothAdapter.getDefaultAdapter() ?: return
      adapter.getProfileProxy(
        this,
        object : BluetoothProfile.ServiceListener {
          override fun onServiceConnected(profile: Int, proxy: BluetoothProfile?) {
            if (profile == BluetoothProfile.HEADSET) {
              btHeadset = proxy as? BluetoothHeadset
              btHeadsetProxyReady = true
              Log.d(TAG, "BT HEADSET proxy connected")
            }
          }

          override fun onServiceDisconnected(profile: Int) {
            if (profile == BluetoothProfile.HEADSET) {
              btHeadset = null
              btHeadsetProxyReady = false
              Log.d(TAG, "BT HEADSET proxy disconnected")
            }
          }
        },
        BluetoothProfile.HEADSET
      )
    } catch (e: Exception) {
      Log.w(TAG, "initBluetoothHeadsetProxy fail: ${e.message}")
    }
  }
  // =====================================================================================================

  // ================== ✅ AirPods/TWS mic+out route helpers (SCO/BLE_HEADSET) ==================
  private fun findBtMicInput(): AudioDeviceInfo? {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return null
    val ins = audioManager.getDevices(AudioManager.GET_DEVICES_INPUTS)
    return ins.firstOrNull { it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO }
      ?: ins.firstOrNull { it.type == AudioDeviceInfo.TYPE_BLE_HEADSET }
  }

  private fun findBtCommOutput(): AudioDeviceInfo? {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return null
    val outs = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
    return outs.firstOrNull { it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO }
      ?: outs.firstOrNull { it.type == AudioDeviceInfo.TYPE_BLE_HEADSET }
  }

  // Android 12+ (API 31): setCommunicationDevice giúp “khóa route” sang BT comm device (đỡ ROM phá)
  // Không được phá wired.
  private fun forceCommDeviceIfPossible(voicePath: Boolean) {
    if (Build.VERSION.SDK_INT < 31) return
    if (findWiredOutput() != null || findWiredInput() != null) return

    // ❌ KHÔNG làm gì khi media path (A2DP) để tránh ROM giết AudioTrack.
    if (!voicePath) return

    try {
      val dev = findBtCommOutput()
      if (dev != null) {
        val ok = audioManager.setCommunicationDevice(dev)
        Log.d(TAG, "setCommunicationDevice(type=${dev.type}) -> $ok")
      } else {
        Log.w(TAG, "setCommunicationDevice: no BT comm output")
      }
    } catch (e: Exception) {
      Log.w(TAG, "forceCommDeviceIfPossible fail: ${e.message}")
    }
  }
  // =====================================================================================================

  // ===================== ✅ One-pole LPF + SimpleGate (A2DP only) =====================
  internal class OnePoleLpf(fs: Double, fc: Double) {
    private var a = 0.0
    private var y1 = 0.0
    init { set(fs, fc) }

    fun set(fs: Double, fc: Double) {
      val c = tan(Math.PI * fc / fs)
      a = c / (1.0 + c)
      y1 = 0.0
    }

    fun process(x: Double): Double {
      val y = y1 + a * (x - y1)
      y1 = y
      return y
    }
  }

  internal class SimpleGate(
    sampleRate: Double,
    threshold: Double,
    attackMs: Double,
    releaseMs: Double
  ) {
    private val thr = threshold.coerceIn(1e-6, 0.5)
    private val atk = exp(-1.0 / (sampleRate * (attackMs / 1000.0)).coerceAtLeast(1e-6))
    private val rel = exp(-1.0 / (sampleRate * (releaseMs / 1000.0)).coerceAtLeast(1e-6))
    private var env = 0.0
    private var g = 0.0

    fun process(x: Double): Double {
      val a = abs(x)
      env = if (a > env) atk * env + (1.0 - atk) * a else rel * env + (1.0 - rel) * a
      val target = if (env >= thr) 1.0 else 0.0
      g += (target - g) * 0.02
      return x * g
    }
  }
  // =====================================================================================================

  // ===================== ✅ ADDED: SimpleLimiter (push gain without harsh clipping) =====================
  internal class SimpleLimiter(
    sampleRate: Double,
    threshold: Double = 0.92,
    releaseMs: Double = 120.0
  ) {
    private val thr = threshold.coerceIn(0.2, 0.99)
    private val rel = exp(-1.0 / (sampleRate * (releaseMs / 1000.0)).coerceAtLeast(1e-6))
    private var g = 1.0

    fun reset() { g = 1.0 }

    fun process(x: Double): Double {
      val ax = abs(x)
      val desired = if (ax <= thr || ax <= 1e-9) 1.0 else (thr / ax)
      if (desired < g) {
        g = desired
      } else {
        g = rel * g + (1.0 - rel) * desired
      }
      return x * g
    }
  }
  // =====================================================================================================

  override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

    initBluetoothHeadsetProxy()

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

              // ✅ OPTIONAL new param (default 1.0)
              val mBoost = (call.argument<Number>("masterBoost") ?: 1.0).toDouble()

              eqEnabled = enabled

              // ✅ IMPORTANT: allow bigger (real) gain; limiter will protect
              outputGain = outGain.coerceIn(0.0, 6.0)

              // ✅ master loudness knob
              masterBoost = mBoost.coerceIn(0.5, 4.0)

              val arr = DoubleArray(5)
              for (i in 0 until 5) {
                val v = if (i < list.size) list[i].toDouble() else 1.0
                arr[i] = v.coerceIn(0.25, 3.0)
              }
              bandGains = arr

              Log.d(TAG, "setParams eq=$eqEnabled outputGain=$outputGain masterBoost=$masterBoost bands=${bandGains.joinToString()}")
              result.success(null)
            }

            "setPreferWiredMic" -> {
              val v = call.argument<Boolean>("preferWiredMic") ?: false
              val boost = (call.argument<Number>("headsetBoost") ?: 2.2).toDouble()

              preferWiredMic = v
              headsetMicBoost = boost.coerceIn(1.0, 6.0)

              Log.d(TAG, "setPreferWiredMic=$preferWiredMic headsetBoost=$headsetMicBoost running=$running")

              if (running) handleRouteChanged()
              result.success(null)
            }

            "isWiredPresent" -> {
              val wired = (findWiredOutput() != null || findWiredInput() != null)
              result.success(wired)
            }

            "isBtHeadsetPresent" -> {
              val ok = isBtHeadsetWithMicConnected()
              result.success(ok)
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

    registerDeviceCallback()
  }

  // ===== Bluetooth detection =====
  private fun findBtA2dpOutput(): AudioDeviceInfo? {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return null
    val outs = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
    return outs.firstOrNull { it.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP }
  }

  // ✅ detect “BT headset with mic” via INPUT devices (SCO/BLE_HEADSET)
  private fun isBtHeadsetWithMicConnected(): Boolean {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false

    val ins = audioManager.getDevices(AudioManager.GET_DEVICES_INPUTS)
    val outs = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)

    val hasScoIn = ins.any {
      it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
        it.type == AudioDeviceInfo.TYPE_BLE_HEADSET
    }

    val hasScoOut = outs.any {
      it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
        it.type == AudioDeviceInfo.TYPE_BLE_HEADSET
    }

    val hasA2dpOut = outs.any { it.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP }
    val hasA2dpOnly = hasA2dpOut && !hasScoIn && !hasScoOut
    if (hasA2dpOnly) {
      logBtHeadsetWithMicOnce(false, "A2DP-only output (speaker/music), no headset input")
      return false
    }

    if (hasScoIn) {
      logBtHeadsetWithMicOnce(true, "Found headset input (SCO/BLE_HEADSET)")
      return true
    }

    logBtHeadsetWithMicOnce(false, "No headset input device")
    return false
  }

  // ===== Start/Stop =====
  private fun startLoopback(voiceMode: Boolean) {
    stopLoopback()
    pendingStartToken++

    lastVoiceModeRequested = voiceMode

    try { audioManager.isSpeakerphoneOn = false } catch (_: Exception) {}

    if (voiceMode && !isBtHeadsetWithMicConnected()) {
      Log.w(TAG, "voiceMode requested but no BT headset mic -> fallback to auto-route")
      startLoopback(false)
      return
    }

    if (!voiceMode) {
      safeStopSco()

      val a2dp = findBtA2dpOutput()
      val wiredOut = findWiredOutput()
      val wiredIn = findWiredInput()
      val wiredPresent = (wiredOut != null || wiredIn != null)

      if (a2dp != null) {
        safeSetModeNormal()
        try { audioManager.isSpeakerphoneOn = false } catch (_: Exception) {}
        startEngine(sampleRate = 48000, voicePath = false, token = pendingStartToken)
        return
      }

      if (isBtHeadsetWithMicConnected()) {
        safeSetModeInCommunication()
        try { audioManager.isSpeakerphoneOn = false } catch (_: Exception) {}

        val token = pendingStartToken
        val filter = IntentFilter(AudioManager.ACTION_SCO_AUDIO_STATE_UPDATED)
        var scoTimeout: Runnable? = null

        scoReceiver = object : BroadcastReceiver() {
          override fun onReceive(context: Context?, intent: Intent?) {
            val state = intent?.getIntExtra(AudioManager.EXTRA_SCO_AUDIO_STATE, -1) ?: -1
            if (token != pendingStartToken) {
              try { unregisterReceiver(this) } catch (_: Exception) {}
              scoReceiver = null
              scoTimeout?.let { mainHandler.removeCallbacks(it) }
              return
            }

            if (state == AudioManager.SCO_AUDIO_STATE_CONNECTED) {
              try { audioManager.isBluetoothScoOn = true } catch (_: Exception) {}

              mainHandler.postDelayed({
                if (token == pendingStartToken) {
                  startEngine(sampleRate = 16000, voicePath = true, token = token)
                }
              }, 120)

              try { unregisterReceiver(this) } catch (_: Exception) {}
              scoReceiver = null
              scoTimeout?.let { mainHandler.removeCallbacks(it) }
            }
          }
        }

        try {
          registerReceiver(scoReceiver, filter)
          audioManager.startBluetoothSco()
          scoTimeout = Runnable {
            if (token == pendingStartToken) {
              try { scoReceiver?.let { unregisterReceiver(it) } } catch (_: Exception) {}
              scoReceiver = null
              safeStopSco()
              safeSetModeNormal()
              startEngine(sampleRate = 48000, voicePath = false, token = token)
            }
          }
          mainHandler.postDelayed(scoTimeout, 2000)
        } catch (_: Exception) {
          try { scoReceiver?.let { unregisterReceiver(it) } } catch (_: Exception) {}
          scoReceiver = null
          safeStopSco()
          safeSetModeNormal()
          startEngine(sampleRate = 48000, voicePath = false, token = token)
        }
        return
      }

      if (!wiredPresent) {
        // ✅ speaker default dùng MODE_NORMAL (để volume không bị bóp như call)
        safeSetModeNormal()
        try { audioManager.isSpeakerphoneOn = true } catch (_: Exception) {}
        startEngine(sampleRate = SPEAKER_VOICE_SR, voicePath = true, token = pendingStartToken)
        return
      }

      safeSetModeNormal()
      try { audioManager.isSpeakerphoneOn = false } catch (_: Exception) {}
      startEngine(sampleRate = 48000, voicePath = false, token = pendingStartToken)
      return
    }

    // Manual SCO mode
    safeSetModeInCommunication()
    val token = pendingStartToken

    val filter = IntentFilter(AudioManager.ACTION_SCO_AUDIO_STATE_UPDATED)
    var scoTimeout: Runnable? = null
    scoReceiver = object : BroadcastReceiver() {
      override fun onReceive(context: Context?, intent: Intent?) {
        val state = intent?.getIntExtra(AudioManager.EXTRA_SCO_AUDIO_STATE, -1) ?: -1
        if (token != pendingStartToken) {
          try { unregisterReceiver(this) } catch (_: Exception) {}
          scoReceiver = null
          scoTimeout?.let { mainHandler.removeCallbacks(it) }
          return
        }

        if (state == AudioManager.SCO_AUDIO_STATE_CONNECTED) {
          try { audioManager.isBluetoothScoOn = true } catch (_: Exception) {}

          mainHandler.postDelayed({
            if (token == pendingStartToken) {
              startEngine(sampleRate = 16000, voicePath = true, token = token)
            }
          }, 120)

          try { unregisterReceiver(this) } catch (_: Exception) {}
          scoReceiver = null
          scoTimeout?.let { mainHandler.removeCallbacks(it) }
        }
      }
    }

    try {
      registerReceiver(scoReceiver, filter)
      audioManager.startBluetoothSco()
      scoTimeout = Runnable {
        if (token == pendingStartToken) {
          try { scoReceiver?.let { unregisterReceiver(it) } } catch (_: Exception) {}
          scoReceiver = null
          safeStopSco()
          safeSetModeNormal()
          startEngine(sampleRate = 48000, voicePath = false, token = token)
        }
      }
      mainHandler.postDelayed(scoTimeout, 2000)
    } catch (_: Exception) {
      try { scoReceiver?.let { unregisterReceiver(it) } } catch (_: Exception) {}
      scoReceiver = null
      safeStopSco()
      safeSetModeNormal()
      startEngine(sampleRate = 48000, voicePath = false, token = token)
    }
  }

  private fun startEngine(sampleRate: Int, voicePath: Boolean, token: Int) {
    if (token != pendingStartToken) return

    lastVoicePath = voicePath
    lastSampleRate = sampleRate

    val channelIn = AudioFormat.CHANNEL_IN_MONO
    val channelOut = AudioFormat.CHANNEL_OUT_MONO
    val encoding = AudioFormat.ENCODING_PCM_16BIT

    val effectiveSampleRate = if (voicePath) sampleRate else try {
      val prop = audioManager.getProperty(AudioManager.PROPERTY_OUTPUT_SAMPLE_RATE)
      prop?.toIntOrNull() ?: sampleRate
    } catch (_: Exception) { sampleRate }

    val recMin = AudioRecord.getMinBufferSize(effectiveSampleRate, channelIn, encoding)
    val playMin = AudioTrack.getMinBufferSize(effectiveSampleRate, channelOut, encoding)

    val wiredOut = findWiredOutput()
    val wiredIn = findWiredInput()
    val usingWiredMic = (wiredIn != null && preferWiredMic)

    val wiredPresent = (!voicePath) && (wiredOut != null || wiredIn != null)
    val isWiredOutNow = (!voicePath) && (wiredOut != null)

    val recTarget = if (voicePath) (effectiveSampleRate / 50) else (effectiveSampleRate / 20)
    val playTarget = when {
      voicePath -> (effectiveSampleRate / 50)
      isWiredOutNow -> (effectiveSampleRate / 10)
      else -> (effectiveSampleRate / 20)
    }

    val recBufSize = maxOf(recMin, recTarget * 6)
    val playBufSize = maxOf(playMin, playTarget * 6)

    Log.d(
      TAG,
      "startEngine requestedSampleRate=$sampleRate effectiveSampleRate=$effectiveSampleRate voicePath=$voicePath recMin=$recMin playMin=$playMin recBuf=$recBufSize playBuf=$playBufSize wiredOut=${wiredOut?.type ?: "null"}"
    )

    val isA2dpOutNow = (!voicePath) && (findBtA2dpOutput() != null) && (findWiredOutput() == null)
    if (isA2dpOutNow) Log.w(TAG, "A2DP output active -> enable anti-feedback guard + cap gain")

    val isBuiltInMicNow = (!usingWiredMic) && (findBuiltInMic() != null)
    val forceVoiceCommForA2dp = isA2dpOutNow && isBuiltInMicNow
    if (forceVoiceCommForA2dp) Log.w(TAG, "A2DP + built-in mic -> force VOICE_COMMUNICATION source + enable AEC/NS/AGC (best-effort)")

    val isSpeakerDefaultNow = voicePath &&
      (findWiredOutput() == null) &&
      (findBtA2dpOutput() == null) &&
      (!isA2dpOutNow)

    val audioSource =
      if (forceVoiceCommForA2dp) {
        MediaRecorder.AudioSource.VOICE_COMMUNICATION
      } else if (voicePath) {
        if (isSpeakerDefaultNow) {
          MediaRecorder.AudioSource.MIC
        } else {
          MediaRecorder.AudioSource.VOICE_COMMUNICATION
        }
      } else {
        if (usingWiredMic) MediaRecorder.AudioSource.VOICE_COMMUNICATION else MediaRecorder.AudioSource.MIC
      }

    recorder = AudioRecord.Builder()
      .setAudioSource(audioSource)
      .setAudioFormat(
        AudioFormat.Builder()
          .setEncoding(encoding)
          .setSampleRate(effectiveSampleRate)
          .setChannelMask(channelIn)
          .build()
      )
      .setBufferSizeInBytes(recBufSize)
      .apply {
        if (Build.VERSION.SDK_INT >= 29) {
          try {
            val perfField = AudioRecord::class.java.getField("PERFORMANCE_MODE_LOW_LATENCY")
            val perfMode = perfField.getInt(null)
            val m = this::class.java.getMethod("setPerformanceMode", Int::class.javaPrimitiveType)
            m.invoke(this, perfMode)
          } catch (_: Exception) {}
        }
      }
      .build()

    // ✅ ép mic BT khi voicePath=true
    if (voicePath) {
      try {
        val btIn = findBtMicInput()
        if (btIn != null) {
          recorder?.preferredDevice = btIn
          Log.d(TAG, "rec.preferredDevice -> BT mic type=${btIn.type}")
        } else {
          Log.w(TAG, "voicePath=true but no BT mic input found")
        }
      } catch (_: Exception) {}
    }

    // ✅ FIX “ăn chữ” speaker: chỉ bật AEC; tắt NS/AGC
    val enableAec = (voicePath || forceVoiceCommForA2dp || usingWiredMic)
    val enableNsAgc = (forceVoiceCommForA2dp || usingWiredMic || (voicePath && !isSpeakerDefaultNow))

    if (enableAec) {
      try { aec = AcousticEchoCanceler.create(recorder?.audioSessionId ?: 0); aec?.enabled = true }
      catch (e: Exception) { aec = null; Log.w(TAG, "AEC init fail: ${e.message}") }
    } else {
      try { aec?.release() } catch (_: Exception) {}
      aec = null
    }

    if (enableNsAgc) {
  try {
    ns = NoiseSuppressor.create(recorder?.audioSessionId ?: 0)
    ns?.enabled = true
  } catch (e: Exception) {
    ns = null
    Log.w(TAG, "NS init fail: ${e.message}")
  }

  try {
    agc = AutomaticGainControl.create(recorder?.audioSessionId ?: 0)
    agc?.enabled = true
  } catch (e: Exception) {
    agc = null
    Log.w(TAG, "AGC init fail: ${e.message}")
  }
} else {
  try { ns?.release() } catch (_: Exception) {}
  ns = null
  try { agc?.release() } catch (_: Exception) {}
  agc = null
}


    // ✅ PATCH: Speaker default dùng USAGE_MEDIA để volume không bị bóp như call stream
    val outUsage =
      if (isSpeakerDefaultNow) AudioAttributes.USAGE_MEDIA
      else if (voicePath) AudioAttributes.USAGE_VOICE_COMMUNICATION
      else AudioAttributes.USAGE_MEDIA

    // ✅ PATCH: Speaker default vẫn là “speech” cho phù hợp (nhưng chạy trên media stream)
    val outContent =
      if (isSpeakerDefaultNow) AudioAttributes.CONTENT_TYPE_SPEECH
      else if (voicePath) AudioAttributes.CONTENT_TYPE_SPEECH
      else AudioAttributes.CONTENT_TYPE_MUSIC

    val attrs = AudioAttributes.Builder()
      .setUsage(outUsage)
      .setContentType(outContent)
      .build()

    val format = AudioFormat.Builder()
      .setEncoding(encoding)
      .setSampleRate(effectiveSampleRate)
      .setChannelMask(channelOut)
      .build()

    player = AudioTrack.Builder()
      .setAudioAttributes(attrs)
      .setAudioFormat(format)
      .setTransferMode(AudioTrack.MODE_STREAM)
      .setBufferSizeInBytes(playBufSize)
      .apply {
        if (Build.VERSION.SDK_INT >= 29) {
          try {
            val perfField = AudioTrack::class.java.getField("PERFORMANCE_MODE_LOW_LATENCY")
            val perfMode = perfField.getInt(null)
            val m = this::class.java.getMethod("setPerformanceMode", Int::class.javaPrimitiveType)
            m.invoke(this, perfMode)
          } catch (_: Exception) {}
        }
      }
      .build()

    // ✅ Android 12+ lock route sang BT communication device (không phá wired)
    forceCommDeviceIfPossible(voicePath)

    // ✅✅ route ưu tiên theo voicePath (tránh set A2DP preferredDevice)
    routeToBestDevices(recorder, player, wiredPresent, voicePath)

    // debug routed
    try {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        Log.d(TAG, "AudioRecord routedDevice type=${recorder?.routedDevice?.type}")
        Log.d(TAG, "AudioTrack routedDevice type=${player?.routedDevice?.type}")
      }
    } catch (_: Exception) {}

    // ✅ PATCH: setVolume chỉ là “tối đa hóa stream”, loudness thật vẫn là digital gain
    // Speaker default: nhẹ tay; Wired: có thể cao hơn
    val speakerBoost = if (isSpeakerDefaultNow) 1.8f else 1.0f
    if (isWiredOutNow) {
      try { player?.setVolume(2.0f) } catch (_: Exception) {}
    } else {
      try { player?.setVolume(speakerBoost) } catch (_: Exception) {}
    }

    val eq = Eq5Band(effectiveSampleRate.toDouble())

    if (isSpeakerDefaultNow) {
      Log.w(TAG, "Speaker default voicePath=true @${effectiveSampleRate}Hz -> VOICE_RECOGNITION + AEC only (NS/AGC off) to reduce dropped consonants")
    }

    val hpf = OnePoleHpf(effectiveSampleRate.toDouble(), A2DP_HPF_HZ)
    val a2dpLpf = OnePoleLpf(effectiveSampleRate.toDouble(), A2DP_LPF_HZ)
    val gate = SimpleGate(
      sampleRate = effectiveSampleRate.toDouble(),
      threshold = A2DP_GATE_THR,
      attackMs = A2DP_GATE_ATTACK_MS,
      releaseMs = A2DP_GATE_RELEASE_MS
    )

    // NOTE: AntiFeedbackAfs là class của bạn (file AntiFeedbackAfs.kt). Không định nghĩa lại ở đây.
    val afs = AntiFeedbackAfs(effectiveSampleRate.toDouble())

    val comp = SimpleCompressor(
      sampleRate = effectiveSampleRate.toDouble(),
      threshold = 0.28,
      ratio = 2.5,
      attackMs = 8.0,
      releaseMs = 180.0
    )

    // ✅ ADDED: limiter để bạn “đẩy gain” mà không vỡ tiếng quá nhanh
    val limiter = SimpleLimiter(
      sampleRate = effectiveSampleRate.toDouble(),
      threshold = 0.92,
      releaseMs = 120.0
    )

    running = true
    thread = Thread {
      Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)

      val rec = recorder ?: return@Thread
      val out = player ?: return@Thread

      val chunkSize = min(recBufSize, playBufSize) / 3
      val buf = ShortArray(chunkSize)

      var lastEqEnabled = eqEnabled
      var lastGain = outputGain
      var lastMaster = masterBoost
      var lastBands = bandGains.copyOf()

      var a2dpFlag = isA2dpOutNow
      var lastA2dpCheckTs = 0L

      var duckUntilTs = 0L
      var lastAnalyzeTs = 0L

      fun refreshEqIfChanged() {
        val en = eqEnabled
        val g = outputGain
        val m = masterBoost
        val b = bandGains

        var changed = false
        if (en != lastEqEnabled || g != lastGain || m != lastMaster) changed = true
        else for (i in 0 until 5) if (b[i] != lastBands[i]) { changed = true; break }

        if (changed) {
          lastEqEnabled = en
          lastGain = g
          lastMaster = m

          val bb = b.copyOf()

          // speaker default: hạn chế high quá gắt
          if (isSpeakerDefaultNow) {
            bb[3] = min(bb[3], 1.25)
            bb[4] = min(bb[4], 1.35)
          }

          // a2dp: hạn chế treble để giảm hú/chói
          if (a2dpFlag) {
            bb[2] = min(bb[2], 1.05)
            bb[3] = min(bb[3], 1.10)
            bb[4] = min(bb[4], 1.10)
          }

          lastBands = bb.copyOf()
          val db = DoubleArray(5) { i ->
            val gi = lastBands[i].coerceAtLeast(0.0001)
            20.0 * ln(gi) / ln(10.0)
          }
          eq.updateGainsDb(db)

          Log.d(TAG, "EQ refresh en=$en outputGain=$g masterBoost=$m a2dp=$a2dpFlag bands=${lastBands.joinToString()}")
        }
      }

      var lastMeterTs = 0L
      var lastUnderrunTs = 0L

      var guardGain = 1.0
      var lastRms = 0.0
      var lastGuardLogTs = 0L

      rec.startRecording()

      val preBufChunks = 2
      val silenceBuf = ShortArray(chunkSize) { 0 }
      for (i in 0 until preBufChunks) {
        try {
          out.write(silenceBuf, 0, silenceBuf.size, AudioTrack.WRITE_BLOCKING)
        } catch (_: Exception) { break }
      }
      Log.d(TAG, "Pre-buffered $preBufChunks chunks of silence to prevent initial underrun")

      out.play()

      while (running) {
        val n = rec.read(buf, 0, buf.size, AudioRecord.READ_BLOCKING)
        if (n <= 0) continue

        // raw RMS floor cho AFS
        var rawSumSq = 0.0
        for (i in 0 until n) {
          val xf = buf[i].toDouble() / 32768.0
          rawSumSq += xf * xf
        }
        val rawRms = sqrt(rawSumSq / n.toDouble()).coerceIn(0.0, 1.0)

        val nowCheck = System.currentTimeMillis()
        if (nowCheck - lastA2dpCheckTs > 500) {
          lastA2dpCheckTs = nowCheck
          val newFlag = (!voicePath) && (findBtA2dpOutput() != null) && (findWiredOutput() == null)
          if (newFlag != a2dpFlag) {
            a2dpFlag = newFlag
            guardGain = 1.0
            limiter.reset()
            afs.reset()
            duckUntilTs = 0L
            Log.w(TAG, "A2DP flag changed -> $a2dpFlag (reset guard/limiter/afs/duck)")
          }
        }

        refreshEqIfChanged()

        val en = lastEqEnabled
        val gRaw = lastGain
        val mBoost = lastMaster

        // speaker default auto boost (để bù vì NS/AGC tắt + voice path)
        val speakerDefaultBoost = if (isSpeakerDefaultNow && !a2dpFlag) 1.35 else 1.0

        val micBoost = if (usingWiredMic) headsetMicBoost else 1.0
        val gCap = if (a2dpFlag) min(gRaw, A2DP_SAFE_GAIN_CAP) else gRaw

        // ✅ loudness thực tế: outputGain * masterBoost * speakerBoost * guard * micBoost
        val combinedGain = (gCap * mBoost * speakerDefaultBoost) * guardGain * micBoost

        var sumSq = 0.0

        val now = System.currentTimeMillis()
        val doAnalyze = a2dpFlag && (rawRms > 0.018) && (now - lastAnalyzeTs >= A2DP_AFS_ANALYZE_MS)
        if (doAnalyze) {
          lastAnalyzeTs = now
          afs.analyze(buf, n)
        }

        val duckNow = a2dpFlag && (now < duckUntilTs)

        if (en) {
          for (i in 0 until n) {
            var x = buf[i].toDouble() / 32768.0

            x = eq.process(x)
            if (!x.isFinite()) x = 0.0

            if (a2dpFlag) {
              x = hpf.process(x)
              x = a2dpLpf.process(x)
              x = gate.process(x)
              x = afs.process(x)
            }

            if (duckNow) x *= 0.78

            x *= combinedGain
            if (a2dpFlag) x = comp.process(x)

            // ✅ limiter trước softClip để loud mà ít méo hơn
            x = limiter.process(x)
            x = softClip(x)

            val y = (x * 32767.0).roundToInt().coerceIn(-32768, 32767).toShort()
            buf[i] = y
            val yf = y.toDouble() / 32768.0
            sumSq += yf * yf
          }
        } else {
          for (i in 0 until n) {
            var x = buf[i].toDouble() / 32768.0

            if (a2dpFlag) {
              x = hpf.process(x)
              x = a2dpLpf.process(x)
              x = gate.process(x)
              x = afs.process(x)
            }

            if (duckNow) x *= 0.78

            x *= combinedGain
            if (a2dpFlag) x = comp.process(x)

            x = limiter.process(x)
            x = softClip(x)

            val y = (x * 32767.0).roundToInt().coerceIn(-32768, 32767).toShort()
            buf[i] = y
            val yf = y.toDouble() / 32768.0
            sumSq += yf * yf
          }
        }

        val rmsNow = sqrt(sumSq / n.toDouble()).coerceIn(0.0, 1.0)

        if (a2dpFlag) {
          val risingFast = (rmsNow - lastRms) > FEEDBACK_RISE_THRESHOLD
          val tooLoud = rmsNow > FEEDBACK_RMS_THRESHOLD

          if (tooLoud || risingFast) duckUntilTs = now + A2DP_DUCK_MS

          if (tooLoud || risingFast) {
            guardGain *= 0.70
            if (guardGain < GUARD_MIN) guardGain = GUARD_MIN
          } else {
            guardGain += (1.0 - guardGain) * 0.001
          }

          val earlyMute = (rmsNow > A2DP_EARLY_MUTE_RMS) || ((rmsNow - lastRms) > A2DP_EARLY_MUTE_RISE)
          val hardMute = rmsNow > A2DP_HARD_MUTE_RMS

          if (earlyMute || hardMute) {
            val muteMs = if (hardMute) A2DP_MUTE_MS else (A2DP_MUTE_MS / 2)
            val muteSamples = min(n, (effectiveSampleRate * (muteMs / 1000.0)).toInt().coerceAtLeast(1))
            for (i in 0 until muteSamples) buf[i] = 0
          }

          val nowLog = System.currentTimeMillis()
          if (nowLog - lastGuardLogTs > 1000) {
            lastGuardLogTs = nowLog
            Log.w(
              TAG,
              "A2DP guard rms=${"%.3f".format(rmsNow)} guardGain=${"%.3f".format(guardGain)} gCap=${"%.2f".format(gCap)} master=${"%.2f".format(mBoost)} notchCount=${afs.activeCount()} duck=${duckNow}"
            )
          }
        }

        lastRms = rmsNow

        var offset = 0
        var remaining = n
        while (remaining > 0 && running) {
          val wrote =
            if (Build.VERSION.SDK_INT >= 21) out.write(buf, offset, remaining, AudioTrack.WRITE_BLOCKING)
            else out.write(buf, offset, remaining)

          if (wrote < 0) {
            Log.w(TAG, "AudioTrack write error $wrote")
            break
          } else if (wrote > 0) {
            offset += wrote
            remaining -= wrote
          } else {
            try { Thread.sleep(1) } catch (_: Exception) {}
          }
        }

        if (remaining > 0 && running) Log.w(TAG, "⚠️ AudioTrack write incomplete: $remaining samples remaining")

        val now2 = System.currentTimeMillis()
        if (Build.VERSION.SDK_INT >= 24 && now2 - lastUnderrunTs > 1000) {
          lastUnderrunTs = now2
          try { Log.d(TAG, "underrunCount=${out.underrunCount} voicePath=$voicePath wiredOutNow=$isWiredOutNow") } catch (_: Exception) {}
        }

        val nowMeter = System.currentTimeMillis()
        if (nowMeter - lastMeterTs > 50) {
          lastMeterTs = nowMeter
          mainHandler.post { eventSink?.success(rmsNow) }
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

    try { aec?.release() } catch (_: Exception) {}
    aec = null
    try { agc?.release() } catch (_: Exception) {}
    agc = null
    try { ns?.release() } catch (_: Exception) {}
    ns = null

    try { recorder?.release() } catch (_: Exception) {}
    recorder = null

    try { player?.pause() } catch (_: Exception) {}
    try { player?.flush() } catch (_: Exception) {}
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
      ?: outs.firstOrNull { it.type == AudioDeviceInfo.TYPE_WIRED_HEADPHONES || it.type == AudioDeviceInfo.TYPE_WIRED_HEADSET }
  }

  private fun findWiredInput(): AudioDeviceInfo? {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return null
    val ins = audioManager.getDevices(AudioManager.GET_DEVICES_INPUTS)
    return ins.firstOrNull { it.type == AudioDeviceInfo.TYPE_USB_HEADSET }
      ?: ins.firstOrNull { it.type == AudioDeviceInfo.TYPE_WIRED_HEADSET }
  }

  private fun findBuiltInMic(): AudioDeviceInfo? {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return null
    val ins = audioManager.getDevices(AudioManager.GET_DEVICES_INPUTS)
    return ins.firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_MIC }
  }

  // ✅✅ FIX CHÍNH: route ưu tiên theo voicePath
  private fun routeToBestDevices(
    rec: AudioRecord?,
    out: AudioTrack?,
    wiredPresent: Boolean,
    voicePath: Boolean
  ) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return

    val wiredOut = findWiredOutput()
    val wiredIn = findWiredInput()
    val builtInMic = findBuiltInMic()

    // -------- OUTPUT --------
    try {
      if (out != null) {
        if (voicePath) {
          val btCommOut = findBtCommOutput()
          if (btCommOut != null) {
            out.preferredDevice = btCommOut
            Log.d(TAG, "routeBest: out.preferredDevice -> BT COMM type=${btCommOut.type}")
          } else {
            if (wiredOut != null && wiredPresent) {
              out.preferredDevice = wiredOut
              Log.w(TAG, "routeBest: voicePath no BT comm -> fallback wiredOut type=${wiredOut.type}")
            } else {
              Log.w(TAG, "routeBest: voicePath no BT comm & no wired -> keep system route")
            }
          }
        } else {
          // ✅✅ FIX QUAN TRỌNG: media path KHÔNG ép preferredDevice sang A2DP
          if (wiredOut != null && wiredPresent) {
            out.preferredDevice = wiredOut
            Log.d(TAG, "routeBest: out.preferredDevice -> wiredOut type=${wiredOut.type}")
          } else {
            Log.d(TAG, "routeBest: media path -> let system route (avoid A2DP preferredDevice)")
          }
        }
      }
    } catch (_: Exception) {}

    // -------- INPUT --------
    try {
      if (rec != null) {
        if (voicePath) {
          val btIn = findBtMicInput()
          if (btIn != null) {
            rec.preferredDevice = btIn
            Log.d(TAG, "routeBest: rec.preferredDevice -> BT mic type=${btIn.type}")
          } else {
            val targetIn = if (preferWiredMic) (wiredIn ?: builtInMic) else (builtInMic ?: wiredIn)
            if (targetIn != null) rec.preferredDevice = targetIn
          }
        } else {
          val targetIn = if (preferWiredMic) (wiredIn ?: builtInMic) else (builtInMic ?: wiredIn)
          if (targetIn != null) rec.preferredDevice = targetIn
        }
      }
    } catch (_: Exception) {}
  }

  // ===================== ADDED BLOCK START =====================
  private fun registerDeviceCallback() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
    if (deviceCallback != null) return

    deviceCallback = object : AudioDeviceCallback() {
      override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>) { handleRouteChanged() }
      override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>) { handleRouteChanged() }
    }

    try { audioManager.registerAudioDeviceCallback(deviceCallback, mainHandler) } catch (_: Exception) {}
  }

  private fun handleRouteChanged() {
    if (!running) return
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return

    val wiredOut = findWiredOutput()
    val wiredIn = findWiredInput()
    val builtIn = findBuiltInMic()

    if (wiredOut != null) {
      Log.d(TAG, "Wired detected -> auto route to wired (preferWiredMic=$preferWiredMic)")

      safeSetModeNormal()
      try { audioManager.isSpeakerphoneOn = false } catch (_: Exception) {}

      try { player?.preferredDevice = wiredOut } catch (_: Exception) {}
      try {
        val targetIn = if (preferWiredMic) (wiredIn ?: builtIn) else (builtIn ?: wiredIn)
        if (targetIn != null) recorder?.preferredDevice = targetIn
      } catch (_: Exception) {}

      restartEngineAuto(sampleRate = 48000, voicePath = false)
      return
    }

    Log.d(TAG, "Wired not present -> restore auto route")

    if (lastVoiceModeRequested) {
      safeSetModeInCommunication()
      try { audioManager.isSpeakerphoneOn = false } catch (_: Exception) {}

      if (isBtHeadsetWithMicConnected()) {
        restartEngineAuto(sampleRate = 16000, voicePath = true)
      } else {
        safeSetModeNormal()
        try { audioManager.isSpeakerphoneOn = true } catch (_: Exception) {}
        restartEngineAuto(sampleRate = SPEAKER_VOICE_SR, voicePath = true)
      }
      return
    }

    val a2dp = findBtA2dpOutput()
    if (a2dp != null) {
      safeSetModeNormal()
      try { audioManager.isSpeakerphoneOn = false } catch (_: Exception) {}
      restartEngineAuto(sampleRate = 48000, voicePath = false)
    } else {
      safeSetModeNormal()
      try { audioManager.isSpeakerphoneOn = true } catch (_: Exception) {}
      restartEngineAuto(sampleRate = SPEAKER_VOICE_SR, voicePath = true)
    }
  }

  private fun restartEngineAuto(sampleRate: Int, voicePath: Boolean) {
    if (voicePath == lastVoicePath && sampleRate == lastSampleRate) return

    val token = ++pendingStartToken
    running = false

    try { recorder?.stop() } catch (_: Exception) {}
    try { player?.pause() } catch (_: Exception) {}
    try { player?.flush() } catch (_: Exception) {}

    try { thread?.interrupt() } catch (_: Exception) {}
    try { thread?.join(300) } catch (_: Exception) {}
    thread = null

    try { aec?.release() } catch (_: Exception) {}
    aec = null
    try { agc?.release() } catch (_: Exception) {}
    agc = null
    try { ns?.release() } catch (_: Exception) {}
    ns = null

    try { recorder?.release() } catch (_: Exception) {}
    recorder = null
    try { player?.release() } catch (_: Exception) {}
    player = null

    startEngine(sampleRate = sampleRate, voicePath = voicePath, token = token)
  }

  override fun onDestroy() {
    super.onDestroy()
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      try { deviceCallback?.let { audioManager.unregisterAudioDeviceCallback(it) } } catch (_: Exception) {}
    }
    deviceCallback = null

    try {
      val adapter = BluetoothAdapter.getDefaultAdapter()
      if (adapter != null && btHeadset != null) {
        adapter.closeProfileProxy(BluetoothProfile.HEADSET, btHeadset)
      }
    } catch (_: Exception) {}
    btHeadset = null
    btHeadsetProxyReady = false
  }
  // ===================== ADDED BLOCK END =====================

  // ===================== STUBS (giữ compile) =====================
  private fun softClip(x: Double): Double {
    val a = 1.5
    val ax = a * x
    return ax / (1.0 + abs(ax))
  }

  // NOTE: Eq5Band / OnePoleHpf / AntiFeedbackAfs / SimpleCompressor là class bạn đã dùng.
  // Ở đây không định nghĩa lại để tránh trùng.
}

