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
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()

    // ===== State / Queue =====
    private let audioQueue = DispatchQueue(label: "loopback.audio.queue", qos: .userInteractive)
    private var running: Bool = false
    private var pendingStartToken: Int = 0

    // ===== Event sink =====
    private var eventSink: FlutterEventSink?

    // ===== Params from Flutter =====
    private var eqEnabled: Bool = true
    private var outputGain: Double = 1.0
    private var bandGains: [Double] = [1, 1, 1, 1, 1]
    private var masterBoost: Double = 1.0

    // ===== INPUT SELECT (best-effort on iOS) =====
    private var preferWiredMic: Bool = false
    private var headsetMicBoost: Double = 3.0

    // ===== Last route mode =====
    private var lastVoiceModeRequested: Bool = false
    private var lastVoicePath: Bool = false
    private var lastSampleRate: Double = 48_000

    // ================== Anti-feedback tuning for A2DP ==================
    private let A2DP_SAFE_GAIN_CAP: Double = 0.55
    private let FEEDBACK_RMS_THRESHOLD: Double = 0.22
    private let FEEDBACK_RISE_THRESHOLD: Double = 0.05
    private let GUARD_MIN: Double = 0.03

    private let A2DP_MUTE_MS: Double = 40.0
    private let A2DP_HARD_MUTE_RMS: Double = 0.55

    // ================== Speaker default voice SR ==================
    private let SPEAKER_VOICE_SR: Double = 48_000

    // ================== A2DP "mixer style" controls ==================
    private let A2DP_HPF_HZ: Double = 220.0

    private let A2DP_AFS_ANALYZE_MS: Double = 100.0
    private let A2DP_DUCK_MS: Double = 450.0
    private let A2DP_EARLY_MUTE_RMS: Double = 0.30
    private let A2DP_EARLY_MUTE_RISE: Double = 0.08

    private let A2DP_LPF_HZ: Double = 8500.0
    private let A2DP_GATE_THR: Double = 0.030
    private let A2DP_GATE_ATTACK_MS: Double = 6.0
    private let A2DP_GATE_RELEASE_MS: Double = 140.0

    // ===== DSP =====
    private var eq: Eq5Band?
    private var hpf: OnePoleHpf?
    private var a2dpLpf: OnePoleLpf?
    private var gate: SimpleGate?
    private var afs: AntiFeedbackAfs?
    private var comp: SimpleCompressor?
    private var limiter: SimpleLimiter?

    // ===== Runtime variables =====
    private var a2dpFlag: Bool = false
    private var lastA2dpCheckTs: Double = 0.0
    private var duckUntilTs: Double = 0.0
    private var lastAnalyzeTs: Double = 0.0

    private var guardGain: Double = 1.0
    private var lastRms: Double = 0.0
    private var lastGuardLogTs: Double = 0.0

    // ===== Meter throttle =====
    private var lastMeterTs: Double = 0.0

    // ===== Cached audio format used for output scheduling =====
    private var monoFormat: AVAudioFormat?

    // MARK: FlutterPlugin register
    public static func register(with registrar: FlutterPluginRegistrar) {
        let inst = LoopbackPlugin()

        let ch = FlutterMethodChannel(name: CHANNEL, binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(inst, channel: ch)

        let ev = FlutterEventChannel(name: EVENTS, binaryMessenger: registrar.messenger())
        ev.setStreamHandler(inst)

        inst.installNotifications()
    }

    // MARK: Stream handler
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    // MARK: Method handler
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
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

            preferWiredMic = v
            headsetMicBoost = clamp(boost, 1.0, 6.0)

            if running { handleRouteChanged() }
            result(nil)

        case "isWiredPresent":
            result(isWiredPresent())

        case "isBtHeadsetPresent":
            result(isBtHeadsetWithMicConnected())

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: Start/Stop
    private func startLoopback(voiceMode: Bool) {
        stopLoopback()
        pendingStartToken += 1
        lastVoiceModeRequested = voiceMode

        // iOS: voiceMode=true but no BT mic -> fallback
        if voiceMode && !isBtHeadsetWithMicConnected() {
            startLoopback(voiceMode: false)
            return
        }

        let a2dp = isA2dpOutputActive()
        let wired = isWiredPresent()

        if voiceMode {
            configureAndStart(sampleRate: 16_000, voicePath: true, token: pendingStartToken)
            return
        }

        if a2dp {
            configureAndStart(sampleRate: 48_000, voicePath: false, token: pendingStartToken)
            return
        }

        if isBtHeadsetWithMicConnected() {
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

        audioQueue.sync {
            self.engine.inputNode.removeTap(onBus: 0)
            self.player.stop()
            self.engine.stop()
            self.engine.reset()
        }

        // reset DSP/state
        guardGain = 1.0
        lastRms = 0.0
        duckUntilTs = 0.0
        lastAnalyzeTs = 0.0
        lastA2dpCheckTs = 0.0
        lastMeterTs = 0.0
        lastGuardLogTs = 0.0

        eq = nil
        hpf = nil
        a2dpLpf = nil
        gate = nil
        afs = nil
        comp = nil
        limiter = nil
        monoFormat = nil

        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
    }

    // MARK: Engine setup
    private func configureAndStart(sampleRate: Double, voicePath: Bool, token: Int) {
        guard token == pendingStartToken else { return }

        lastVoicePath = voicePath
        lastSampleRate = sampleRate

        // Update flags
        a2dpFlag = (!voicePath) && isA2dpOutputActive() && !isWiredPresent()

        do {
            try configureSession(voicePath: voicePath, sampleRate: sampleRate)
        } catch {
            try? configureSession(voicePath: false, sampleRate: 48_000)
        }

        audioQueue.async { [weak self] in
            guard let self else { return }
            guard token == self.pendingStartToken else { return }

            if !self.engine.attachedNodes.contains(self.player) {
                self.engine.attach(self.player)
            }

            let input = self.engine.inputNode
            let inputFormat = input.outputFormat(forBus: 0)
            let fs = inputFormat.sampleRate

            // mono float32 format used for processing & playback
            let mono = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                     sampleRate: fs,
                                     channels: 1,
                                     interleaved: false)!
            self.monoFormat = mono

            self.engine.connect(self.player, to: self.engine.mainMixerNode, format: mono)

            self.buildDsp(sampleRate: fs)

            input.removeTap(onBus: 0)

            // ~10ms tap (like Android chunk-ish). Keep safe bounds.
            let tapFrames = AVAudioFrameCount(max(128, min(1024, Int(fs / 100.0))))

            input.installTap(onBus: 0, bufferSize: tapFrames, format: inputFormat) { [weak self] buf, _ in
                self?.processTap(buffer: buf, voicePath: voicePath)
            }

            do {
                try self.engine.start()
                self.player.play()
                self.running = true
            } catch {
                self.running = false
            }
        }
    }

    private func configureSession(voicePath: Bool, sampleRate: Double) throws {
        // iOS mapping:
        // voicePath=true  -> .voiceChat (AEC best-effort)
        // voicePath=false -> .default + allow A2DP
        var options: AVAudioSession.CategoryOptions = [.defaultToSpeaker, .allowBluetooth]
        if !voicePath { options.insert(.allowBluetoothA2DP) }

        try session.setCategory(.playAndRecord,
                                mode: voicePath ? .voiceChat : .default,
                                options: options)
        try session.setPreferredSampleRate(sampleRate)
        try session.setPreferredIOBufferDuration(0.01) // ~10ms
        try session.setActive(true, options: [])
    }

    private func buildDsp(sampleRate fs: Double) {
        eq = Eq5Band(fs: fs)
        hpf = OnePoleHpf(fs: fs, fc: A2DP_HPF_HZ)
        a2dpLpf = OnePoleLpf(fs: fs, fc: A2DP_LPF_HZ)
        gate = SimpleGate(sampleRate: fs,
                          threshold: A2DP_GATE_THR,
                          attackMs: A2DP_GATE_ATTACK_MS,
                          releaseMs: A2DP_GATE_RELEASE_MS)
        afs = AntiFeedbackAfs(fs: fs)
        comp = SimpleCompressor(sampleRate: fs,
                                threshold: 0.28,
                                ratio: 2.5,
                                attackMs: 8.0,
                                releaseMs: 180.0)
        limiter = SimpleLimiter(sampleRate: fs,
                                threshold: 0.92,
                                releaseMs: 120.0)

        afs?.reset()
        limiter?.reset()

        guardGain = 1.0
        lastRms = 0.0
        duckUntilTs = 0.0
        lastAnalyzeTs = 0.0
        lastA2dpCheckTs = 0.0

        applyEqIfChanged(force: true)
    }

    // MARK: Processing loop
    private func processTap(buffer: AVAudioPCMBuffer, voicePath: Bool) {
        guard running else { return }

        // Convert whatever input channels -> mono by taking channel 0 (like Android MONO record)
        guard let ch0 = buffer.floatChannelData?[0] else { return }
        let n = Int(buffer.frameLength)
        if n <= 0 { return }

        let now = nowMs()

        // A2DP flag check (500ms)
        if (now - lastA2dpCheckTs) > 500 {
            lastA2dpCheckTs = now
            let newFlag = (!voicePath) && isA2dpOutputActive() && !isWiredPresent()
            if newFlag != a2dpFlag {
                a2dpFlag = newFlag
                guardGain = 1.0
                limiter?.reset()
                afs?.reset()
                duckUntilTs = 0.0
            }
        }

        applyEqIfChanged(force: false)

        // raw RMS for AFS decision
        var rawSumSq: Double = 0
        for i in 0..<n {
            let xf = Double(ch0[i])
            rawSumSq += xf * xf
        }
        let rawRms = sqrt(rawSumSq / Double(n)).clamp01()

        // AFS analyze
        if a2dpFlag && rawRms > 0.018 && (now - lastAnalyzeTs) >= A2DP_AFS_ANALYZE_MS {
            lastAnalyzeTs = now
            afs?.analyzeFloat(input: ch0, count: n)
        }

        let duckNow = a2dpFlag && (now < duckUntilTs)

        // Gains
        let gRaw = outputGain
        let mBoost = masterBoost

        let isSpeakerDefaultNow = voicePath && !isWiredPresent() && !isA2dpOutputActive() && !a2dpFlag
        let speakerDefaultBoost = (isSpeakerDefaultNow && !a2dpFlag) ? 1.35 : 1.0

        // iOS can't truly force mic device from app code; keep knob best-effort
        let micBoost = (preferWiredMic ? headsetMicBoost : 1.0)

        let gCap = a2dpFlag ? min(gRaw, A2DP_SAFE_GAIN_CAP) : gRaw
        let combinedGain = (gCap * mBoost * speakerDefaultBoost) * guardGain * micBoost

        guard let mono = monoFormat else { return }
        let outBuf = AVAudioPCMBuffer(pcmFormat: mono, frameCapacity: AVAudioFrameCount(n))!
        outBuf.frameLength = AVAudioFrameCount(n)
        guard let outData = outBuf.floatChannelData?[0] else { return }

        var sumSq: Double = 0

        if eqEnabled {
            for i in 0..<n {
                var x = Double(ch0[i])

                x = eq?.process(x) ?? x
                if !x.isFinite { x = 0 }

                if a2dpFlag {
                    x = hpf?.process(x) ?? x
                    x = a2dpLpf?.process(x) ?? x
                    x = gate?.process(x) ?? x
                    x = afs?.process(x) ?? x
                }

                if duckNow { x *= 0.78 }

                x *= combinedGain
                if a2dpFlag { x = comp?.process(x) ?? x }

                x = limiter?.process(x) ?? x
                x = softClip(x)

                let y = x.clamp(-1.0, 1.0)
                outData[i] = Float(y)
                sumSq += y * y
            }
        } else {
            for i in 0..<n {
                var x = Double(ch0[i])

                if a2dpFlag {
                    x = hpf?.process(x) ?? x
                    x = a2dpLpf?.process(x) ?? x
                    x = gate?.process(x) ?? x
                    x = afs?.process(x) ?? x
                }

                if duckNow { x *= 0.78 }

                x *= combinedGain
                if a2dpFlag { x = comp?.process(x) ?? x }

                x = limiter?.process(x) ?? x
                x = softClip(x)

                let y = x.clamp(-1.0, 1.0)
                outData[i] = Float(y)
                sumSq += y * y
            }
        }

        let rmsNow = sqrt(sumSq / Double(n)).clamp01()

        if a2dpFlag {
            let risingFast = (rmsNow - lastRms) > FEEDBACK_RISE_THRESHOLD
            let tooLoud = rmsNow > FEEDBACK_RMS_THRESHOLD

            if tooLoud || risingFast { duckUntilTs = now + A2DP_DUCK_MS }

            if tooLoud || risingFast {
                guardGain *= 0.70
                if guardGain < GUARD_MIN { guardGain = GUARD_MIN }
            } else {
                guardGain += (1.0 - guardGain) * 0.001
            }

            let earlyMute = (rmsNow > A2DP_EARLY_MUTE_RMS) || ((rmsNow - lastRms) > A2DP_EARLY_MUTE_RISE)
            let hardMute = (rmsNow > A2DP_HARD_MUTE_RMS)

            if earlyMute || hardMute {
                let muteMs = hardMute ? A2DP_MUTE_MS : (A2DP_MUTE_MS / 2.0)
                let muteSamples = min(n, max(1, Int(mono.sampleRate * (muteMs / 1000.0))))
                for i in 0..<muteSamples { outData[i] = 0 }
            }

            if (now - lastGuardLogTs) > 1000 {
                lastGuardLogTs = now
                // print("A2DP guard rms=\(rmsNow) guardGain=\(guardGain) notch=\(afs?.activeCount() ?? 0)")
            }
        }

        lastRms = rmsNow

        // Send RMS event ~50ms
        if (now - lastMeterTs) > 50 {
            lastMeterTs = now
            DispatchQueue.main.async { [weak self] in
                self?.eventSink?(rmsNow)
            }
        }

        // Output
        player.scheduleBuffer(outBuf, completionHandler: nil)
    }

    // MARK: EQ refresh logic
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

        // speaker default: limit highs
        let speakerDefaultNow = lastVoicePath && !isWiredPresent() && !isA2dpOutputActive() && !a2dpFlag
        if speakerDefaultNow {
            bb[3] = min(bb[3], 1.25)
            bb[4] = min(bb[4], 1.35)
        }

        // a2dp: limit treble
        if a2dpFlag {
            bb[2] = min(bb[2], 1.05)
            bb[3] = min(bb[3], 1.10)
            bb[4] = min(bb[4], 1.10)
        }

        lastBands = bb

        // linear -> dB
        var db = [Double](repeating: 0, count: 5)
        for i in 0..<5 {
            let gi = max(0.0001, bb[i])
            db[i] = 20.0 * log10(gi)
        }

        // ✅ call signature đúng
        eq.updateGainsDb(db)
    }

    // MARK: Route change
    private func handleRouteChanged() {
        guard running else { return }

        let voiceMode = lastVoiceModeRequested
        let a2dp = isA2dpOutputActive()
        let wired = isWiredPresent()

        var targetSampleRate: Double = 48_000
        var targetVoicePath: Bool = false

        if voiceMode {
            if isBtHeadsetWithMicConnected() {
                targetSampleRate = 16_000
                targetVoicePath = true
            } else {
                targetSampleRate = SPEAKER_VOICE_SR
                targetVoicePath = true
            }
        } else {
            if a2dp {
                targetSampleRate = 48_000
                targetVoicePath = false
            } else if isBtHeadsetWithMicConnected() {
                targetSampleRate = 16_000
                targetVoicePath = true
            } else if !wired {
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

        audioQueue.sync {
            self.engine.inputNode.removeTap(onBus: 0)
            self.player.stop()
            self.engine.stop()
            self.engine.reset()
        }

        configureAndStart(sampleRate: sampleRate, voicePath: voicePath, token: token)
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
        handleRouteChanged()
    }

    @objc private func onInterruption(_ n: Notification) {
        guard let info = n.userInfo,
              let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }

        if type == .began {
            stopLoopback()
        } else {
            startLoopback(voiceMode: lastVoiceModeRequested)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: Route helpers
    private func isA2dpOutputActive() -> Bool {
        for o in session.currentRoute.outputs {
            if o.portType == .bluetoothA2DP { return true }
        }
        return false
    }

    private func isWiredPresent() -> Bool {
        let r = session.currentRoute
        for o in r.outputs {
            if o.portType == .headphones || o.portType == .headsetMic || o.portType == .usbAudio { return true }
        }
        for i in r.inputs {
            if i.portType == .headsetMic || i.portType == .usbAudio { return true }
        }
        return false
    }

    private func isBtHeadsetWithMicConnected() -> Bool {
        let r = session.currentRoute
        for i in r.inputs where i.portType == .bluetoothHFP { return true }
        return false
    }

    // MARK: Helpers
    private func softClip(_ x: Double) -> Double {
        // Kotlin stub: a=1.5; ax=a*x; return ax/(1+abs(ax))
        let a = 1.5
        let ax = a * x
        return ax / (1.0 + abs(ax))
    }

    private func nowMs() -> Double { CACurrentMediaTime() * 1000.0 }
    private func clamp(_ x: Double, _ lo: Double, _ hi: Double) -> Double { min(hi, max(lo, x)) }
}

fileprivate extension Double {
    func clamp(_ lo: Double, _ hi: Double) -> Double { min(hi, max(lo, self)) }
    func clamp01() -> Double { min(1.0, max(0.0, self)) }
}
