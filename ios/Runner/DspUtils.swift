import Foundation

// MARK: - softClipCubic (Swift port of softClipCubic in DspUtils.kt)

@inline(__always)
func softClipCubic(_ xIn: Double) -> Double {
    if !xIn.isFinite { return 0.0 }

    var x = xIn
    if x > 2.5 { x = 2.5 }
    if x < -2.5 { x = -2.5 }

    let y = x - (x * x * x) / 3.0
    return min(1.0, max(-1.0, y))
}

// MARK: - OnePoleHpf (Swift port of OnePoleHpf in DspUtils.kt)

final class OnePoleHpf {
    private var a: Double = 0.0
    private var x1: Double = 0.0
    private var y1: Double = 0.0

    init(fs: Double, fc: Double) {
        set(fs: fs, fc: fc)
    }

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

// MARK: - SimpleCompressor (Swift port of SimpleCompressor in DspUtils.kt)

final class SimpleCompressor {
    private let thr: Double
    private let rat: Double
    private let atk: Double
    private let rel: Double

    private var env: Double = 0.0

    init(sampleRate: Double, threshold: Double, ratio: Double, attackMs: Double, releaseMs: Double) {
        // Kotlin: threshold.coerceIn(1e-6, 0.99)
        self.thr = min(0.99, max(1e-6, threshold))
        // Kotlin: ratio.coerceAtLeast(1.0)
        self.rat = max(1.0, ratio)

        // Kotlin:
        // atk = exp(-1.0 / (sampleRate * (attackMs/1000)).coerceAtLeast(1e-6))
        // rel = exp(-1.0 / (sampleRate * (releaseMs/1000)).coerceAtLeast(1e-6))
        let atkDen = max(1e-6, sampleRate * (attackMs / 1000.0))
        let relDen = max(1e-6, sampleRate * (releaseMs / 1000.0))
        self.atk = exp(-1.0 / atkDen)
        self.rel = exp(-1.0 / relDen)
    }

    @inline(__always)
    func process(_ xIn: Double) -> Double {
        var x = xIn
        let a = abs(x)

        if a > env {
            env = atk * env + (1.0 - atk) * a
        } else {
            env = rel * env + (1.0 - rel) * a
        }

        if env <= thr { return x }

        let over = env / thr
        let gain = pow(over, (1.0 / rat) - 1.0)
        x *= gain
        return x
    }

    func reset() {
        env = 0.0
    }
}
