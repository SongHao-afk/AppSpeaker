import Foundation

@inline(__always)
func softClipCubic(_ xIn: Double) -> Double {
    if !xIn.isFinite { return 0.0 }

    var x = xIn
    if x > 2.5 { x = 2.5 }
    if x < -2.5 { x = -2.5 }

    let y = x - (x * x * x) / 3.0
    return min(1.0, max(-1.0, y))
}

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

// Nới detector để bắt speech sớm hơn, nhất là voice có ZCR thấp
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
        let voicedLike = (rms >= 0.030 && zcr <= 0.08)

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

// Nới guard để tiếng to hơn, bớt cắt âm
final class SpeakerFeedbackController {
    private(set) var guardGain: Double = 1.0
    private(set) var preDuckGain: Double = 1.0
    private(set) var monitorGain: Double = 1.0
    private(set) var duckUntilMs: Double = 0.0

    private let guardMinSpeech: Double
    private let guardMinNonSpeech: Double
    private let hotRms: Double
    private let riseThr: Double

    init(guardMinSpeech: Double = 0.55,
         guardMinNonSpeech: Double = 0.42,
         hotRms: Double = 0.22,
         riseThr: Double = 0.090) {
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

        if startupGrace {
            let targetMonitor = rawRms > 0.05 ? 0.92 : 1.0
            let targetPreDuck = rawRms > 0.16 ? 0.94 : 1.0

            monitorGain += (targetMonitor - monitorGain) * 0.08
            preDuckGain += (targetPreDuck - preDuckGain) * 0.08
            guardGain += (1.0 - guardGain) * 0.05

            if guardGain < 0.80 { guardGain = 0.80 }
            return
        }

        if speechActive {
            let targetMonitor = rawRms > 0.04 ? 0.90 : 1.0
            let targetPreDuck = rawRms > 0.16 ? 0.93 : 1.0

            monitorGain += (targetMonitor - monitorGain) * (targetMonitor < monitorGain ? 0.08 : 0.03)
            preDuckGain += (targetPreDuck - preDuckGain) * (targetPreDuck < preDuckGain ? 0.09 : 0.03)

            if hot && rising {
                duckUntilMs = nowMs + 100.0
                guardGain *= 0.97
            } else if hot {
                guardGain *= 0.985
            } else {
                guardGain += (1.0 - guardGain) * 0.030
            }

            if guardGain < guardMinSpeech { guardGain = guardMinSpeech }
        } else {
            let targetMonitor = rawRms > 0.03 ? 0.84 : 1.0
            let targetPreDuck = rawRms > 0.12 ? 0.88 : 1.0

            monitorGain += (targetMonitor - monitorGain) * (targetMonitor < monitorGain ? 0.10 : 0.03)
            preDuckGain += (targetPreDuck - preDuckGain) * (targetPreDuck < preDuckGain ? 0.10 : 0.03)

            if hot && rising {
                duckUntilMs = nowMs + 240.0
                guardGain *= 0.90
            } else if hot {
                guardGain *= 0.95
            } else {
                guardGain += (1.0 - guardGain) * 0.018
            }

            if guardGain < guardMinNonSpeech { guardGain = guardMinNonSpeech }
        }
    }

    func shouldHardMute(rawRms: Double, rise: Double, speechActive: Bool, startupGrace: Bool) -> Bool {
        if startupGrace { return false }
        if speechActive { return false }
        return rawRms > 0.50 || rise > 0.18
    }

    
}