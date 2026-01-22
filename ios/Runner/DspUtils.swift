import Foundation

// MARK: - softClipCubic (optional helper)
@inline(__always)
func softClipCubic(_ xIn: Double) -> Double {
    if !xIn.isFinite { return 0.0 }

    var x = xIn
    if x > 2.5 { x = 2.5 }
    if x < -2.5 { x = -2.5 }

    let y = x - (x * x * x) / 3.0
    return min(1.0, max(-1.0, y))
}

// MARK: - OnePoleHPF (port of Kotlin OnePoleHpf)
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

// MARK: - OnePoleLPF (port of Kotlin OnePoleLpf)
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
}

// MARK: - SimpleGate (port of Kotlin SimpleGate)
final class SimpleGate {
    private let thr: Double
    private let atk: Double
    private let rel: Double
    private var env: Double = 0.0
    private var g: Double = 0.0

    init(sampleRate: Double, threshold: Double, attackMs: Double, releaseMs: Double) {
        thr = min(0.5, max(1e-6, threshold))
        let atkDen = max(1e-6, sampleRate * (attackMs / 1000.0))
        let relDen = max(1e-6, sampleRate * (releaseMs / 1000.0))
        atk = exp(-1.0 / atkDen)
        rel = exp(-1.0 / relDen)
    }

    @inline(__always)
    func process(_ x: Double) -> Double {
        let a = abs(x)
        env = (a > env) ? (atk * env + (1.0 - atk) * a) : (rel * env + (1.0 - rel) * a)
        let target = (env >= thr) ? 1.0 : 0.0
        g += (target - g) * 0.02
        return x * g
    }
}

// MARK: - SimpleCompressor (port of Kotlin SimpleCompressor)
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

// MARK: - SimpleLimiter (port of Kotlin SimpleLimiter)
final class SimpleLimiter {
    private let thr: Double
    private let rel: Double
    private var g: Double = 1.0

    init(sampleRate: Double, threshold: Double = 0.92, releaseMs: Double = 120.0) {
        thr = min(0.99, max(0.2, threshold))
        let relDen = max(1e-6, sampleRate * (releaseMs / 1000.0))
        rel = exp(-1.0 / relDen)
    }

    func reset() { g = 1.0 }

    @inline(__always)
    func process(_ x: Double) -> Double {
        let ax = abs(x)
        let desired = (ax <= thr || ax <= 1e-9) ? 1.0 : (thr / ax)

        if desired < g {
            g = desired
        } else {
            g = rel * g + (1.0 - rel) * desired
        }
        return x * g
    }
}
