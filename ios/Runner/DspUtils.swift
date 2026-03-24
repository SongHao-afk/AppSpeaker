// DspUtils.swift
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

// MARK: - OnePoleHPF
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