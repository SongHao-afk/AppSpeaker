import Flutter
import UIKit
import AVFoundation
import QuartzCore

public final class LoopbackPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

  private static let CHANNEL = "loopback"
  private static let EVENTS  = "loopback_events"

  private let session = AVAudioSession.sharedInstance()
  private var engine = AVAudioEngine()
  private var player = AVAudioPlayerNode()

  private let audioQueue = DispatchQueue(label: "loopback.audio.queue", qos: .userInteractive)
  private var running: Bool = false
  private var pendingStartToken: Int = 0

  private let audioQueueKey = DispatchSpecificKey<Void>()

  public override init() {
    super.init()
    audioQueue.setSpecific(key: audioQueueKey, value: ())
  }

  private func onAudioQueue() -> Bool {
    DispatchQueue.getSpecific(key: audioQueueKey) != nil
  }

  private func audioAsync(_ block: @escaping () -> Void) {
    audioQueue.async(execute: block)
  }

  private func audioSyncIfNeeded(_ block: () -> Void) {
    if onAudioQueue() { block() } else { audioQueue.sync(execute: block) }
  }

  private var eventSink: FlutterEventSink?

  private var eqEnabled: Bool = true
  private var outputGain: Double = 1.0
  private var bandGains: [Double] = [1, 1, 1, 1, 1]
  private var masterBoost: Double = 1.0
  private var duckOthersEnabled: Bool = true

  private var preferWiredMic: Bool = false
  private var headsetMicBoost: Double = 3.0
  private var bluetoothMicBoost: Double = 4.5

  private var lastVoiceModeRequested: Bool = false
  private var lastVoicePath: Bool = false
  private var lastSampleRate: Double = 48_000

  private var wantsBluetoothA2DPPlayback: Bool = false
  private var lastNonVoiceA2dpTargetTs: Double = 0.0

  private let A2DP_SAFE_GAIN_CAP: Double = 2.20
  private let A2DP_TOTAL_GAIN_CAP: Double = 2.40
  private let FEEDBACK_RMS_THRESHOLD: Double = 0.18
  private let FEEDBACK_RISE_THRESHOLD: Double = 0.035
  private let GUARD_MIN: Double = 0.05
  private let A2DP_MUTE_MS: Double = 40.0
  private let A2DP_HARD_MUTE_RMS: Double = 0.55

  private let SPEAKER_VOICE_SR: Double = 48_000

  private let FIXED_GAIN_SPEAKER: Double = 1.38
  private let FIXED_GAIN_WIRED:   Double = 2.80
  private let FIXED_GAIN_HFP:     Double = 2.50
  private let SPK_TOTAL_GAIN_CAP: Double = 2.20

  private let A2DP_HPF_HZ: Double = 50.0
  private let A2DP_AFS_ANALYZE_MS: Double = 100.0
  private let A2DP_DUCK_MS: Double = 450.0
  private let A2DP_EARLY_MUTE_RMS: Double = 0.30
  private let A2DP_EARLY_MUTE_RISE: Double = 0.08
  private let A2DP_LPF_HZ: Double = 12000.0
  private let A2DP_GATE_THR: Double = 0.012
  private let A2DP_GATE_ATTACK_MS: Double = 4.0
  private let A2DP_GATE_RELEASE_MS: Double = 260.0

  private let SPK_HPF_HZ: Double = 150.0
  private let SPK_LPF_HZ: Double = 1750.0
  private let SPK_GATE_THR: Double = 0.022
  private let SPK_GATE_ATTACK_MS: Double = 2.0
  private let SPK_GATE_RELEASE_MS: Double = 160.0

  private let SPK_AFS_ANALYZE_MS: Double = 32.0
  private let SPK_DUCK_MS: Double = 900.0

  private let SPK_FEEDBACK_RMS_THRESHOLD: Double = 0.040
  private let SPK_FEEDBACK_RISE_THRESHOLD: Double = 0.010
  private let SPK_GUARD_MIN: Double = 0.05

  private let SPK_TALK_RMS: Double = 0.030
  private let SPK_MONITOR_MIN: Double = 0.62
  private let SPK_MONITOR_ATTACK: Double = 0.18
  private let SPK_MONITOR_RELEASE: Double = 0.012

  private let SPK_PRE_DUCK_RMS: Double = 0.020
  private let SPK_HARD_DUCK_RMS: Double = 0.080

  private let A2DP_TALK_RMS_EFFECTIVE: Double = 0.030
  private let A2DP_MONITOR_MIN_EFFECTIVE: Double = 0.60
  private let A2DP_MONITOR_ATTACK: Double = 0.12
  private let A2DP_MONITOR_RELEASE: Double = 0.008

  private let EXPANDER_THRESHOLD: Double = 0.006
  private let EXPANDER_RATIO: Double = 0.65
  private let EXPANDER_ATTACK: Double = 0.16
  private let EXPANDER_RELEASE: Double = 0.035

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

  private var speechTracker: SpeechPresenceTracker?
  private var speakerGuardCtl: SpeakerFeedbackController?

  private var echoReducer: AdaptiveEchoReducer?
  private var presenceSmoother: PresenceSmoother?

  private var popSmoother: SpeakerPopSmoother?
  private var smoothedCombinedGain: Double = 0.13

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

  private var lastSpeechActive: Bool = false
  private var lastSpeechScore: Double = 0.0
  private var lastZcr: Double = 0.0

  private var lastEchoCancelGain: Double = 0.0
  private var lastEchoDelayMs: Double = 0.0
  private var lastPresenceMix: Double = 0.0

  private var monoFormat: AVAudioFormat?

  private let poolLock = NSLock()
  private var freePool: [AVAudioPCMBuffer] = []
  private var freePoolFrames: Int = 0
  private var freePoolCount: Int = 36

  private var nextPlaySampleTime: AVAudioFramePosition = 0
  private var hasTimeline: Bool = false

  private var routeA2dp: Bool = false
  private var routeWired: Bool = false
  private var routeBtMic: Bool = false

  private var lastRouteRestartTs: Double = 0.0
  private var didLogTapBufferFormat: Bool = false

  private var startWarmupUntilTs: Double = 0.0
  private var isStoppingNow: Bool = false

  private var transitionInProgress: Bool = false
  private var queuedStartVoiceMode: Bool? = nil
  private var lastStopCompletedTs: Double = 0.0
  private let START_AFTER_STOP_DELAY_MS: Double = 180.0

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

  private func liveRouteFlags() -> (a2dp: Bool, wired: Bool, btHfp: Bool, outIsSpeaker: Bool, outIsReceiver: Bool) {
    let r = session.currentRoute
    let a2dp = r.outputs.contains { $0.portType == .bluetoothA2DP }
    let wiredOut = r.outputs.contains { $0.portType == .headphones || $0.portType == .usbAudio }
    let wiredIn  = r.inputs.contains  { $0.portType == .headsetMic || $0.portType == .usbAudio }
    let wired = wiredOut || wiredIn
    let btHfp = r.inputs.contains { $0.portType == .bluetoothHFP }
    let outIsSpeaker = r.outputs.contains { $0.portType == .builtInSpeaker }
    let outIsReceiver = r.outputs.contains { $0.portType == .builtInReceiver }
    return (a2dp, wired, btHfp, outIsSpeaker, outIsReceiver)
  }

  private func hasBluetoothA2dpOutputAvailable() -> Bool {
    session.currentRoute.outputs.contains { $0.portType == .bluetoothA2DP }
  }

  private func hasAnyBluetoothOutputNow() -> Bool {
    let outs = session.currentRoute.outputs
    return outs.contains {
      $0.portType == .bluetoothA2DP || $0.portType == .bluetoothHFP
    }
  }

  private func shouldPreferBluetoothA2DPOnRouteChange(reason: AVAudioSession.RouteChangeReason?) -> Bool {
    guard !lastVoiceModeRequested else { return false }

    let live = liveRouteFlags()

    if live.a2dp { return true }

    if reason == .newDeviceAvailable, hasAnyBluetoothOutputNow() {
      return true
    }

    return wantsBluetoothA2DPPlayback
  }

  private func preferredBuiltInMic() -> AVAudioSessionPortDescription? {
    session.availableInputs?.first {
      $0.portType == .builtInMic
    }
  }

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
    freePoolFrames > 0 && Int(b.frameCapacity) == freePoolFrames
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
      audioQueue.async { [weak self] in
        guard let self else { return }
        self.queuedStartVoiceMode = nil
        if self.transitionInProgress {
          self.log("🛑[Stop] requested while transitionInProgress -> will stop now")
        }
        self.transitionInProgress = true
        self.stopLoopbackInternal(clearTransitionWhenDone: true)
      }
      result(nil)

    case "setParams":
      let args = call.arguments as? [String: Any]
      let enabled = (args?["eqEnabled"] as? Bool) ?? true
      let outGain = (args?["outputGain"] as? NSNumber)?.doubleValue ?? 1.0
      let mBoost  = (args?["masterBoost"] as? NSNumber)?.doubleValue ?? 1.0
      let list = (args?["bandGains"] as? [NSNumber])?.map { $0.doubleValue } ?? [1,1,1,1,1]

      audioQueue.async { [weak self] in
        guard let self else { return }

        self.eqEnabled = enabled
        self.outputGain = self.clamp(outGain, 0.0, 6.0)
        self.masterBoost = self.clamp(mBoost, 0.5, 4.0)

        var arr = [Double](repeating: 1.0, count: 5)
        for i in 0..<5 {
          let v = (i < list.count) ? list[i] : 1.0
          arr[i] = self.clamp(v, 0.25, 3.0)
        }
        self.bandGains = arr

        self.log("🎚️[setParams] applied eq=\(enabled) out=\(self.outputGain) master=\(self.masterBoost) bands=\(self.bandGains)")

        self.applyEqIfChanged(force: true)
      }
      result(nil)

    case "setPreferWiredMic":
      let args = call.arguments as? [String: Any]
      let v = (args?["preferWiredMic"] as? Bool) ?? false
      let boost = (args?["headsetBoost"] as? NSNumber)?.doubleValue ?? 2.2
      let btBoost = (args?["bluetoothBoost"] as? NSNumber)?.doubleValue ?? self.bluetoothMicBoost

      audioQueue.async { [weak self] in
        guard let self else { return }

        self.preferWiredMic = v
        self.headsetMicBoost = self.clamp(boost, 1.0, 6.0)
        self.bluetoothMicBoost = self.clamp(btBoost, 1.0, 8.0)

        self.log("🎙️[setPreferWiredMic] prefer=\(v) wiredBoost=\(self.headsetMicBoost) btBoost=\(self.bluetoothMicBoost)")

        if self.running {
          self.handleRouteChanged()
        }
      }
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

  private func startLoopback(voiceMode: Bool) {
    ensureMicPermission { [weak self] granted in
      guard let self else { return }

      if !granted {
        self.log("❌ Microphone permission denied -> cannot start loopback")
        return
      }

      self.audioQueue.async {
        if self.transitionInProgress {
          self.queuedStartVoiceMode = voiceMode
          self.log("🕒[Start] queued voiceMode=\(voiceMode) because transitionInProgress")
          return
        }

        self.transitionInProgress = true
        self._startLoopbackInternal(voiceMode: voiceMode)
      }
    }
  }

  private func _startLoopbackInternal(voiceMode requestedVoiceMode: Bool) {
    stopLoopbackInternal(clearTransitionWhenDone: false)

    pendingStartToken += 1

    var voiceMode = requestedVoiceMode
    lastVoiceModeRequested = voiceMode

    updateRouteCache()

    wantsBluetoothA2DPPlayback = !voiceMode && (routeA2dp || hasAnyBluetoothOutputNow())
    if wantsBluetoothA2DPPlayback {
      lastNonVoiceA2dpTargetTs = nowMs()
    }

    if voiceMode && !routeBtMic {
      log("↩️[Start] voiceMode requested but no BT HFP mic -> fallback without recursive start")
      voiceMode = false
      lastVoiceModeRequested = false
    }

    let a2dp  = routeA2dp
    let wired = routeWired
    let hfp   = routeBtMic

    let targetSampleRate: Double
    let targetVoicePath: Bool

    if voiceMode {
      if hfp {
        targetSampleRate = 16_000
        targetVoicePath = true
      } else {
        targetSampleRate = SPEAKER_VOICE_SR
        targetVoicePath = true
      }
    } else if a2dp {
      targetSampleRate = 44_100
      targetVoicePath = false
    } else if hfp {
      targetSampleRate = 16_000
      targetVoicePath = true
    } else if !wired {
      targetSampleRate = SPEAKER_VOICE_SR
      targetVoicePath = true
    } else {
      targetSampleRate = 48_000
      targetVoicePath = false
    }

    let token = pendingStartToken

    log("🧭[Start] scheduled after stop delay voicePath=\(targetVoicePath) sr=\(targetSampleRate) token=\(token)")

    audioQueue.asyncAfter(deadline: .now() + .milliseconds(Int(START_AFTER_STOP_DELAY_MS))) { [weak self] in
      guard let self else { return }

      guard token == self.pendingStartToken else {
        self.log("⏭️[Start] canceled stale delayed start token=\(token) current=\(self.pendingStartToken)")
        self.finishTransitionAndRunQueuedStartIfNeeded()
        return
      }

      self.configureAndStart(sampleRate: targetSampleRate, voicePath: targetVoicePath, token: token)
    }
  }

  private func stopLoopback() {
    stopLoopbackInternal(clearTransitionWhenDone: true)
  }

  private func stopLoopbackInternal(clearTransitionWhenDone: Bool) {
    if isStoppingNow {
      log("⏭️[stopLoopback] ignored duplicate because isStoppingNow=true")
      if clearTransitionWhenDone {
        finishTransitionAndRunQueuedStartIfNeeded()
      }
      return
    }

    pendingStartToken += 1
    running = false
    isStoppingNow = true

    wantsBluetoothA2DPPlayback = false
    lastNonVoiceA2dpTargetTs = 0.0

    guardGain = 1.0
    monitorGain = 1.0
    harshMix = 0.0
    preDuckGain = 1.0
    expanderGain = 1.0
    lastRms = 0.0
    lastGuardLogTs = 0.0
    lastMeterTs = 0.0
    duckUntilTs = 0.0
    lastAnalyzeTs = 0.0
    lastA2dpCheckTs = 0.0
    lastRouteRestartTs = 0.0
    didLogTapBufferFormat = false
    startWarmupUntilTs = 0.0
    lastEchoCancelGain = 0.0
    lastEchoDelayMs = 0.0
    lastPresenceMix = 0.0

    smoothedCombinedGain = 0.13

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
    echoReducer = nil
    presenceSmoother = nil
    popSmoother = nil
    monoFormat = nil

    speechTracker = nil
    speakerGuardCtl = nil
    lastSpeechActive = false
    lastSpeechScore = 0.0
    lastZcr = 0.0

    lastEqEnabled = true
    lastGain = -999.0
    lastMaster = -999.0
    lastBands = [-999.0, -999.0, -999.0, -999.0, -999.0]

    poolLock.lock()
    freePool.removeAll()
    poolLock.unlock()
    freePoolFrames = 0

    audioSyncIfNeeded {
      self.engine.inputNode.removeTap(onBus: 0)
      self.player.stop()
      self.engine.stop()
      self.engine.reset()
      try? self.session.setActive(false, options: [.notifyOthersOnDeactivation])
      self.lastStopCompletedTs = self.nowMs()
      self.log("⏹[stopLoopback] stopped + deactivated session")
    }

    isStoppingNow = false

    if clearTransitionWhenDone {
      finishTransitionAndRunQueuedStartIfNeeded()
    }
  }

  private func finishTransitionAndRunQueuedStartIfNeeded() {
    transitionInProgress = false

    guard let queued = queuedStartVoiceMode else { return }

    queuedStartVoiceMode = nil
    transitionInProgress = true

    log("▶️[Start] running queued start voiceMode=\(queued)")
    _startLoopbackInternal(voiceMode: queued)
  }

  private func configureAndStart(sampleRate: Double, voicePath: Bool, token: Int) {
    guard token == pendingStartToken else { return }

    lastVoicePath = voicePath
    lastSampleRate = sampleRate

    updateRouteCache()
    a2dpFlag = (!voicePath) && (routeA2dp || wantsBluetoothA2DPPlayback) && !routeWired

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

      self.startWarmupUntilTs = self.nowMs() + 450.0
      self.isStoppingNow = false

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
        self.transitionInProgress = false
        self.log("✅[Engine] started voicePath=\(voicePath) sampleRatePref=\(sampleRate) inputSR=\(hwFs)")
        self.logSession("afterEngineStart")
        self.finishTransitionAndRunQueuedStartIfNeeded()
      } catch {
        self.running = false
        self.transitionInProgress = false
        self.log("❌[Engine] start failed error=\(error)")
        self.finishTransitionAndRunQueuedStartIfNeeded()
      }
    }
  }

  private func configureSession(voicePath: Bool, sampleRate: Double) throws {
    let beforePerm = session.recordPermission
    log("⚙️[configureSession] BEGIN voicePath=\(voicePath) sampleRate=\(sampleRate) duck=\(duckOthersEnabled) perm=\(permStr(beforePerm))")
    log("🔥 BUILD_TAG=2026-04-23-BT-ROUTE-FIX SPEAKER_VOICE_SR=\(SPEAKER_VOICE_SR)")
    logSession("beforeConfigure")

    let ins = session.availableInputs ?? []
    let wiredAvailable = ins.contains { $0.portType == .headsetMic || $0.portType == .usbAudio }
    let btHfpAvailable = ins.contains { $0.portType == .bluetoothHFP }
    let a2dpExpected = wantsBluetoothA2DPPlayback && !voicePath

    var options: AVAudioSession.CategoryOptions = [.defaultToSpeaker]
    if duckOthersEnabled { options.insert(.duckOthers) }

    if voicePath {
      options.insert(.allowBluetooth)
    } else if a2dpExpected {
      options.insert(.allowBluetoothA2DP)
    } else {
      options.insert(.allowBluetooth)
      options.insert(.allowBluetoothA2DP)
    }

    let liveBefore = liveRouteFlags()

    let mode: AVAudioSession.Mode
    if voicePath && (liveBefore.btHfp || btHfpAvailable) && !a2dpExpected {
      mode = .voiceChat
    } else {
      mode = .default
    }

    log("⚙️[configureSession] PRE-SET mode=\(mode.rawValue) options=\(options) wired=\(wiredAvailable) hfp=\(btHfpAvailable)")

    try session.setCategory(.playAndRecord, mode: mode, options: options)
    try session.setActive(true)

    let flags = liveRouteFlags()
    let wiredNow = flags.wired
    let a2dpNow  = flags.a2dp || a2dpExpected
    let btHfpNow = flags.btHfp
    let outIsSpeaker = flags.outIsSpeaker

    let speakerDefaultNow = voicePath && outIsSpeaker && !btHfpNow && !wiredNow && !a2dpNow

    log("⚙️[configureSession] FINAL flags wired=\(wiredNow) a2dp=\(a2dpNow) btHfp=\(btHfpNow) outIsSpeaker=\(outIsSpeaker) speakerDefaultNow=\(speakerDefaultNow) wantsBluetoothA2DPPlayback=\(wantsBluetoothA2DPPlayback)")

    try session.setCategory(.playAndRecord, mode: mode, options: options)

    if speakerDefaultNow {
      try session.setPreferredSampleRate(48_000)
      try session.setPreferredIOBufferDuration(0.010)
    } else if a2dpNow && !voicePath {
      try session.setPreferredSampleRate(44_100)
      try session.setPreferredIOBufferDuration(0.023)
    } else {
      try session.setPreferredSampleRate(sampleRate)
      try session.setPreferredIOBufferDuration(voicePath ? 0.008 : 0.010)
    }

    if preferWiredMic {
      if let wired = session.availableInputs?.first(where: { $0.portType == .headsetMic || $0.portType == .usbAudio }) {
        try? session.setPreferredInput(wired)
      }
    } else if a2dpNow && !voicePath {
      if let builtIn = preferredBuiltInMic() {
        try? session.setPreferredInput(builtIn)
        log("🎙️[configureSession] preferred built-in mic for A2DP path")
      }
    } else if voicePath {
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

    if a2dpNow && !voicePath {
      if let builtIn = preferredBuiltInMic() {
        try? session.setPreferredInput(builtIn)
      }
      updateRouteCache()
      log("🎧[A2DP-FIX] route after A2DP configure = \(routeStr(session.currentRoute))")
    }

    log("⚙️[configureSession] END perm=\(permStr(session.recordPermission)) speakerDefaultNow=\(speakerDefaultNow)")
    logSession("afterConfigure")
  }

  private func buildDsp(sampleRate fs: Double) {
    eq = Eq5Band(fs: fs)

    hpf = OnePoleHpf(fs: fs, fc: SPK_HPF_HZ)
    a2dpLpf = OnePoleLpf(fs: fs, fc: SPK_LPF_HZ)

    spkLpf2 = OnePoleLpf(fs: fs, fc: 1350.0)
    harshDynLpf = OnePoleLpf(fs: fs, fc: 950.0)

    gate = SimpleGate(sampleRate: fs,
                      threshold: SPK_GATE_THR,
                      attackMs: SPK_GATE_ATTACK_MS,
                      releaseMs: SPK_GATE_RELEASE_MS)

    expander = DownwardExpander(sampleRate: fs,
                                threshold: 0.006,
                                ratio: 1.60,
                                attackMs: 8.0,
                                releaseMs: 180.0,
                                floorGain: 0.16)

    afs = AntiFeedbackAfs(fs: fs)

    comp = SimpleCompressor(sampleRate: fs,
                            threshold: 0.40,
                            ratio: 2.0,
                            attackMs: 2.0,
                            releaseMs: 150.0)

    limiter = SimpleLimiter(sampleRate: fs,
                            threshold: 0.65,
                            attackMs: 0.08,
                            releaseMs: 220.0)

    speechTracker = SpeechPresenceTracker(sampleRate: fs,
                                         rmsOn: 0.055,
                                         rmsOff: 0.032,
                                         zcrMin: 0.006,
                                         zcrMax: 0.22,
                                         attackMs: 4.0,
                                         releaseMs: 65.0,
                                         hangMs: 70.0)

    speakerGuardCtl = SpeakerFeedbackController(
      guardMinSpeech: 0.58,
      guardMinNonSpeech: 0.12,
      hotRms: 0.078,
      riseThr: 0.018
    )

    echoReducer = AdaptiveEchoReducer(sampleRate: fs)
    presenceSmoother = PresenceSmoother(sampleRate: fs)
    popSmoother = SpeakerPopSmoother()
    smoothedCombinedGain = 0.13

    hpf?.resetState()
    a2dpLpf?.resetState()
    spkLpf2?.resetState()
    harshDynLpf?.resetState()
    gate?.reset()
    expander?.reset()
    comp?.reset()
    limiter?.reset()
    afs?.reset()
    speechTracker?.reset()
    speakerGuardCtl?.reset()
    echoReducer?.reset()
    presenceSmoother?.reset()
    popSmoother?.reset()

    lastEchoCancelGain = 0.0
    lastEchoDelayMs = 0.0
    lastPresenceMix = 0.0

    applyEqIfChanged(force: true)
  }

  private func processTap(buffer: AVAudioPCMBuffer, voicePath: Bool) {
    guard running else { return }
    guard !isStoppingNow else { return }
    guard let ch0 = buffer.floatChannelData?[0] else { return }

    let n = Int(buffer.frameLength)
    if n <= 0 { return }

    let now = nowMs()
    let inStartupGrace = now < startWarmupUntilTs

    let live = liveRouteFlags()
    let isSpeakerDefaultNow = voicePath && live.outIsSpeaker && !live.wired && !live.a2dp && !live.btHfp && !a2dpFlag

    if (now - lastA2dpCheckTs) > 500 {
      lastA2dpCheckTs = now
      let newFlag = (!voicePath) && (routeA2dp || wantsBluetoothA2DPPlayback) && !routeWired
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
        speechTracker?.reset()
        speakerGuardCtl?.reset()
        echoReducer?.reset()
        presenceSmoother?.reset()
        popSmoother?.reset()
        duckUntilTs = 0.0
        startWarmupUntilTs = now + 450.0
        lastEchoCancelGain = 0.0
        lastEchoDelayMs = 0.0
        lastPresenceMix = 0.0
        smoothedCombinedGain = 0.13

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

    var speechActive = false
    if isSpeakerDefaultNow, let st = speechTracker {
      let speechInfo = st.analyze(buf: ch0, count: n, nowMs: now)
      speechActive = speechInfo.active

      if speechActive && rawRms < 0.050 {
        speechActive = false
      }
      if !speechActive && rawRms > 0.065 && speechInfo.zcr < 0.080 {
        speechActive = true
      }

      lastSpeechActive = speechActive
      lastSpeechScore = speechInfo.score
      lastZcr = speechInfo.zcr
    } else {
      lastSpeechActive = false
      lastSpeechScore = 0.0
      lastZcr = 0.0
    }

    if isSpeakerDefaultNow {
      let targetExpand: Double
      if speechActive {
        targetExpand = 1.0
      } else if rawRms < EXPANDER_THRESHOLD {
        let t = max(0.0, rawRms / EXPANDER_THRESHOLD)
        targetExpand = 0.22 + 0.38 * pow(t, EXPANDER_RATIO)
      } else {
        targetExpand = 0.72
      }
      let k = (targetExpand < expanderGain) ? EXPANDER_ATTACK : EXPANDER_RELEASE
      expanderGain += (targetExpand - expanderGain) * k
    } else {
      expanderGain = 1.0
    }

    if a2dpFlag {
      let talking = rawRms > A2DP_TALK_RMS_EFFECTIVE
      let target = talking ? A2DP_MONITOR_MIN_EFFECTIVE : 1.0
      let k = talking ? A2DP_MONITOR_ATTACK : A2DP_MONITOR_RELEASE
      monitorGain += (target - monitorGain) * k
    } else if isSpeakerDefaultNow {
      if let ctl = speakerGuardCtl {
        ctl.update(rawRms: rawRms, rise: rise, speechActive: speechActive, nowMs: now, startupGrace: inStartupGrace)

        monitorGain = ctl.monitorGain
        preDuckGain = ctl.preDuckGain
        guardGain = ctl.guardGain

        if speechActive {
          monitorGain = min(monitorGain, 0.97)
          preDuckGain = min(preDuckGain, 0.98)
          guardGain = min(guardGain, 1.00)
        }

        duckUntilTs = max(duckUntilTs, ctl.duckUntilMs)
      } else {
        monitorGain = 1.0
        preDuckGain = 1.0
      }
    } else {
      monitorGain = 1.0
      preDuckGain = 1.0
    }

    if !isSpeakerDefaultNow {
      preDuckGain = 1.0
    }

    if isSpeakerDefaultNow {
      let targetHarshMix: Double

      if inStartupGrace {
        if rawRms > 0.12 {
          targetHarshMix = 0.30
        } else {
          targetHarshMix = 0.14
        }
      } else if speechActive {
        if rawRms > 0.14 {
          targetHarshMix = 0.30
        } else if rawRms > 0.08 {
          targetHarshMix = 0.22
        } else {
          targetHarshMix = 0.10
        }
      } else {
        if rawRms < 0.012 {
          targetHarshMix = 0.0
        } else if rawRms > 0.14 {
          targetHarshMix = 0.34
        } else if rawRms > 0.08 {
          targetHarshMix = 0.24
        } else if rawRms > 0.04 {
          targetHarshMix = 0.14
        } else {
          targetHarshMix = 0.08
        }
      }

      let k = (targetHarshMix > harshMix) ? 0.12 : 0.05
      harshMix += (targetHarshMix - harshMix) * k
    } else {
      harshMix = 0.0
    }

    if a2dpFlag && rawRms > 0.018 && (now - lastAnalyzeTs) >= A2DP_AFS_ANALYZE_MS {
      lastAnalyzeTs = now
      afs?.analyzeFloat(input: ch0, count: n)
    }
    if isSpeakerDefaultNow && rawRms > 0.008 && (now - lastAnalyzeTs) >= SPK_AFS_ANALYZE_MS {
      lastAnalyzeTs = now
      afs?.analyzeFloat(input: ch0, count: n)
    }

    let duckNow = (a2dpFlag || isSpeakerDefaultNow) && (now < duckUntilTs)

    let baseGain: Double = {
      if isSpeakerDefaultNow { return FIXED_GAIN_SPEAKER }
      if routeBtMic && voicePath { return FIXED_GAIN_HFP }
      if routeWired { return FIXED_GAIN_WIRED }
      if a2dpFlag { return 1.0 }
      return 1.0
    }()

    let micBoost: Double = {
      if preferWiredMic && routeWired { return headsetMicBoost }
      if routeBtMic && voicePath { return bluetoothMicBoost }
      return 1.0
    }()

    let gCap = a2dpFlag ? min(baseGain, A2DP_SAFE_GAIN_CAP) : baseGain

    let userOutGain: Double = {
      if isSpeakerDefaultNow {
        return clamp(outputGain, 1.00, 2.20)
      }
      if a2dpFlag {
        return clamp(outputGain, 0.70, 1.30)
      }
      return clamp(outputGain, 0.0, 6.0)
    }()

    var combinedGain = (gCap * masterBoost * userOutGain) *
                       guardGain * micBoost * monitorGain * preDuckGain * expanderGain

    if isSpeakerDefaultNow {
      if speechActive {
        combinedGain = min(combinedGain, 0.30)
        combinedGain = max(combinedGain, 0.14)
      } else {
        combinedGain = min(combinedGain, 0.12)
      }

      let k = combinedGain > smoothedCombinedGain ? 0.045 : 0.12
      smoothedCombinedGain += (combinedGain - smoothedCombinedGain) * k
      combinedGain = smoothedCombinedGain
    }

    if a2dpFlag { combinedGain = min(combinedGain, A2DP_TOTAL_GAIN_CAP) }

    if now - lastGuardLogTs > 1000 {
      lastGuardLogTs = now
      log("🎛️[GAIN] speakerDefault=\(isSpeakerDefaultNow) a2dp=\(a2dpFlag) speech=\(speechActive) speechScore=\(String(format: "%.2f", lastSpeechScore)) zcr=\(String(format: "%.3f", lastZcr)) startupGrace=\(inStartupGrace) rawRms=\(String(format: "%.3f", rawRms)) rise=\(String(format: "%.3f", rise)) base=\(String(format: "%.2f", baseGain)) guard=\(String(format: "%.3f", guardGain)) monitor=\(String(format: "%.3f", monitorGain)) preDuck=\(String(format: "%.3f", preDuckGain)) expander=\(String(format: "%.3f", expanderGain)) harshMix=\(String(format: "%.2f", harshMix)) echoCancel=\(String(format: "%.2f", lastEchoCancelGain)) echoDelayMs=\(String(format: "%.1f", lastEchoDelayMs)) presence=\(String(format: "%.2f", lastPresenceMix)) combined=\(String(format: "%.4f", combinedGain)) route=\(routeStr(session.currentRoute))")
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

    let useEqForThisRoute = eqEnabled && a2dpFlag

    if useEqForThisRoute {
      for i in 0..<n {
        var x = Double(ch0[i])

        if false, isSpeakerDefaultNow, let er = echoReducer {
          x = er.processMic(x, speechActive: speechActive, startupGrace: inStartupGrace)
          lastEchoCancelGain = er.currentCancelGain()
          lastEchoDelayMs = er.currentDelayMs()
        }

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

            if let ps = presenceSmoother {
              x = ps.process(x, speechActive: speechActive)
              lastPresenceMix = ps.currentMix()
            }
          }

          if isSpeakerDefaultNow {
            x = expander?.process(x) ?? x
          } else {
            x = gateBypass ? (x * 0.20) : (gate?.process(x) ?? x)
          }

          x = afs?.process(x) ?? x
        }

        if duckNow { x *= isSpeakerDefaultNow ? 0.68 : 0.82 }

        x *= combinedGain

        if a2dpFlag || isSpeakerDefaultNow {
          x = comp?.process(x) ?? x
        }

        x = limiter?.process(x) ?? x
        x = softClip(x)

        if isSpeakerDefaultNow && rawRms < 0.006 && abs(x) < 0.010 {
          x = 0.0
        }

        if isSpeakerDefaultNow {
          x = popSmoother?.process(x, rawRms: rawRms, rise: rise, speechActive: speechActive) ?? x
        }

        let y = x.clamp(-1.0, 1.0)
        outData[i] = Float(y)
        sumSq += y * y

        if false, isSpeakerDefaultNow, let er = echoReducer {
          er.pushSpeakerSample(Float(y))
        }
      }
    } else {
      for i in 0..<n {
        var x = Double(ch0[i])

        if false, isSpeakerDefaultNow, let er = echoReducer {
          x = er.processMic(x, speechActive: speechActive, startupGrace: inStartupGrace)
          lastEchoCancelGain = er.currentCancelGain()
          lastEchoDelayMs = er.currentDelayMs()
        }

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

            if let ps = presenceSmoother {
              x = ps.process(x, speechActive: speechActive)
              lastPresenceMix = ps.currentMix()
            }
          }

          if isSpeakerDefaultNow {
            x = expander?.process(x) ?? x
          } else {
            x = gateBypass ? (x * 0.20) : (gate?.process(x) ?? x)
          }

          x = afs?.process(x) ?? x
        }

        if duckNow { x *= isSpeakerDefaultNow ? 0.68 : 0.82 }

        x *= combinedGain

        if a2dpFlag || isSpeakerDefaultNow {
          x = comp?.process(x) ?? x
        }

        x = limiter?.process(x) ?? x
        x = softClip(x)

        if isSpeakerDefaultNow && rawRms < 0.006 && abs(x) < 0.010 {
          x = 0.0
        }

        if isSpeakerDefaultNow {
          x = popSmoother?.process(x, rawRms: rawRms, rise: rise, speechActive: speechActive) ?? x
        }

        let y = x.clamp(-1.0, 1.0)
        outData[i] = Float(y)
        sumSq += y * y

        if false, isSpeakerDefaultNow, let er = echoReducer {
          er.pushSpeakerSample(Float(y))
        }
      }
    }

    let rmsNow = sqrt(sumSq / Double(n)).clamp01()

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

    if isSpeakerDefaultNow {
      let speakerRise = rise > 0.028
      let speakerHot  = rawRms > 0.085

      if !speechActive && !inStartupGrace && (speakerHot || speakerRise) {
        duckUntilTs = now + 480.0
      }

      if let ctl = speakerGuardCtl {
        if ctl.shouldHardMute(rawRms: rawRms, rise: rise, speechActive: speechActive, startupGrace: inStartupGrace) {
          let muteSamples = min(n, max(1, Int(mono.sampleRate * 0.003)))
          for i in 0..<muteSamples { outData[i] *= 0.35 }
        }
      }

      if rawRms > SPK_PRE_DUCK_RMS && !inStartupGrace {
        duckUntilTs = max(duckUntilTs, now + min(speechActive ? 180.0 : 320.0, SPK_DUCK_MS))
      }

      if guardGain < SPK_GUARD_MIN {
        guardGain = SPK_GUARD_MIN
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

    let bb = bandGains
    lastBands = bb

    // IMPORTANT:
    // Old code converted 5 sliders to almost the same "volume" change, then capped
    // Mid/Treble/High on A2DP. That made EQ sound weak and unclear.
    // New mapping keeps 1.0 = 0dB and spreads each slider to a strong EQ dB range.
    // Flutter current range is expected around 0.25...3.0:
    //   0.25 -> -18dB
    //   1.00 ->   0dB
    //   3.00 -> +18dB
    func sliderToDb(_ vIn: Double) -> Double {
      let v = clamp(vIn, 0.25, 3.0)
      if v >= 1.0 {
        return ((v - 1.0) / 2.0) * 18.0
      } else {
        return ((v - 1.0) / 0.75) * 18.0
      }
    }

    var db = [Double](repeating: 0.0, count: 5)
    for i in 0..<5 {
      db[i] = sliderToDb(bb[i])
    }

    // EQ is only meant to color Bluetooth A2DP output.
    // Voice/HFP path keeps filters neutral to avoid telephone-quality harshness.
    if lastVoicePath {
      db = [0.0, 0.0, 0.0, 0.0, 0.0]
    }

    eq.updateGainsDb(db)
  }

  private func handleRouteChanged(reason: AVAudioSession.RouteChangeReason? = nil) {
    guard running else { return }

    let now = nowMs()
    if (now - lastRouteRestartTs) < 250.0 {
      log("⏭️[RouteChange] skip duplicate restart")
      return
    }
    lastRouteRestartTs = now

    updateRouteCache()

    let live = liveRouteFlags()

    if shouldPreferBluetoothA2DPOnRouteChange(reason: reason) {
      wantsBluetoothA2DPPlayback = true
      lastNonVoiceA2dpTargetTs = now
    } else if !live.a2dp && !live.btHfp {
      wantsBluetoothA2DPPlayback = false
    }

    hasTimeline = false
    nextPlaySampleTime = 0

    let voiceMode = lastVoiceModeRequested

    var targetSampleRate: Double = 48_000
    var targetVoicePath: Bool = false

    if voiceMode {
      if live.btHfp {
        targetSampleRate = 16_000
        targetVoicePath = true
      } else {
        targetSampleRate = SPEAKER_VOICE_SR
        targetVoicePath = true
      }
    } else {
      if wantsBluetoothA2DPPlayback {
        if live.a2dp {
          targetSampleRate = 44_100
          targetVoicePath = false
          lastNonVoiceA2dpTargetTs = now
        } else if live.btHfp {
          log("🛡️[RouteChange] transient HFP detected while targeting A2DP -> force A2DP reconfigure")
          targetSampleRate = 44_100
          targetVoicePath = false
        } else if hasAnyBluetoothOutputNow() {
          targetSampleRate = 44_100
          targetVoicePath = false
        } else if !live.wired {
          targetSampleRate = SPEAKER_VOICE_SR
          targetVoicePath = true
        } else {
          targetSampleRate = 48_000
          targetVoicePath = false
        }
      } else {
        if live.a2dp {
          targetSampleRate = 44_100
          targetVoicePath = false
        } else if live.btHfp {
          targetSampleRate = 16_000
          targetVoicePath = true
        } else if !live.wired {
          targetSampleRate = SPEAKER_VOICE_SR
          targetVoicePath = true
        } else {
          targetSampleRate = 48_000
          targetVoicePath = false
        }
      }
    }

    if targetVoicePath == lastVoicePath && targetSampleRate == lastSampleRate {
      log("✅[RouteChange] no restart needed")
      return
    }

    log("🔁[RouteChange] target voicePath=\(targetVoicePath) sr=\(targetSampleRate) wantsA2DP=\(wantsBluetoothA2DPPlayback) liveA2DP=\(live.a2dp) liveHFP=\(live.btHfp)")
    restartEngineAuto(sampleRate: targetSampleRate, voicePath: targetVoicePath)
  }

  private func restartEngineAuto(sampleRate: Double, voicePath: Bool) {
    if transitionInProgress {
      log("⏭️[Restart] skipped because transitionInProgress")
      return
    }

    if voicePath == lastVoicePath && sampleRate == lastSampleRate { return }

    let token = pendingStartToken + 1
    pendingStartToken = token
    running = false

    audioAsync { [weak self] in
      guard let self else { return }
      self.log("♻️[Restart] engine stopping for route change")
      self.engine.inputNode.removeTap(onBus: 0)
      self.player.stop()
      self.engine.stop()
      self.engine.reset()

      try? self.session.setActive(false, options: [.notifyOthersOnDeactivation])

      self.configureAndStart(sampleRate: sampleRate, voicePath: voicePath, token: token)
    }
  }

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
    let raw = n.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
    let reason = raw.flatMap { AVAudioSession.RouteChangeReason(rawValue: $0) }

    log("🔄[RouteChange] reason=\(String(describing: reason)) \(routeStr(session.currentRoute))")
    audioQueue.async { [weak self] in
      guard let self else { return }
      self.updateRouteCache()
      self.handleRouteChanged(reason: reason)
    }
  }

  @objc private func onInterruption(_ n: Notification) {
    guard let info = n.userInfo,
          let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }

    if type == .began {
      log("⛔️[Interruption] began -> stop")
      audioQueue.async { [weak self] in
        self?.stopLoopback()
      }
    } else {
      log("▶️[Interruption] ended -> restart")
      let voiceMode = lastVoiceModeRequested
      DispatchQueue.main.async { [weak self] in
        self?.startLoopback(voiceMode: voiceMode)
      }
    }
  }

  deinit { NotificationCenter.default.removeObserver(self) }

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

final class SpeakerPopSmoother {
  private var last: Double = 0.0
  private var gain: Double = 1.0

  private let maxStepNormal: Double = 0.030
  private let maxStepHot: Double = 0.018

  func reset() {
    last = 0.0
    gain = 1.0
  }

  @inline(__always)
  func process(_ xIn: Double, rawRms: Double, rise: Double, speechActive: Bool) -> Double {
    var x = xIn

    let hot = rawRms > 0.14 || abs(rise) > 0.055
    let maxStep = hot ? maxStepHot : maxStepNormal

    let d = x - last
    if d > maxStep {
      x = last + maxStep
    } else if d < -maxStep {
      x = last - maxStep
    }

    let targetGain: Double
    if hot {
      targetGain = speechActive ? 0.86 : 0.72
    } else {
      targetGain = 1.0
    }

    let k = targetGain < gain ? 0.22 : 0.035
    gain += (targetGain - gain) * k

    let y = x * gain
    last = y
    return y
  }
}

fileprivate extension Double {
  func clamp(_ lo: Double, _ hi: Double) -> Double { min(hi, max(lo, self)) }
  func clamp01() -> Double { min(1.0, max(0.0, self)) }
}