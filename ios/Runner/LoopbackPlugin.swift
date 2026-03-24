// LoopbackPlugin.swift
//
// MERGED PIPELINE:
// - speaker-default keeps .default mode
// - AFS notch
// - dynamic harsh suppression only when RMS is high enough
// - soft clip only near peaks
// - noise-floor expander (don't talk = near silence)
// - pre-emptive duck
// - feedback guard
// - rebuilt engine to avoid stale 44.1k graph
// - tap format mismatch fixed
// - async stop teardown to reduce UI stall feeling

import Flutter
import UIKit
import AVFoundation
import QuartzCore

public final class LoopbackPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

  // ===== Channels =====
  private static let CHANNEL = "loopback"
  private static let EVENTS  = "loopback_events"

  // ===== Audio Session / Engine =====
  private let session = AVAudioSession.sharedInstance()
  private var engine = AVAudioEngine()
  private var player = AVAudioPlayerNode()

  // ===== State / Queue =====
  private let audioQueue = DispatchQueue(label: "loopback.audio.queue", qos: .userInteractive)
  private var running: Bool = false
  private var pendingStartToken: Int = 0

  private let audioQueueKey = DispatchSpecificKey<Void>()

  public override init() {
    super.init()
    audioQueue.setSpecific(key: audioQueueKey, value: ())
  }

  private func onAudioQueue() -> Bool {
    return DispatchQueue.getSpecific(key: audioQueueKey) != nil
  }

  private func audioAsync(_ block: @escaping () -> Void) {
    audioQueue.async(execute: block)
  }

  private func audioSyncIfNeeded(_ block: () -> Void) {
    if onAudioQueue() { block() } else { audioQueue.sync(execute: block) }
  }

  // ===== Event sink =====
  private var eventSink: FlutterEventSink?

  // ===== Params from Flutter =====
  private var eqEnabled: Bool = true
  private var outputGain: Double = 1.0 // kept for API compat
  private var bandGains: [Double] = [1, 1, 1, 1, 1]
  private var masterBoost: Double = 1.0
  private var duckOthersEnabled: Bool = true

  // ===== INPUT SELECT (best-effort on iOS) =====
  private var preferWiredMic: Bool = false
  private var headsetMicBoost: Double = 3.0
  private var bluetoothMicBoost: Double = 4.5

  // ===== Last route mode =====
  private var lastVoiceModeRequested: Bool = false
  private var lastVoicePath: Bool = false
  private var lastSampleRate: Double = 48_000

  // ================== A2DP tuning ==================
  private let A2DP_SAFE_GAIN_CAP: Double = 0.70
  private let A2DP_TOTAL_GAIN_CAP: Double = 1.25
  private let FEEDBACK_RMS_THRESHOLD: Double = 0.20
  private let FEEDBACK_RISE_THRESHOLD: Double = 0.045
  private let GUARD_MIN: Double = 0.05
  private let A2DP_MUTE_MS: Double = 40.0
  private let A2DP_HARD_MUTE_RMS: Double = 0.55

  // ================== Speaker route ==================
  private let SPEAKER_VOICE_SR: Double = 48_000
  private let FIXED_GAIN_SPEAKER: Double = 0.28
  private let FIXED_GAIN_WIRED:   Double = 1.35
  private let FIXED_GAIN_HFP:     Double = 1.20
  private let SPK_TOTAL_GAIN_CAP: Double = 0.42

  // ================== A2DP mixer style ==================
  private let A2DP_HPF_HZ: Double = 220.0
  private let A2DP_AFS_ANALYZE_MS: Double = 100.0
  private let A2DP_DUCK_MS: Double = 450.0
  private let A2DP_EARLY_MUTE_RMS: Double = 0.30
  private let A2DP_EARLY_MUTE_RISE: Double = 0.08
  private let A2DP_LPF_HZ: Double = 8500.0
  private let A2DP_GATE_THR: Double = 0.012
  private let A2DP_GATE_ATTACK_MS: Double = 4.0
  private let A2DP_GATE_RELEASE_MS: Double = 260.0

  // ================== Speaker anti-feedback ==================
  private let SPK_HPF_HZ: Double = 150.0
  private let SPK_LPF_HZ: Double = 2500.0
  private let SPK_GATE_THR: Double = 0.030
  private let SPK_GATE_ATTACK_MS: Double = 2.0
  private let SPK_GATE_RELEASE_MS: Double = 120.0

  private let SPK_AFS_ANALYZE_MS: Double = 55.0
  private let SPK_DUCK_MS: Double = 700.0

  private let SPK_FEEDBACK_RMS_THRESHOLD: Double = 0.070
  private let SPK_FEEDBACK_RISE_THRESHOLD: Double = 0.018
  private let SPK_GUARD_MIN: Double = 0.06

  private let SPK_TALK_RMS: Double = 0.030
  private let SPK_MONITOR_MIN: Double = 0.72
  private let SPK_MONITOR_ATTACK: Double = 0.14
  private let SPK_MONITOR_RELEASE: Double = 0.012

  private let SPK_PRE_DUCK_RMS: Double = 0.022
  private let SPK_HARD_DUCK_RMS: Double = 0.120

  // ===== Reduce self-echo feeling on A2DP =====
  private let A2DP_TALK_RMS_EFFECTIVE: Double = 0.030
  private let A2DP_MONITOR_MIN_EFFECTIVE: Double = 0.60
  private let A2DP_MONITOR_ATTACK: Double = 0.12
  private let A2DP_MONITOR_RELEASE: Double = 0.008

  // ===== Noise-floor expander =====
  private let EXPANDER_THRESHOLD: Double = 0.008
  private let EXPANDER_RATIO: Double = 0.25
  private let EXPANDER_ATTACK: Double = 0.18
  private let EXPANDER_RELEASE: Double = 0.025

  // ===== DSP =====
  private var eq: Eq5Band?
  private var hpf: OnePoleHpf?
  private var a2dpLpf: OnePoleLpf?
  private var spkLpf2: OnePoleLpf?
  private var harshDynLpf: OnePoleLpf?
  private var gate: SimpleGate?
  private var expander: DownwardExpander?
  private var afs: AntiFeedbackAfs?
  private var comp: SimpleCompressor?
  private var limiter: SimpleLimiter?

  // ===== Runtime =====
  private var a2dpFlag: Bool = false
  private var lastA2dpCheckTs: Double = 0.0
  private var duckUntilTs: Double = 0.0
  private var lastAnalyzeTs: Double = 0.0

  private var guardGain: Double = 1.0
  private var monitorGain: Double = 1.0
  private var harshMix: Double = 0.0
  private var preDuckGain: Double = 1.0
  private var expanderGain: Double = 1.0

  private var lastRms: Double = 0.0
  private var lastGuardLogTs: Double = 0.0
  private var lastMeterTs: Double = 0.0

  // ===== Cached audio format used for output scheduling =====
  private var monoFormat: AVAudioFormat?

  // ===== Buffer pool =====
  private let poolLock = NSLock()
  private var freePool: [AVAudioPCMBuffer] = []
  private var freePoolFrames: Int = 0
  private var freePoolCount: Int = 36

  // ===== Stable scheduling timeline =====
  private var nextPlaySampleTime: AVAudioFramePosition = 0
  private var hasTimeline: Bool = false

  // ===== Cached route flags =====
  private var routeA2dp: Bool = false
  private var routeWired: Bool = false
  private var routeBtMic: Bool = false

  // ===== Extra guards =====
  private var lastRouteRestartTs: Double = 0.0
  private var didLogTapBufferFormat: Bool = false

  // MARK: Route helpers
  private func updateRouteCache() {
    let r = session.currentRoute

    routeA2dp = r.outputs.contains { $0.portType == .bluetoothA2DP }

    let wiredOut = r.outputs.contains { o in
      o.portType == .headphones || o.portType == .usbAudio
    }
    let wiredIn = r.inputs.contains { i in
      i.portType == .headsetMic || i.portType == .usbAudio
    }
    routeWired = wiredOut || wiredIn

    routeBtMic = r.inputs.contains { $0.portType == .bluetoothHFP }
  }

  private func liveRouteFlags() -> (a2dp: Bool, wired: Bool, btHfp: Bool, outIsSpeaker: Bool) {
    let r = session.currentRoute
    let a2dp = r.outputs.contains { $0.portType == .bluetoothA2DP }
    let wiredOut = r.outputs.contains { $0.portType == .headphones || $0.portType == .usbAudio }
    let wiredIn  = r.inputs.contains  { $0.portType == .headsetMic || $0.portType == .usbAudio }
    let wired = wiredOut || wiredIn
    let btHfp = r.inputs.contains { $0.portType == .bluetoothHFP }
    let outIsSpeaker = r.outputs.contains { $0.portType == .builtInSpeaker }
    return (a2dp, wired, btHfp, outIsSpeaker)
  }

  // MARK: Pool helpers
  private func prepareFreePool(frames: Int, mono: AVAudioFormat) {
    if freePoolFrames == frames, !freePool.isEmpty { return }
    freePoolFrames = frames
    poolLock.lock()
    defer { poolLock.unlock() }
    freePool.removeAll(keepingCapacity: true)
    for _ in 0..<freePoolCount {
      if let b = AVAudioPCMBuffer(pcmFormat: mono, frameCapacity: AVAudioFrameCount(frames)) {
        b.frameLength = AVAudioFrameCount(frames)
        freePool.append(b)
      }
    }
  }

  private func acquireFreeBuf(frames: Int, mono: AVAudioFormat) -> AVAudioPCMBuffer? {
    if freePool.isEmpty || freePoolFrames != frames {
      prepareFreePool(frames: frames, mono: mono)
    }
    poolLock.lock()
    defer { poolLock.unlock() }
    guard !freePool.isEmpty else { return nil }
    let b = freePool.removeLast()
    b.frameLength = AVAudioFrameCount(frames)
    return b
  }

  private func releaseFreeBuf(_ b: AVAudioPCMBuffer) {
    poolLock.lock()
    freePool.append(b)
    poolLock.unlock()
  }

  private func isPooledBuffer(_ b: AVAudioPCMBuffer) -> Bool {
    return freePoolFrames > 0 && Int(b.frameCapacity) == freePoolFrames
  }

  private func rebuildEngineGraph() {
    let oldEngine = self.engine
    let oldPlayer = self.player

    oldEngine.inputNode.removeTap(onBus: 0)
    oldPlayer.stop()
    oldEngine.stop()
    oldEngine.reset()

    let newEngine = AVAudioEngine()
    let newPlayer = AVAudioPlayerNode()
    newEngine.attach(newPlayer)

    self.engine = newEngine
    self.player = newPlayer

    log("🧱[Engine] rebuilt fresh graph")
  }

  // MARK: Logging
  private func log(_ msg: String) { NSLog("%@", msg) }

  public static func register(with registrar: FlutterPluginRegistrar) {
    NSLog("✅✅ LoopbackPlugin REGISTERED iOS (channel=\(CHANNEL), events=\(EVENTS))")

    let inst = LoopbackPlugin()

    let ch = FlutterMethodChannel(name: CHANNEL, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(inst, channel: ch)

    let ev = FlutterEventChannel(name: EVENTS, binaryMessenger: registrar.messenger())
    ev.setStreamHandler(inst)

    inst.installNotifications()
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    log("📡[EventChannel] onListen args=\(String(describing: arguments))")
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    log("📡[EventChannel] onCancel args=\(String(describing: arguments))")
    self.eventSink = nil
    return nil
  }

  // MARK: Method handler
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method != "isWiredPresent" && call.method != "isBtHeadsetPresent" {
      log("📩[MethodChannel] method=\(call.method) args=\(String(describing: call.arguments))")
    }

    switch call.method {
    case "start":
      let args = call.arguments as? [String: Any]
      let voiceMode = (args?["voiceMode"] as? Bool) ?? false
      startLoopback(voiceMode: voiceMode)
      result(nil)

    case "stop":
      stopLoopback()
      result(nil)

    case "setParams":
      let args = call.arguments as? [String: Any]
      let enabled = (args?["eqEnabled"] as? Bool) ?? true
      let outGain = (args?["outputGain"] as? NSNumber)?.doubleValue ?? 1.0
      let mBoost  = (args?["masterBoost"] as? NSNumber)?.doubleValue ?? 1.0
      let list = (args?["bandGains"] as? [NSNumber])?.map { $0.doubleValue } ?? [1,1,1,1,1]

      eqEnabled = enabled
      outputGain = clamp(outGain, 0.0, 6.0)
      masterBoost = clamp(mBoost, 0.5, 4.0)

      var arr = [Double](repeating: 1.0, count: 5)
      for i in 0..<5 {
        let v = (i < list.count) ? list[i] : 1.0
        arr[i] = clamp(v, 0.25, 3.0)
      }
      bandGains = arr

      audioQueue.async { [weak self] in
        self?.applyEqIfChanged(force: true)
      }
      result(nil)

    case "setPreferWiredMic":
      let args = call.arguments as? [String: Any]
      let v = (args?["preferWiredMic"] as? Bool) ?? false
      let boost = (args?["headsetBoost"] as? NSNumber)?.doubleValue ?? 2.2
      let btBoost = (args?["bluetoothBoost"] as? NSNumber)?.doubleValue ?? self.bluetoothMicBoost

      preferWiredMic = v
      headsetMicBoost = clamp(boost, 1.0, 6.0)
      bluetoothMicBoost = clamp(btBoost, 1.0, 8.0)

      if running { handleRouteChanged() }
      result(nil)

    case "setDuckOthers":
      let args = call.arguments as? [String: Any]
      let enabled = (args?["enabled"] as? Bool) ?? true
      duckOthersEnabled = enabled

      if running {
        audioQueue.async { [weak self] in
          guard let self else { return }
          do { try self.configureSession(voicePath: self.lastVoicePath, sampleRate: self.lastSampleRate) }
          catch { self.log("❌[setDuckOthers] reconfigure failed error=\(error)") }
        }
      }
      result(nil)

    case "isWiredPresent":
      updateRouteCache()
      result(routeWired)

    case "isBtHeadsetPresent":
      updateRouteCache()
      result(routeBtMic)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: Debug helpers
  private func permStr(_ p: AVAudioSession.RecordPermission) -> String {
    switch p {
    case .granted: return "granted"
    case .denied: return "denied"
    case .undetermined: return "undetermined"
    @unknown default: return "unknown"
    }
  }

  private func routeStr(_ r: AVAudioSessionRouteDescription) -> String {
    let ins = r.inputs.map { "\($0.portType.rawValue)(\($0.portName))" }.joined(separator: ", ")
    let outs = r.outputs.map { "\($0.portType.rawValue)(\($0.portName))" }.joined(separator: ", ")
    return "inputs=[\(ins)] outputs=[\(outs)]"
  }

  private func logSession(_ tag: String) {
    let cat = session.category.rawValue
    let mode = session.mode.rawValue
    let sr = session.sampleRate
    let io = session.ioBufferDuration
    let r = routeStr(session.currentRoute)
    log("🎧[\(tag)] cat=\(cat) mode=\(mode) sr=\(sr) io=\(io) route=\(r)")
  }

  // MARK: Mic permission
  private func ensureMicPermission(_ cb: @escaping (Bool) -> Void) {
    let st = AVAudioSession.sharedInstance().recordPermission
    log("🎙️[MicPerm] recordPermission=\(permStr(st))")

    switch st {
    case .granted: cb(true)
    case .denied: cb(false)
    case .undetermined:
      DispatchQueue.main.async {
        AVAudioSession.sharedInstance().requestRecordPermission { ok in
          DispatchQueue.main.async { cb(ok) }
        }
      }
    @unknown default:
      cb(false)
    }
  }

  // MARK: Start/Stop
  private func startLoopback(voiceMode: Bool) {
    ensureMicPermission { [weak self] granted in
      guard let self else { return }
      if !granted {
        self.log("❌ Microphone permission denied -> cannot start loopback")
        return
      }
      self._startLoopbackInternal(voiceMode: voiceMode)
    }
  }

  private func _startLoopbackInternal(voiceMode: Bool) {
    stopLoopback()
    pendingStartToken += 1
    lastVoiceModeRequested = voiceMode

    updateRouteCache()

    if voiceMode && !routeBtMic {
      startLoopback(voiceMode: false)
      return
    }

    let a2dp  = routeA2dp
    let wired = routeWired
    let hfp   = routeBtMic

    if voiceMode {
      if hfp {
        configureAndStart(sampleRate: 16_000, voicePath: true, token: pendingStartToken)
      } else {
        configureAndStart(sampleRate: SPEAKER_VOICE_SR, voicePath: true, token: pendingStartToken)
      }
      return
    }

    if a2dp {
      configureAndStart(sampleRate: 44_100, voicePath: false, token: pendingStartToken)
      return
    }

    if hfp {
      configureAndStart(sampleRate: 16_000, voicePath: true, token: pendingStartToken)
      return
    }

    if !wired {
      configureAndStart(sampleRate: SPEAKER_VOICE_SR, voicePath: true, token: pendingStartToken)
      return
    }

    configureAndStart(sampleRate: 48_000, voicePath: false, token: pendingStartToken)
  }

  private func stopLoopback() {
    pendingStartToken += 1
    running = false

    // reset state immediately
    guardGain = 1.0
    monitorGain = 1.0
    harshMix = 0.0
    preDuckGain = 1.0
    expanderGain = 1.0
    lastRms = 0.0
    duckUntilTs = 0.0
    lastAnalyzeTs = 0.0
    lastA2dpCheckTs = 0.0
    lastMeterTs = 0.0
    lastGuardLogTs = 0.0
    lastRouteRestartTs = 0.0
    didLogTapBufferFormat = false

    hasTimeline = false
    nextPlaySampleTime = 0

    eq = nil
    hpf = nil
    a2dpLpf = nil
    spkLpf2 = nil
    harshDynLpf = nil
    gate = nil
    expander = nil
    afs = nil
    comp = nil
    limiter = nil
    monoFormat = nil

    poolLock.lock()
    freePool.removeAll()
    poolLock.unlock()
    freePoolFrames = 0

    // teardown async to reduce stop button hitch
    audioAsync { [weak self] in
      guard let self else { return }
      self.engine.inputNode.removeTap(onBus: 0)
      self.player.stop()
      self.engine.stop()
      self.engine.reset()
      try? self.session.setActive(false, options: [.notifyOthersOnDeactivation])
      self.log("⏹[stopLoopback] stopped + deactivated session")
    }
  }

  // MARK: Engine setup
  private func configureAndStart(sampleRate: Double, voicePath: Bool, token: Int) {
    guard token == pendingStartToken else { return }

    lastVoicePath = voicePath
    lastSampleRate = sampleRate

    updateRouteCache()
    a2dpFlag = (!voicePath) && routeA2dp && !routeWired

    do {
      try configureSession(voicePath: voicePath, sampleRate: sampleRate)
    } catch {
      log("❌[configureSession] failed -> fallback voicePath=true sr=\(SPEAKER_VOICE_SR) error=\(error)")
      try? configureSession(voicePath: true, sampleRate: SPEAKER_VOICE_SR)
    }

    rebuildEngineGraph()

    audioQueue.async { [weak self] in
      guard let self else { return }
      guard token == self.pendingStartToken else { return }

      self.player.stop()
      self.engine.stop()
      self.engine.reset()
      self.didLogTapBufferFormat = false

      let input = self.engine.inputNode

      usleep(20_000)

      let inputFormat = input.inputFormat(forBus: 0)
      let hwFs = inputFormat.sampleRate

      self.log("🎤[InputFormatHW] sr=\(inputFormat.sampleRate) ch=\(inputFormat.channelCount) fmt=\(inputFormat)")
      self.log("🎯[TapHWTarget] using input.inputFormat sampleRate=\(hwFs)")

      let mono = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                               sampleRate: hwFs,
                               channels: 1,
                               interleaved: false)!
      self.monoFormat = mono

      self.engine.connect(self.player, to: self.engine.mainMixerNode, format: mono)

      self.player.volume = 1.0
      self.engine.mainMixerNode.outputVolume = 1.0

      self.buildDsp(sampleRate: hwFs)

      if self.a2dpFlag {
        self.guardGain = 0.18
        self.monitorGain = self.A2DP_MONITOR_MIN_EFFECTIVE
        self.duckUntilTs = self.nowMs() + 1200.0
      } else {
        self.guardGain = 1.0
        self.monitorGain = 1.0
        self.harshMix = 0.0
        self.preDuckGain = 1.0
        self.expanderGain = 1.0
        self.duckUntilTs = 0.0
      }

      input.removeTap(onBus: 0)

      let tapFrames: Int
      if voicePath {
        tapFrames = max(256, min(512, Int(hwFs / 100.0)))
      } else {
        tapFrames = self.a2dpFlag ? 2048 : max(512, min(1024, Int(hwFs / 100.0)))
      }

      self.prepareFreePool(frames: tapFrames, mono: mono)

      input.installTap(onBus: 0,
                       bufferSize: AVAudioFrameCount(tapFrames),
                       format: nil) { [weak self] buf, _ in
        guard let self else { return }

        if !self.didLogTapBufferFormat {
          self.didLogTapBufferFormat = true
          self.log("🎤[TapBufferActual] sr=\(buf.format.sampleRate) ch=\(buf.format.channelCount) fmt=\(buf.format)")
        }

        self.processTap(buffer: buf, voicePath: voicePath)
      }

      do {
        try self.engine.start()
        self.player.play()

        self.hasTimeline = false
        self.nextPlaySampleTime = 0

        self.running = true
        self.log("✅[Engine] started voicePath=\(voicePath) sampleRatePref=\(sampleRate) inputSR=\(hwFs)")
        self.logSession("afterEngineStart")
      } catch {
        self.running = false
        self.log("❌[Engine] start failed error=\(error)")
      }
    }
  }

  private func configureSession(voicePath: Bool, sampleRate: Double) throws {
    let beforePerm = session.recordPermission
    log("⚙️[configureSession] BEGIN voicePath=\(voicePath) sampleRate=\(sampleRate) duck=\(duckOthersEnabled) perm=\(permStr(beforePerm))")
    log("🔥 BUILD_TAG=2026-03-17-SPK-AFS-DYNEQ-SOFTCLIP-DUCK-GUARD-2 SPEAKER_VOICE_SR=\(SPEAKER_VOICE_SR) FIXED_GAIN_SPEAKER=\(FIXED_GAIN_SPEAKER)")
    log("🔥 FILE=\(#file) LINE=\(#line)")
    logSession("beforeConfigure")

    let flags = liveRouteFlags()
    let wiredNow = flags.wired
    let a2dpNow  = flags.a2dp
    let btHfpNow = flags.btHfp
    let outIsSpeaker = flags.outIsSpeaker

    let speakerDefaultNow = voicePath && outIsSpeaker && !btHfpNow && !wiredNow && !a2dpNow

    log("⚙️[configureSession] flags wired=\(wiredNow) a2dp=\(a2dpNow) btHfp=\(btHfpNow) outIsSpeaker=\(outIsSpeaker) speakerDefaultNow=\(speakerDefaultNow)")

    var options: AVAudioSession.CategoryOptions = [.allowBluetooth]
    if !voicePath { options.insert(.allowBluetoothA2DP) }
    if duckOthersEnabled { options.insert(.duckOthers) }
    if speakerDefaultNow { options.insert(.defaultToSpeaker) }

    let mode: AVAudioSession.Mode
    if speakerDefaultNow {
      mode = .default
    } else if voicePath {
      mode = .voiceChat
    } else {
      mode = a2dpNow ? .default : .measurement
    }

    log("⚙️[configureSession] choose mode=\(mode.rawValue) options=\(options)")

    try session.setCategory(.playAndRecord, mode: mode, options: options)

    if speakerDefaultNow {
      try session.setPreferredSampleRate(48_000)
      try session.setPreferredIOBufferDuration(0.010)
    } else if a2dpNow && !voicePath {
      try session.setPreferredSampleRate(44_100)
      try session.setPreferredIOBufferDuration(0.030)
    } else {
      try session.setPreferredSampleRate(sampleRate)
      try session.setPreferredIOBufferDuration(voicePath ? 0.008 : 0.010)
    }

    if preferWiredMic {
      if let wired = session.availableInputs?.first(where: { $0.portType == .headsetMic || $0.portType == .usbAudio }) {
        try? session.setPreferredInput(wired)
      }
    }
    if voicePath {
      if let hfp = session.availableInputs?.first(where: { $0.portType == .bluetoothHFP }) {
        try? session.setPreferredInput(hfp)
      }
    }

    try session.setActive(true)
    log("🎯[ActiveSR] actual session sr=\(session.sampleRate) io=\(session.ioBufferDuration)")

    if speakerDefaultNow {
      try? session.overrideOutputAudioPort(.speaker)
    } else {
      try? session.overrideOutputAudioPort(.none)
    }

    updateRouteCache()

    log("⚙️[configureSession] END perm=\(permStr(session.recordPermission)) speakerDefaultNow=\(speakerDefaultNow)")
    logSession("afterConfigure")
  }

  private func buildDsp(sampleRate fs: Double) {
    eq = Eq5Band(fs: fs)

    hpf = OnePoleHpf(fs: fs, fc: SPK_HPF_HZ)
    a2dpLpf = OnePoleLpf(fs: fs, fc: SPK_LPF_HZ)
    spkLpf2 = OnePoleLpf(fs: fs, fc: SPK_LPF_HZ)
    harshDynLpf = OnePoleLpf(fs: fs, fc: 1550.0)

    gate = SimpleGate(sampleRate: fs,
                      threshold: SPK_GATE_THR,
                      attackMs: SPK_GATE_ATTACK_MS,
                      releaseMs: SPK_GATE_RELEASE_MS)

    expander = DownwardExpander(sampleRate: fs,
                                threshold: 0.012,
                                ratio: 1.45,
                                attackMs: 8.0,
                                releaseMs: 220.0,
                                floorGain: 0.55)

    afs = AntiFeedbackAfs(fs: fs)

    comp = SimpleCompressor(sampleRate: fs,
                            threshold: 0.075,
                            ratio: 2.4,
                            attackMs: 1.8,
                            releaseMs: 160.0)

    limiter = SimpleLimiter(sampleRate: fs,
                            threshold: 0.38,
                            attackMs: 0.12,
                            releaseMs: 180.0)

    hpf?.resetState()
    a2dpLpf?.resetState()
    spkLpf2?.resetState()
    harshDynLpf?.resetState()
    gate?.reset()
    expander?.reset()
    comp?.reset()
    limiter?.reset()
    afs?.reset()

    applyEqIfChanged(force: true)
  }

  // MARK: Processing loop
  private func processTap(buffer: AVAudioPCMBuffer, voicePath: Bool) {
    guard running else { return }
    guard let ch0 = buffer.floatChannelData?[0] else { return }

    let n = Int(buffer.frameLength)
    if n <= 0 { return }

    let now = nowMs()
    let live = liveRouteFlags()
    let isSpeakerDefaultNow = voicePath && live.outIsSpeaker && !live.wired && !live.a2dp && !live.btHfp && !a2dpFlag

    if (now - lastA2dpCheckTs) > 500 {
      lastA2dpCheckTs = now
      let newFlag = (!voicePath) && routeA2dp && !routeWired
      if newFlag != a2dpFlag {
        a2dpFlag = newFlag
        guardGain = 1.0
        monitorGain = 1.0
        harshMix = 0.0
        preDuckGain = 1.0
        expanderGain = 1.0
        limiter?.reset()
        comp?.reset()
        expander?.reset()
        gate?.reset()
        afs?.reset()
        duckUntilTs = 0.0

        hasTimeline = false
        nextPlaySampleTime = 0

        if a2dpFlag {
          guardGain = 0.18
          monitorGain = A2DP_MONITOR_MIN_EFFECTIVE
          duckUntilTs = now + 1200.0
        }
      }
    }

    applyEqIfChanged(force: false)

    var rawSumSq: Double = 0
    for i in 0..<n {
      let xf = Double(ch0[i])
      rawSumSq += xf * xf
    }
    let rawRms = sqrt(rawSumSq / Double(n)).clamp01()
    let rise = rawRms - lastRms
    let gateBypass = rawRms < 0.010

    // ===== noise-floor expander =====
    if isSpeakerDefaultNow {
      let targetExpand: Double
      if rawRms < EXPANDER_THRESHOLD {
        let t = max(0.0, rawRms / EXPANDER_THRESHOLD)
        targetExpand = pow(t, EXPANDER_RATIO)
      } else {
        targetExpand = 1.0
      }
      let k = (targetExpand < expanderGain) ? EXPANDER_ATTACK : EXPANDER_RELEASE
      expanderGain += (targetExpand - expanderGain) * k
    } else {
      expanderGain = 1.0
    }

    // ===== monitor suppression =====
    if a2dpFlag {
      let talking = rawRms > A2DP_TALK_RMS_EFFECTIVE
      let target = talking ? A2DP_MONITOR_MIN_EFFECTIVE : 1.0
      let k = talking ? A2DP_MONITOR_ATTACK : A2DP_MONITOR_RELEASE
      monitorGain += (target - monitorGain) * k
    } else if isSpeakerDefaultNow {
      let talking = rawRms > SPK_TALK_RMS
      let target = talking ? SPK_MONITOR_MIN : 1.0
      let k = talking ? SPK_MONITOR_ATTACK : SPK_MONITOR_RELEASE
      monitorGain += (target - monitorGain) * k
    } else {
      monitorGain = 1.0
    }

    // ===== pre-emptive duck =====
    if isSpeakerDefaultNow {
      let targetPreDuck: Double
      if rawRms > SPK_HARD_DUCK_RMS {
        targetPreDuck = 0.45
      } else if rawRms > SPK_PRE_DUCK_RMS {
        targetPreDuck = 0.72
      } else {
        targetPreDuck = 1.0
      }
      let k = (targetPreDuck < preDuckGain) ? 0.22 : 0.015
      preDuckGain += (targetPreDuck - preDuckGain) * k
    } else {
      preDuckGain = 1.0
    }

    // ===== dynamic harsh suppression only when RMS is really up =====
    if isSpeakerDefaultNow {
      let targetHarshMix: Double
      if rawRms < 0.020 {
        targetHarshMix = 0.0
      } else if rawRms > 0.16 {
        targetHarshMix = 0.65
      } else if rawRms > 0.08 {
        targetHarshMix = 0.45
      } else if rawRms > 0.04 {
        targetHarshMix = 0.22
      } else {
        targetHarshMix = 0.10
      }
      let k = (targetHarshMix > harshMix) ? 0.16 : 0.04
      harshMix += (targetHarshMix - harshMix) * k
    } else {
      harshMix = 0.0
    }

    // ===== AFS analyze =====
    if a2dpFlag && rawRms > 0.018 && (now - lastAnalyzeTs) >= A2DP_AFS_ANALYZE_MS {
      lastAnalyzeTs = now
      afs?.analyzeFloat(input: ch0, count: n)
    }
    if isSpeakerDefaultNow && rawRms > 0.012 && (now - lastAnalyzeTs) >= SPK_AFS_ANALYZE_MS {
      lastAnalyzeTs = now
      afs?.analyzeFloat(input: ch0, count: n)
    }

    let duckNow = (a2dpFlag || isSpeakerDefaultNow) && (now < duckUntilTs)

    let baseGain: Double = {
      if isSpeakerDefaultNow { return FIXED_GAIN_SPEAKER }
      if routeBtMic && voicePath { return FIXED_GAIN_HFP }
      if routeWired { return FIXED_GAIN_WIRED }
      return 1.0
    }()

    let micBoost: Double = {
      if preferWiredMic && routeWired { return headsetMicBoost }
      if routeBtMic && voicePath { return bluetoothMicBoost }
      return 1.0
    }()

    let gCap = a2dpFlag ? min(baseGain, A2DP_SAFE_GAIN_CAP) : baseGain
    var combinedGain = (gCap * masterBoost) * guardGain * micBoost * monitorGain * preDuckGain * expanderGain

    if isSpeakerDefaultNow {
      if rawRms > 0.12 {
        combinedGain = min(combinedGain, 0.16)
      }
      combinedGain = min(combinedGain, SPK_TOTAL_GAIN_CAP)
      combinedGain = max(combinedGain, 0.0)
    }

    if a2dpFlag { combinedGain = min(combinedGain, A2DP_TOTAL_GAIN_CAP) }

    if now - lastGuardLogTs > 1000 {
      lastGuardLogTs = now
      log("🎛️[GAIN] speakerDefault=\(isSpeakerDefaultNow) rawRms=\(String(format: "%.3f", rawRms)) rise=\(String(format: "%.3f", rise)) base=\(String(format: "%.2f", baseGain)) guard=\(String(format: "%.3f", guardGain)) monitor=\(String(format: "%.3f", monitorGain)) preDuck=\(String(format: "%.3f", preDuckGain)) expander=\(String(format: "%.3f", expanderGain)) harshMix=\(String(format: "%.2f", harshMix)) combined=\(String(format: "%.2f", combinedGain))")
    }

    guard let mono = monoFormat else { return }

    var outBuf: AVAudioPCMBuffer
    if let b = acquireFreeBuf(frames: n, mono: mono) {
      outBuf = b
    } else {
      guard let b = AVAudioPCMBuffer(pcmFormat: mono, frameCapacity: AVAudioFrameCount(n)) else { return }
      b.frameLength = AVAudioFrameCount(n)
      outBuf = b
    }

    guard let outData = outBuf.floatChannelData?[0] else {
      if isPooledBuffer(outBuf) { releaseFreeBuf(outBuf) }
      return
    }

    var sumSq: Double = 0

    if eqEnabled {
      for i in 0..<n {
        var x = Double(ch0[i])

        x = eq?.process(x) ?? x
        if !x.isFinite { x = 0 }

        if a2dpFlag || isSpeakerDefaultNow {
          x = hpf?.process(x) ?? x
          x = a2dpLpf?.process(x) ?? x

          if isSpeakerDefaultNow {
            x = spkLpf2?.process(x) ?? x

            if harshMix > 0.001 {
              let filtered = harshDynLpf?.process(x) ?? x
              x = (x * (1.0 - harshMix)) + (filtered * harshMix)
            } else {
              _ = harshDynLpf?.process(x)
            }
          }

          if isSpeakerDefaultNow {
            x = expander?.process(x) ?? x
          } else {
            x = gateBypass ? (x * 0.20) : (gate?.process(x) ?? x)
          }

          x = afs?.process(x) ?? x
        }

        if duckNow { x *= 0.74 }

        x *= combinedGain

        if a2dpFlag || isSpeakerDefaultNow {
          x = comp?.process(x) ?? x
        }

        x = limiter?.process(x) ?? x
        x = softClip(x)

        // extra silence floor kill after processing
        if isSpeakerDefaultNow && rawRms < 0.006 && abs(x) < 0.010 {
          x = 0.0
        }

        let y = x.clamp(-1.0, 1.0)
        outData[i] = Float(y)
        sumSq += y * y
      }
    } else {
      for i in 0..<n {
        var x = Double(ch0[i])

        if a2dpFlag || isSpeakerDefaultNow {
          x = hpf?.process(x) ?? x
          x = a2dpLpf?.process(x) ?? x

          if isSpeakerDefaultNow {
            x = spkLpf2?.process(x) ?? x

            if harshMix > 0.001 {
              let filtered = harshDynLpf?.process(x) ?? x
              x = (x * (1.0 - harshMix)) + (filtered * harshMix)
            } else {
              _ = harshDynLpf?.process(x)
            }
          }

          if isSpeakerDefaultNow {
            x = expander?.process(x) ?? x
          } else {
            x = gateBypass ? (x * 0.20) : (gate?.process(x) ?? x)
          }

          x = afs?.process(x) ?? x
        }

        if duckNow { x *= 0.74 }

        x *= combinedGain

        if a2dpFlag || isSpeakerDefaultNow {
          x = comp?.process(x) ?? x
        }

        x = limiter?.process(x) ?? x
        x = softClip(x)

        if isSpeakerDefaultNow && rawRms < 0.006 && abs(x) < 0.010 {
          x = 0.0
        }

        let y = x.clamp(-1.0, 1.0)
        outData[i] = Float(y)
        sumSq += y * y
      }
    }

    let rmsNow = sqrt(sumSq / Double(n)).clamp01()

    // ===== A2DP guard =====
    if a2dpFlag {
      let risingFast = (rmsNow - lastRms) > FEEDBACK_RISE_THRESHOLD
      let tooLoud = rmsNow > FEEDBACK_RMS_THRESHOLD

      if tooLoud || risingFast { duckUntilTs = now + A2DP_DUCK_MS }

      if tooLoud || risingFast {
        guardGain *= 0.78
        if guardGain < GUARD_MIN { guardGain = GUARD_MIN }
      } else {
        guardGain += (1.0 - guardGain) * 0.004
      }

      let earlyMute = (rmsNow > A2DP_EARLY_MUTE_RMS) || ((rmsNow - lastRms) > A2DP_EARLY_MUTE_RISE)
      let hardMute = (rmsNow > A2DP_HARD_MUTE_RMS)

      if earlyMute || hardMute {
        let muteMs = hardMute ? A2DP_MUTE_MS : (A2DP_MUTE_MS / 2.0)
        let muteSamples = min(n, max(1, Int(mono.sampleRate * (muteMs / 1000.0))))
        for i in 0..<muteSamples { outData[i] = 0 }
      }
    }

    // ===== Speaker guard =====
    if isSpeakerDefaultNow {
      let speakerRise = rise > SPK_FEEDBACK_RISE_THRESHOLD
      let speakerHot  = rawRms > SPK_FEEDBACK_RMS_THRESHOLD

      if rawRms > SPK_PRE_DUCK_RMS {
        duckUntilTs = now + 220.0
      }

      if speakerHot || speakerRise {
        duckUntilTs = now + SPK_DUCK_MS
        guardGain *= 0.82
        monitorGain *= 0.88
        if guardGain < SPK_GUARD_MIN { guardGain = SPK_GUARD_MIN }
      } else {
        guardGain += (1.0 - guardGain) * 0.010
      }

      if rawRms > SPK_HARD_DUCK_RMS {
        let muteSamples = min(n, max(1, Int(mono.sampleRate * 0.004)))
        for i in 0..<muteSamples { outData[i] *= 0.15 }
      }
    }

    lastRms = isSpeakerDefaultNow ? rawRms : rmsNow

    if (now - lastMeterTs) > 50 {
      lastMeterTs = now
      DispatchQueue.main.async { [weak self] in self?.eventSink?(rmsNow) }
    }

    let fs = mono.sampleRate
    let framesPos = AVAudioFramePosition(n)

    var when: AVAudioTime? = nil
    if let nodeTime = player.lastRenderTime,
       let playerTime = player.playerTime(forNodeTime: nodeTime) {

      if !hasTimeline {
        nextPlaySampleTime = playerTime.sampleTime + AVAudioFramePosition(fs * 0.03)
        hasTimeline = true
      }

      when = AVAudioTime(sampleTime: nextPlaySampleTime, atRate: fs)
      nextPlaySampleTime += framesPos
    } else {
      hasTimeline = false
      nextPlaySampleTime = 0
      when = nil
    }

    player.scheduleBuffer(
      outBuf,
      at: when,
      options: [],
      completionCallbackType: .dataConsumed
    ) { [weak self] _ in
      guard let self else { return }
      if self.isPooledBuffer(outBuf) { self.releaseFreeBuf(outBuf) }
    }
  }

  // MARK: EQ refresh
  private var lastEqEnabled: Bool = true
  private var lastGain: Double = 1.0
  private var lastMaster: Double = 1.0
  private var lastBands: [Double] = [1, 1, 1, 1, 1]

  private func applyEqIfChanged(force: Bool) {
    guard let eq = self.eq else { return }

    var changed = force
    if !changed {
      if eqEnabled != lastEqEnabled || outputGain != lastGain || masterBoost != lastMaster {
        changed = true
      } else {
        for i in 0..<5 where bandGains[i] != lastBands[i] { changed = true; break }
      }
    }
    guard changed else { return }

    lastEqEnabled = eqEnabled
    lastGain = outputGain
    lastMaster = masterBoost

    var bb = bandGains

    if a2dpFlag {
      bb[2] = min(bb[2], 1.05)
      bb[3] = min(bb[3], 1.10)
      bb[4] = min(bb[4], 1.10)
    }

    if lastVoicePath {
      bb[2] = min(bb[2], 0.84)
      bb[3] = min(bb[3], 0.56)
      bb[4] = min(bb[4], 0.40)
    }

    lastBands = bb

    var db = [Double](repeating: 0, count: 5)
    for i in 0..<5 {
      let gi = max(0.0001, bb[i])
      db[i] = 20.0 * log10(gi)
    }

    eq.updateGainsDb(db)
  }

  // MARK: Route change
  private func handleRouteChanged() {
    guard running else { return }

    let now = nowMs()
    if (now - lastRouteRestartTs) < 350.0 {
      log("⏭️[RouteChange] skip duplicate restart")
      return
    }
    lastRouteRestartTs = now

    updateRouteCache()

    hasTimeline = false
    nextPlaySampleTime = 0

    let voiceMode = lastVoiceModeRequested

    var targetSampleRate: Double = 48_000
    var targetVoicePath: Bool = false

    if voiceMode {
      if routeBtMic {
        targetSampleRate = 16_000
        targetVoicePath = true
      } else {
        targetSampleRate = SPEAKER_VOICE_SR
        targetVoicePath = true
      }
    } else {
      if routeA2dp {
        targetSampleRate = 44_100
        targetVoicePath = false
      } else if routeBtMic {
        targetSampleRate = 16_000
        targetVoicePath = true
      } else if !routeWired {
        targetSampleRate = SPEAKER_VOICE_SR
        targetVoicePath = true
      } else {
        targetSampleRate = 48_000
        targetVoicePath = false
      }
    }

    restartEngineAuto(sampleRate: targetSampleRate, voicePath: targetVoicePath)
  }

  private func restartEngineAuto(sampleRate: Double, voicePath: Bool) {
    if voicePath == lastVoicePath && sampleRate == lastSampleRate { return }

    let token = pendingStartToken + 1
    pendingStartToken = token
    running = false

    audioAsync { [weak self] in
      guard let self else { return }
      self.engine.inputNode.removeTap(onBus: 0)
      self.player.stop()
      self.engine.stop()
      self.engine.reset()
      self.configureAndStart(sampleRate: sampleRate, voicePath: voicePath, token: token)
    }
  }

  // MARK: Notifications
  private func installNotifications() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(onRouteChange(_:)),
      name: AVAudioSession.routeChangeNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(onInterruption(_:)),
      name: AVAudioSession.interruptionNotification,
      object: nil
    )
  }

  @objc private func onRouteChange(_ n: Notification) {
    log("🔄[RouteChange] \(routeStr(session.currentRoute))")
    audioQueue.async { [weak self] in
      self?.updateRouteCache()
      self?.handleRouteChanged()
    }
  }

  @objc private func onInterruption(_ n: Notification) {
    guard let info = n.userInfo,
          let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }

    if type == .began {
      log("⛔️[Interruption] began -> stop")
      stopLoopback()
    } else {
      log("▶️[Interruption] ended -> restart")
      startLoopback(voiceMode: lastVoiceModeRequested)
    }
  }

  deinit { NotificationCenter.default.removeObserver(self) }

  // MARK: Helpers
  private func softClip(_ x: Double) -> Double {
    let ax = abs(x)
    let th = 0.60
    if ax < th { return x }

    let sign = x >= 0 ? 1.0 : -1.0
    let normalized = (ax - th) / max(1e-9, (1.0 - th))
    let clipped = th + (1.0 - th) * tanh(1.6 * normalized)
    let y = sign * clipped
    return y.isFinite ? y : 0.0
  }

  private func nowMs() -> Double { CACurrentMediaTime() * 1000.0 }
  private func clamp(_ x: Double, _ lo: Double, _ hi: Double) -> Double { min(hi, max(lo, x)) }
}

fileprivate extension Double {
  func clamp(_ lo: Double, _ hi: Double) -> Double { min(hi, max(lo, self)) }
  func clamp01() -> Double { min(1.0, max(0.0, self)) }
}