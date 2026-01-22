import Foundation

// MARK: - AntiFeedbackAfs (Swift port of AntiFeedbackAfs.kt)
// Goertzel scan on candidate freqs -> detect ringing peak -> place/refresh up to 4 notch filters.

final class AntiFeedbackAfs {

    private let fs: Double

    // candidates = [2000, 2500, 3150, 4000, 5000, 6300, 8000, 10000]
    private let candidates: [Double] = [
        2000.0, 2500.0, 3150.0, 4000.0, 5000.0, 6300.0, 8000.0, 10000.0
    ]

    // 4 notch slots
    private var notch: [Biquad] = Array(repeating: Biquad(), count: 4)
    private var notchF: [Double] = Array(repeating: 0.0, count: 4)
    private var notchUntilMs: [Int64] = Array(repeating: 0, count: 4)

    private let Q: Double = 10.0

    // EMA tracker per candidate
    private var ema: [Double]
    private let emaAlpha: Double = 0.90

    init(fs: Double) {
        self.fs = fs
        self.ema = Array(repeating: 1e-6, count: candidates.count)
        reset()
    }

    func reset() {
        for i in 0..<notch.count {
            notchF[i] = 0.0
            notchUntilMs[i] = 0
            notch[i].setNotch(fs: fs, f0: 1000.0, q: Q)
        }
        for k in 0..<ema.count {
            ema[k] = 1e-6
        }
    }

    func activeCount() -> Int {
        let now = Self.nowMs()
        var c = 0
        for i in 0..<notch.count {
            if notchF[i] > 0.0 && now < notchUntilMs[i] { c += 1 }
        }
        return c
    }

    /// Analyze a PCM16 buffer (mono) with n samples.
    /// - Parameters:
    ///   - buf: samples in Int16 (equiv ShortArray)
    ///   - n: number of valid samples
    func analyze(buf: UnsafePointer<Int16>, n: Int) {
        let now = Self.nowMs()

        // energies per candidate
        var e = Array(repeating: 0.0, count: candidates.count)

        for k in 0..<candidates.count {
            let energy = goertzelEnergy(buf: buf, n: n, freq: candidates[k], fs: fs)
            e[k] = energy
            let clamped = max(energy, 1e-9)
            ema[k] = emaAlpha * ema[k] + (1.0 - emaAlpha) * clamped
        }

        // pick best normalized peak: score = e[k] / (ema[k] + 1e-9)
        var bestK = -1
        var bestScore = 0.0
        for k in 0..<candidates.count {
            let score = e[k] / (ema[k] + 1e-9)
            if score > bestScore {
                bestScore = score
                bestK = k
            }
        }

        // FIX #1: reject noise/room tone
        if bestK < 0 { return }
        if bestScore < 10.0 { return }   // threshold raised from 6.0
        if e[bestK] < 5e-6 { return }    // energy floor

        let f0 = candidates[bestK]

        // refresh existing notch if close (abs diff < 120Hz) and still active
        for i in 0..<notch.count {
            if notchF[i] > 0.0,
               abs(notchF[i] - f0) < 120.0,
               now < notchUntilMs[i] {
                // FIX #2: shorter hold (700ms instead of 1200ms)
                notchUntilMs[i] = now + 700
                return
            }
        }

        // find free slot (expired); else reuse slot 0
        var slot = -1
        for i in 0..<notch.count {
            if now >= notchUntilMs[i] {
                slot = i
                break
            }
        }
        if slot < 0 { slot = 0 }

        notchF[slot] = f0
        notch[slot].setNotch(fs: fs, f0: f0, q: Q)
        notchUntilMs[slot] = now + 700
    }

    /// Convenience overload using Swift array
    func analyze(samples: [Int16], n: Int? = nil) {
        let count = min(n ?? samples.count, samples.count)
        samples.withUnsafeBufferPointer { ptr in
            guard let base = ptr.baseAddress else { return }
            analyze(buf: base, n: count)
        }
    }

    func process(_ xIn: Double) -> Double {
        var x = xIn
        let now = Self.nowMs()
        for i in 0..<notch.count {
            if notchF[i] > 0.0 && now < notchUntilMs[i] {
                x = notch[i].process(x)
            }
        }
        return x
    }

    // MARK: - Goertzel energy (same math as Kotlin)
    private func goertzelEnergy(buf: UnsafePointer<Int16>, n: Int, freq: Double, fs: Double) -> Double {
        let w = 2.0 * Double.pi * freq / fs
        let cosw = cos(w)
        let coeff = 2.0 * cosw

        var s0 = 0.0
        var s1 = 0.0
        var s2 = 0.0

        var i = 0
        while i < n {
            let x = Double(buf[i]) / 32768.0
            s0 = x + coeff * s1 - s2
            s2 = s1
            s1 = s0
            i += 1
        }

        let power = s1 * s1 + s2 * s2 - coeff * s1 * s2
        return max(power, 0.0)
    }

    // MARK: - Time helper
    private static func nowMs() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000.0)
    }
}

// MARK: - Dependency: Biquad
// This is just the API expected by AntiFeedbackAfs.
// Replace this stub with your real Biquad.swift port (the one you pasted in Kotlin).
final class Biquad {
    func process(_ x: Double) -> Double { x }
    func setNotch(fs: Double, f0: Double, q: Double) { /* implement in Biquad.swift */ }
}
