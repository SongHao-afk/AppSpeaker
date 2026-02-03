import Foundation

// MARK: - AntiFeedbackAfs (Android-aligned, 2-notch, hardened)
final class AntiFeedbackAfs {

    private let fs: Double

    // Candidate ringing freqs (same as Android)
    private let candidates: [Double] = [
        2000.0, 2500.0, 3150.0, 4000.0, 5000.0, 6300.0, 8000.0, 10000.0
    ]

    // ✅ FIX: only 2 notches (avoid boxy/roomy sound)
    private let notchCount = 2
    private var notch: [Biquad]
    private var notchF: [Double]
    private var notchUntilMs: [Int64]

    // ✅ Android value
    private let Q: Double = 8.0

    // EMA baseline
    private var ema: [Double]
    private let emaAlpha: Double = 0.90

    init(fs: Double) {
        self.fs = fs
        self.notch = Array(repeating: Biquad(), count: notchCount)
        self.notchF = Array(repeating: 0.0, count: notchCount)
        self.notchUntilMs = Array(repeating: 0, count: notchCount)
        self.ema = Array(repeating: 1e-6, count: candidates.count)
        reset()
    }

    func reset() {
        for i in 0..<notchCount {
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
        for i in 0..<notchCount {
            if notchF[i] > 0.0 && now < notchUntilMs[i] { c += 1 }
        }
        return c
    }

    // MARK: - Analyze Float32 directly (Android-like)
    func analyzeFloat(input: UnsafePointer<Float>, count n: Int) {
        let now = Self.nowMs()

        var e = Array(repeating: 0.0, count: candidates.count)

        for k in 0..<candidates.count {
            let energy = goertzelEnergyFloat(buf: input, n: n, freq: candidates[k], fs: fs)
            e[k] = energy
            ema[k] = emaAlpha * ema[k] + (1.0 - emaAlpha) * max(energy, 1e-9)
        }

        var bestK = -1
        var bestScore = 0.0
        for k in 0..<candidates.count {
            let score = e[k] / (ema[k] + 1e-9)
            if score > bestScore {
                bestScore = score
                bestK = k
            }
        }

        if bestK < 0 { return }

        // ✅ HARDEN (match Android)
        if bestScore < 14.0 { return }
        if e[bestK] < 1.2e-5 { return }

        let f0 = candidates[bestK]

        // refresh existing notch
        for i in 0..<notchCount {
            if notchF[i] > 0.0,
               abs(notchF[i] - f0) < 140.0,
               now < notchUntilMs[i] {
                notchUntilMs[i] = now + 650
                return
            }
        }

        // find free slot
        var slot = -1
        for i in 0..<notchCount {
            if now >= notchUntilMs[i] {
                slot = i
                break
            }
        }
        if slot < 0 { slot = 0 }

        notchF[slot] = f0
        notch[slot].setNotch(fs: fs, f0: f0, q: Q)
        notchUntilMs[slot] = now + 650
    }

    // MARK: - Process
    func process(_ xIn: Double) -> Double {
        var x = xIn
        let now = Self.nowMs()
        for i in 0..<notchCount {
            if notchF[i] > 0.0 && now < notchUntilMs[i] {
                x = notch[i].process(x)
            }
        }
        return x
    }

    // MARK: - Goertzel (Float)
    private func goertzelEnergyFloat(
        buf: UnsafePointer<Float>,
        n: Int,
        freq: Double,
        fs: Double
    ) -> Double {
        let w = 2.0 * Double.pi * freq / fs
        let cosw = cos(w)
        let coeff = 2.0 * cosw

        var s0 = 0.0
        var s1 = 0.0
        var s2 = 0.0

        for i in 0..<n {
            let x = Double(buf[i])
            s0 = x + coeff * s1 - s2
            s2 = s1
            s1 = s0
        }

        let power = s1 * s1 + s2 * s2 - coeff * s1 * s2
        return max(power, 0.0)
    }

    private static func nowMs() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000.0)
    }
}
