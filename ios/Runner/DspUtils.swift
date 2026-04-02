import Foundation

final class OnePoleHpf {
    private var a: Double = 0.0
    private var x1: Double = 0.0
    private var y1: Double = 0.0

    init(fs: Double, fc: Double) { set(fs: fs, fc: fc) }

    func set(fs: Double, fc: Double) {
        let c = tan(Double.pi * fc / fs)
        a = (1.0 - c) / (1.0 + c)
        x1 = 0.0
        y1 = 0.0
    }

    @inline(__always)
    func process(_ x: Double) -> Double {
        let y = a * (y1 + x - x1)
        x1 = x
        y1 = y
        return y
    }

    func resetState() {
        x1 = 0.0
        y1 = 0.0
    }
}

// MARK: - OnePoleLPF
final class OnePoleLpf {
    private var a: Double = 0.0
    private var y1: Double = 0.0

    init(fs: Double, fc: Double) { set(fs: fs, fc: fc) }

    func set(fs: Double, fc: Double) {
        let c = tan(Double.pi * fc / fs)
        a = c / (1.0 + c)
        y1 = 0.0
    }

    @inline(__always)
    func process(_ x: Double) -> Double {
        let y = y1 + a * (x - y1)
        y1 = y
        return y
    }

    func resetState() {
        y1 = 0.0
    }
}

// MARK: - SimpleGate
final class SimpleGate {
    private let thr: Double
    private let atk: Double
    private let rel: Double
    private let floorGain: Double
    private let smooth: Double

    private var env: Double = 0.0
    private var g: Double = 0.0

    init(sampleRate: Double,
         threshold: Double,
         attackMs: Double,
         releaseMs: Double,
         floorGain: Double = 0.03,
         smooth: Double = 0.02) {
        thr = min(0.5, max(1e-6, threshold))
        let atkDen = max(1e-6, sampleRate * (attackMs / 1000.0))
        let relDen = max(1e-6, sampleRate * (releaseMs / 1000.0))
        atk = exp(-1.0 / atkDen)
        rel = exp(-1.0 / relDen)
        self.floorGain = min(0.99, max(0.0, floorGain))
        self.smooth = min(1.0, max(0.0005, smooth))
    }

    @inline(__always)
    func process(_ x: Double) -> Double {
        let a = abs(x)
        env = (a > env) ? (atk * env + (1.0 - atk) * a) : (rel * env + (1.0 - rel) * a)

        let target = (env >= thr) ? 1.0 : floorGain
        g += (target - g) * smooth
        return x * g
    }

    func reset() {
        env = 0.0
        g = 0.0
    }
}

// MARK: - DownwardExpander
final class DownwardExpander {
    private let thr: Double
    private let ratio: Double
    private let atk: Double
    private let rel: Double
    private let floorGain: Double

    private var env: Double = 0.0
    private var g: Double = 1.0

    init(sampleRate: Double,
         threshold: Double,
         ratio: Double = 2.5,
         attackMs: Double = 8.0,
         releaseMs: Double = 180.0,
         floorGain: Double = 0.22) {
        self.thr = max(1e-6, threshold)
        self.ratio = max(1.0, ratio)

        let atkDen = max(1e-6, sampleRate * (attackMs / 1000.0))
        let relDen = max(1e-6, sampleRate * (releaseMs / 1000.0))
        self.atk = exp(-1.0 / atkDen)
        self.rel = exp(-1.0 / relDen)

        self.floorGain = min(1.0, max(0.0, floorGain))
    }

    @inline(__always)
    func process(_ x: Double) -> Double {
        let a = abs(x)
        env = (a > env)
            ? (atk * env + (1.0 - atk) * a)
            : (rel * env + (1.0 - rel) * a)

        var targetGain = 1.0

        if env < thr {
            let normalized = env / thr
            let shaped = pow(normalized, (ratio - 1.0) / ratio)
            targetGain = floorGain + (1.0 - floorGain) * shaped
        }

        g += (targetGain - g) * 0.02
        return x * g
    }

    func reset() {
        env = 0.0
        g = 1.0
    }
}

// MARK: - SimpleCompressor
final class SimpleCompressor {
    private let thr: Double
    private let rat: Double
    private let atk: Double
    private let rel: Double
    private var env: Double = 0.0

    init(sampleRate: Double, threshold: Double, ratio: Double, attackMs: Double, releaseMs: Double) {
        thr = min(0.99, max(1e-6, threshold))
        rat = max(1.0, ratio)

        let atkDen = max(1e-6, sampleRate * (attackMs / 1000.0))
        let relDen = max(1e-6, sampleRate * (releaseMs / 1000.0))
        atk = exp(-1.0 / atkDen)
        rel = exp(-1.0 / relDen)
    }

    @inline(__always)
    func process(_ xIn: Double) -> Double {
        var x = xIn
        let a = abs(x)

        env = (a > env) ? (atk * env + (1.0 - atk) * a) : (rel * env + (1.0 - rel) * a)

        if env <= thr { return x }

        let over = env / thr
        let gain = pow(over, (1.0 / rat) - 1.0)
        x *= gain
        return x
    }

    func reset() { env = 0.0 }
}

// MARK: - SimpleLimiter
final class SimpleLimiter {
    private let sr: Double
    private let thr: Double
    private let atk: Double
    private let rel: Double
    private var g: Double = 1.0

    init(sampleRate: Double, threshold: Double = 0.92, attackMs: Double = 1.0, releaseMs: Double = 120.0) {
        self.sr = max(8000.0, sampleRate)
        self.thr = min(0.99, max(0.2, threshold))

        let atkDen = max(1e-6, self.sr * (attackMs / 1000.0))
        let relDen = max(1e-6, self.sr * (releaseMs / 1000.0))
        self.atk = exp(-1.0 / atkDen)
        self.rel = exp(-1.0 / relDen)
    }

    func reset() { g = 1.0 }

    @inline(__always)
    func process(_ xIn: Double) -> Double {
        let ax = abs(xIn)
        let desired = (ax <= thr) ? 1.0 : (thr / (ax + 1e-12))

        if desired < g {
            g = atk * g + (1.0 - atk) * desired
        } else {
            g = rel * g + (1.0 - rel) * desired
        }
        return xIn * g
    }
}

// MARK: - SpeechPresenceTracker
final class SpeechPresenceTracker {
    private let attack: Double
    private let release: Double
    private let rmsOn: Double
    private let rmsOff: Double
    private let zcrMin: Double
    private let zcrMax: Double
    private let hangMs: Double

    private var score: Double = 0.0
    private var activeUntilMs: Double = 0.0

    init(sampleRate: Double,
         rmsOn: Double = 0.014,
         rmsOff: Double = 0.008,
         zcrMin: Double = 0.008,
         zcrMax: Double = 0.30,
         attackMs: Double = 12.0,
         releaseMs: Double = 220.0,
         hangMs: Double = 320.0) {
        let atkDen = max(1e-6, sampleRate * (attackMs / 1000.0))
        let relDen = max(1e-6, sampleRate * (releaseMs / 1000.0))
        self.attack = exp(-1.0 / atkDen)
        self.release = exp(-1.0 / relDen)
        self.rmsOn = rmsOn
        self.rmsOff = rmsOff
        self.zcrMin = zcrMin
        self.zcrMax = zcrMax
        self.hangMs = hangMs
    }

    func reset() {
        score = 0.0
        activeUntilMs = 0.0
    }

    func analyze(buf: UnsafePointer<Float>, count n: Int, nowMs: Double) -> (active: Bool, rms: Double, zcr: Double, score: Double) {
        guard n > 1 else { return (false, 0.0, 0.0, score) }

        var sumSq = 0.0
        var zc = 0
        var prev = Double(buf[0])

        for i in 0..<n {
            let x = Double(buf[i])
            sumSq += x * x
            if i > 0 {
                if (prev >= 0.0 && x < 0.0) || (prev < 0.0 && x >= 0.0) {
                    zc += 1
                }
            }
            prev = x
        }

        let rms = sqrt(sumSq / Double(n))
        let zcr = Double(zc) / Double(n)

        let strongSpeech = (rms >= rmsOn && zcr >= zcrMin && zcr <= zcrMax)
        let weakSpeech = (rms >= rmsOff && zcr >= zcrMin * 0.6 && zcr <= zcrMax * 1.25)
        let voicedLike = (rms >= 0.060 && zcr <= 0.08)

        let target: Double
        if strongSpeech {
            target = 1.0
        } else if voicedLike {
            target = 0.82
        } else if weakSpeech {
            target = 0.58
        } else {
            target = 0.0
        }

        let k = (target > score) ? (1.0 - attack) : (1.0 - release)
        score += (target - score) * k

        if score > 0.50 {
            activeUntilMs = nowMs + hangMs
        }

        let active = nowMs < activeUntilMs || score > 0.52
        return (active, rms, zcr, score)
    }
}

// MARK: - SpeakerFeedbackController
final class SpeakerFeedbackController {
    private(set) var guardGain: Double = 1.0
    private(set) var preDuckGain: Double = 1.0
    private(set) var monitorGain: Double = 1.0
    private(set) var duckUntilMs: Double = 0.0

    private let guardMinSpeech: Double
    private let guardMinNonSpeech: Double
    private let hotRms: Double
    private let riseThr: Double

    init(guardMinSpeech: Double = 0.42,
         guardMinNonSpeech: Double = 0.28,
         hotRms: Double = 0.11,
         riseThr: Double = 0.020) {
        self.guardMinSpeech = guardMinSpeech
        self.guardMinNonSpeech = guardMinNonSpeech
        self.hotRms = hotRms
        self.riseThr = riseThr
    }

    func reset() {
        guardGain = 1.0
        preDuckGain = 1.0
        monitorGain = 1.0
        duckUntilMs = 0.0
    }

    func update(rawRms: Double, rise: Double, speechActive: Bool, nowMs: Double, startupGrace: Bool) {
        let hot = rawRms > hotRms
        let rising = rise > riseThr
        let veryHot = rawRms > (hotRms * 1.55)

        if startupGrace {
            let targetMonitor = rawRms > 0.030 ? 0.78 : 0.92
            let targetPreDuck = rawRms > 0.060 ? 0.84 : 0.94

            monitorGain += (targetMonitor - monitorGain) * 0.18
            preDuckGain += (targetPreDuck - preDuckGain) * 0.18
            guardGain += (0.72 - guardGain) * 0.10
            guardGain = min(guardGain, 0.80)
            return
        }

        if speechActive {
            let targetMonitor = rawRms > 0.028 ? 0.72 : 0.88
            let targetPreDuck = rawRms > 0.060 ? 0.82 : 0.92

            monitorGain += (targetMonitor - monitorGain) * (targetMonitor < monitorGain ? 0.16 : 0.05)
            preDuckGain += (targetPreDuck - preDuckGain) * (targetPreDuck < preDuckGain ? 0.18 : 0.05)

            if veryHot && rising {
                duckUntilMs = nowMs + 350.0
                guardGain *= 0.72
            } else if hot && rising {
                duckUntilMs = nowMs + 250.0
                guardGain *= 0.80
            } else if hot {
                guardGain *= 0.88
            } else {
                guardGain += (0.94 - guardGain) * 0.032
            }

            if guardGain < guardMinSpeech { guardGain = guardMinSpeech }
        } else {
            let targetMonitor = rawRms > 0.020 ? 0.62 : 0.86
            let targetPreDuck = rawRms > 0.045 ? 0.72 : 0.90

            monitorGain += (targetMonitor - monitorGain) * (targetMonitor < monitorGain ? 0.18 : 0.05)
            preDuckGain += (targetPreDuck - preDuckGain) * (targetPreDuck < preDuckGain ? 0.22 : 0.05)

            if veryHot && rising {
                duckUntilMs = nowMs + 480.0
                guardGain *= 0.58
            } else if hot && rising {
                duckUntilMs = nowMs + 380.0
                guardGain *= 0.66
            } else if hot {
                guardGain *= 0.78
            } else {
                guardGain += (0.90 - guardGain) * 0.022
            }

            if guardGain < guardMinNonSpeech { guardGain = guardMinNonSpeech }
        }
    }

    func shouldHardMute(rawRms: Double, rise: Double, speechActive: Bool, startupGrace: Bool) -> Bool {
        if startupGrace { return false }
        return (!speechActive && (rawRms > 0.24 || rise > 0.07)) || rawRms > 0.34
    }
}

// MARK: - CircularFloatDelayBuffer
final class CircularFloatDelayBuffer {
    private var buf: [Float]
    private var writeIndex: Int = 0
    private(set) var capacity: Int

    init(capacity: Int) {
        self.capacity = max(2048, capacity)
        self.buf = Array(repeating: 0, count: self.capacity)
    }

    func reset() {
        for i in 0..<buf.count { buf[i] = 0 }
        writeIndex = 0
    }

    func write(_ x: Float) {
        buf[writeIndex] = x
        writeIndex += 1
        if writeIndex >= capacity { writeIndex = 0 }
    }

    @inline(__always)
    func read(delaySamples: Int) -> Float {
        let d = max(0, min(delaySamples, capacity - 1))
        var idx = writeIndex - 1 - d
        if idx < 0 { idx += capacity }
        return buf[idx]
    }
}

// MARK: - AdaptiveEchoReducer
final class AdaptiveEchoReducer {
    private let sampleRate: Double
    private let ref: CircularFloatDelayBuffer

    private let candidateDelays: [Int]
    private var corrEma: [Double]
    private var refEma: [Double]
    private var micEma: Double = 1e-6

    private var gainFast: Double = 0.0
    private var gainSlow: Double = 0.0
    private var chosenDelay: Int = 0
    private var holdSamples: Int = 0
    private var sampleCounter: Int = 0

    init(sampleRate: Double) {
        self.sampleRate = sampleRate

        let cap = Int(sampleRate * 0.20)
        self.ref = CircularFloatDelayBuffer(capacity: cap)

        let msCandidates: [Double] = [10, 14, 18, 22, 28, 34, 42, 52, 64, 80, 100, 128]
        self.candidateDelays = msCandidates.map { Int(sampleRate * ($0 / 1000.0)) }
        self.corrEma = Array(repeating: 1e-6, count: msCandidates.count)
        self.refEma = Array(repeating: 1e-6, count: msCandidates.count)
        self.chosenDelay = self.candidateDelays.first ?? 0
    }

    func reset() {
        ref.reset()
        for i in 0..<corrEma.count {
            corrEma[i] = 1e-6
            refEma[i] = 1e-6
        }
        micEma = 1e-6
        gainFast = 0.0
        gainSlow = 0.0
        chosenDelay = candidateDelays.first ?? 0
        holdSamples = 0
        sampleCounter = 0
    }

    func pushSpeakerSample(_ x: Float) {
        ref.write(x)
    }

    @inline(__always)
    func processMic(_ xIn: Double, speechActive: Bool, startupGrace: Bool) -> Double {
        var x = xIn
        let absMic = abs(x)
        micEma = 0.992 * micEma + 0.008 * max(absMic, 1e-6)

        if absMic > 0.003 {
            for i in 0..<candidateDelays.count {
                let r = Double(ref.read(delaySamples: candidateDelays[i]))
                let absRef = abs(r)
                corrEma[i] = 0.988 * corrEma[i] + 0.012 * abs(x * r)
                refEma[i] = 0.992 * refEma[i] + 0.008 * max(absRef, 1e-6)
            }
        }

        sampleCounter += 1
        if holdSamples > 0 { holdSamples -= 1 }

        if sampleCounter >= 64 {
            sampleCounter = 0

            var bestIdx = 0
            var bestScore = -1.0
            for i in 0..<candidateDelays.count {
                let score = corrEma[i] / sqrt((refEma[i] * micEma) + 1e-9)
                if score > bestScore {
                    bestScore = score
                    bestIdx = i
                }
            }

            if bestScore > 0.14 || holdSamples <= 0 {
                chosenDelay = candidateDelays[bestIdx]
                holdSamples = Int(sampleRate * 0.012)
            }
        }

        let r = Double(ref.read(delaySamples: chosenDelay))
        let absRef = abs(r)

        let corr = abs(x * r) / sqrt((absRef * absMic) + 1e-9)

        let target: Double
        if startupGrace {
            target = min(0.36, absRef * 0.55)
        } else if speechActive {
            target = min(0.42, absRef * 0.50 + corr * 0.12)
        } else {
            target = min(0.60, absRef * 0.70 + corr * 0.16)
        }

        let up = target > gainFast ? 0.12 : 0.02
        gainFast += (target - gainFast) * up
        gainSlow += (gainFast - gainSlow) * 0.04

        let cancelGain = speechActive ? min(gainSlow, 0.45) : min(gainSlow, 0.65)

        x = x - cancelGain * r

        if !speechActive && absRef > 0.030 {
            let residual = abs(x)
            if residual < absRef * 0.70 {
                x *= 0.65
            }
        }

        return x
    }

    func currentCancelGain() -> Double { gainSlow }
    func currentDelayMs() -> Double { Double(chosenDelay) * 1000.0 / sampleRate }
}

// MARK: - PresenceSmoother
final class PresenceSmoother {
    private let cut1 = Biquad()
    private let cut2 = Biquad()
    private let cut3 = Biquad()

    private var envFast: Double = 0.0
    private var envSlow: Double = 0.0
    private var mix: Double = 0.0

    private let atkFast: Double
    private let relFast: Double
    private let atkSlow: Double
    private let relSlow: Double

    init(sampleRate fs: Double) {
        cut1.setPeaking(fs: fs, f0: 2100.0, q: 1.1, gainDb: -3.2)
        cut2.setPeaking(fs: fs, f0: 3100.0, q: 1.3, gainDb: -6.8)
        cut3.setPeaking(fs: fs, f0: 4300.0, q: 1.1, gainDb: -4.4)

        atkFast = exp(-1.0 / max(1.0, fs * 0.002))
        relFast = exp(-1.0 / max(1.0, fs * 0.030))
        atkSlow = exp(-1.0 / max(1.0, fs * 0.010))
        relSlow = exp(-1.0 / max(1.0, fs * 0.160))
    }

    func reset() {
        envFast = 0.0
        envSlow = 0.0
        mix = 0.0
        cut1.resetState()
        cut2.resetState()
        cut3.resetState()
    }

    @inline(__always)
    func process(_ x: Double, speechActive: Bool) -> Double {
        let ax = abs(x)

        envFast = (ax > envFast)
            ? (atkFast * envFast + (1.0 - atkFast) * ax)
            : (relFast * envFast + (1.0 - relFast) * ax)

        envSlow = (ax > envSlow)
            ? (atkSlow * envSlow + (1.0 - atkSlow) * ax)
            : (relSlow * envSlow + (1.0 - relSlow) * ax)

        let delta = max(0.0, envFast - envSlow)

        let target: Double
        if speechActive {
            if delta > 0.050 {
                target = 0.66
            } else if delta > 0.028 {
                target = 0.44
            } else {
                target = 0.14
            }
        } else {
            if delta > 0.040 {
                target = 0.58
            } else if delta > 0.020 {
                target = 0.32
            } else {
                target = 0.08
            }
        }

        mix += (target - mix) * (target > mix ? 0.16 : 0.05)

        var y = x
        y = cut1.process(y)
        y = cut2.process(y)
        y = cut3.process(y)

        return x * (1.0 - mix) + y * mix
    }

    func currentMix() -> Double { mix }
}