import Foundation

final class Biquad {
    private var b0: Double = 1.0
    private var b1: Double = 0.0
    private var b2: Double = 0.0
    private var a1: Double = 0.0
    private var a2: Double = 0.0
    private var z1: Double = 0.0
    private var z2: Double = 0.0

    @inline(__always)
    func process(_ x: Double) -> Double {
        let y = b0 * x + z1
        z1 = b1 * x - a1 * y + z2
        z2 = b2 * x - a2 * y
        return y.isFinite ? y : 0.0
    }

    func resetState() {
        z1 = 0.0
        z2 = 0.0
    }

    private func setNorm(
        b0u: Double, b1u: Double, b2u: Double,
        a0u: Double, a1u: Double, a2u: Double
    ) {
        guard a0u.isFinite, abs(a0u) > 1e-12 else { return }
        let inv = 1.0 / a0u
        b0 = b0u * inv
        b1 = b1u * inv
        b2 = b2u * inv
        a1 = a1u * inv
        a2 = a2u * inv
    }

    func setPeaking(fs: Double, f0: Double, q: Double, gainDb: Double) {
        let safeFs = max(8000.0, fs)
        let nyq = safeFs * 0.5
        let safeF0 = min(max(20.0, f0), nyq * 0.92)
        let safeQ = max(0.20, q)
        let db = min(18.0, max(-18.0, gainDb))

        let A = pow(10.0, db / 40.0)
        let w0 = 2.0 * Double.pi * (safeF0 / safeFs)
        let cw = cos(w0)
        let sw = sin(w0)
        let alpha = sw / (2.0 * safeQ)

        let b0u = 1.0 + alpha * A
        let b1u = -2.0 * cw
        let b2u = 1.0 - alpha * A
        let a0u = 1.0 + alpha / A
        let a1u = -2.0 * cw
        let a2u = 1.0 - alpha / A
        setNorm(b0u: b0u, b1u: b1u, b2u: b2u, a0u: a0u, a1u: a1u, a2u: a2u)
    }

    func setLowShelf(fs: Double, f0: Double, slope: Double, gainDb: Double) {
        let safeFs = max(8000.0, fs)
        let nyq = safeFs * 0.5
        let safeF0 = min(max(20.0, f0), nyq * 0.70)
        let safeSlope = min(1.0, max(0.20, slope))
        let db = min(18.0, max(-18.0, gainDb))

        let A = pow(10.0, db / 40.0)
        let w0 = 2.0 * Double.pi * (safeF0 / safeFs)
        let cw = cos(w0)
        let sw = sin(w0)
        let sqrtA = sqrt(A)
        let alpha = (sw / 2.0) * sqrt((A + 1.0 / A) * (1.0 / safeSlope - 1.0) + 2.0)

        let b0u = A * ((A + 1.0) - (A - 1.0) * cw + 2.0 * sqrtA * alpha)
        let b1u = 2.0 * A * ((A - 1.0) - (A + 1.0) * cw)
        let b2u = A * ((A + 1.0) - (A - 1.0) * cw - 2.0 * sqrtA * alpha)
        let a0u = (A + 1.0) + (A - 1.0) * cw + 2.0 * sqrtA * alpha
        let a1u = -2.0 * ((A - 1.0) + (A + 1.0) * cw)
        let a2u = (A + 1.0) + (A - 1.0) * cw - 2.0 * sqrtA * alpha
        setNorm(b0u: b0u, b1u: b1u, b2u: b2u, a0u: a0u, a1u: a1u, a2u: a2u)
    }

    func setHighShelf(fs: Double, f0: Double, slope: Double, gainDb: Double) {
        let safeFs = max(8000.0, fs)
        let nyq = safeFs * 0.5
        let safeF0 = min(max(1000.0, f0), nyq * 0.88)
        let safeSlope = min(1.0, max(0.20, slope))
        let db = min(18.0, max(-18.0, gainDb))

        let A = pow(10.0, db / 40.0)
        let w0 = 2.0 * Double.pi * (safeF0 / safeFs)
        let cw = cos(w0)
        let sw = sin(w0)
        let sqrtA = sqrt(A)
        let alpha = (sw / 2.0) * sqrt((A + 1.0 / A) * (1.0 / safeSlope - 1.0) + 2.0)

        let b0u = A * ((A + 1.0) + (A - 1.0) * cw + 2.0 * sqrtA * alpha)
        let b1u = -2.0 * A * ((A - 1.0) + (A + 1.0) * cw)
        let b2u = A * ((A + 1.0) + (A - 1.0) * cw - 2.0 * sqrtA * alpha)
        let a0u = (A + 1.0) - (A - 1.0) * cw + 2.0 * sqrtA * alpha
        let a1u = 2.0 * ((A - 1.0) - (A + 1.0) * cw)
        let a2u = (A + 1.0) - (A - 1.0) * cw - 2.0 * sqrtA * alpha
        setNorm(b0u: b0u, b1u: b1u, b2u: b2u, a0u: a0u, a1u: a1u, a2u: a2u)
    }

    func setNotch(fs: Double, f0: Double, q: Double) {
        let safeFs = max(8000.0, fs)
        let nyq = safeFs * 0.5
        let safeF0 = min(max(20.0, f0), nyq * 0.92)
        let safeQ = max(0.20, q)

        let w0 = 2.0 * Double.pi * safeF0 / safeFs
        let cw = cos(w0)
        let sw = sin(w0)
        let alpha = sw / (2.0 * safeQ)

        let b0u = 1.0
        let b1u = -2.0 * cw
        let b2u = 1.0
        let a0u = 1.0 + alpha
        let a1u = -2.0 * cw
        let a2u = 1.0 - alpha

        setNorm(b0u: b0u, b1u: b1u, b2u: b2u, a0u: a0u, a1u: a1u, a2u: a2u)
    }
}

// MARK: - Eq5Band
final class Eq5Band {
    private let fs: Double
    private let low = Biquad()
    private let bass = Biquad()
    private let mid = Biquad()
    private let treble = Biquad()
    private let high = Biquad()

    private var lastDb: [Double] = [0.0, 0.0, 0.0, 0.0, 0.0]

    init(fs: Double) {
        self.fs = max(8000.0, fs)
        updateGainsDb(lastDb)
    }

    func resetState() {
        low.resetState()
        bass.resetState()
        mid.resetState()
        treble.resetState()
        high.resetState()
    }

    /// db length=5: [Low, Bass, Mid, Treble, High]
    /// Low    = trầm sâu
    /// Bass   = lực bass
    /// Mid    = vang/giọng
    /// Treble = chói/sắc
    /// High   = sáng/chi tiết
    func updateGainsDb(_ db: [Double]) {
        guard db.count >= 5 else { return }

        for i in 0..<5 {
            lastDb[i] = min(18.0, max(-18.0, db[i]))
        }

        // Match Android final tuning.
        // These are intentionally separated so each slider changes tone, not just volume.
        low.setLowShelf(fs: fs, f0: 80.0, slope: 0.85, gainDb: lastDb[0])
        bass.setPeaking(fs: fs, f0: 180.0, q: 0.90, gainDb: lastDb[1])
        mid.setPeaking(fs: fs, f0: 900.0, q: 0.95, gainDb: lastDb[2])
        treble.setPeaking(fs: fs, f0: 4200.0, q: 0.85, gainDb: lastDb[3])

        let nyq = fs * 0.5
        let fHigh = min(9000.0, nyq * 0.82)
        high.setHighShelf(fs: fs, f0: fHigh, slope: 0.85, gainDb: lastDb[4])
    }

    @inline(__always)
    func process(_ x: Double) -> Double {
        var y = x
        y = low.process(y)
        y = bass.process(y)
        y = mid.process(y)
        y = treble.process(y)
        y = high.process(y)
        return y.isFinite ? y : 0.0
    }
}

// MARK: - AntiFeedbackAfs
final class AntiFeedbackAfs {

    private let fs: Double

    private let candidates: [Double] = [
        2500.0, 3150.0, 4000.0,
        5000.0, 6300.0, 8000.0
    ]

    private let notchCount = 2
    private var notch: [Biquad]
    private var notchF: [Double]
    private var notchUntilMs: [Int64]
    private var notchGain: [Double]
    private var notchTarget: [Double]

    private let Q: Double = 10.0
    private var ema: [Double]
    private let emaAlpha: Double = 0.92

    private let holdMs: Int64 = 500

    init(fs: Double) {
        self.fs = max(8000.0, fs)

        // Do not use Array(repeating: Biquad(), count: n) for class instances.
        // That would put the SAME Biquad object in every slot.
        self.notch = (0..<notchCount).map { _ in Biquad() }
        self.notchF = Array(repeating: 0.0, count: notchCount)
        self.notchUntilMs = Array(repeating: 0, count: notchCount)
        self.notchGain = Array(repeating: 0.0, count: notchCount)
        self.notchTarget = Array(repeating: 0.0, count: notchCount)
        self.ema = Array(repeating: 1e-6, count: candidates.count)
        reset()
    }

    func reset() {
        for i in 0..<notchCount {
            notchF[i] = 0.0
            notchUntilMs[i] = 0
            notchGain[i] = 0.0
            notchTarget[i] = 0.0
            notch[i].setNotch(fs: fs, f0: 1000.0, q: Q)
            notch[i].resetState()
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

    func analyzeFloat(input: UnsafePointer<Float>, count n: Int) {
        let now = Self.nowMs()
        if n <= 0 { return }

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

        let f0 = candidates[bestK]
        let bestEnergy = e[bestK]

        // Harder trigger so normal voice/EQ boost is not mistaken as feedback.
        if bestScore < 18.0 { return }
        if bestEnergy < 1.5e-5 { return }

        for i in 0..<notchCount {
            if notchF[i] > 0.0,
               abs(notchF[i] - f0) < 150.0,
               now < notchUntilMs[i] {
                notchUntilMs[i] = now + holdMs
                notchTarget[i] = 1.0
                return
            }
        }

        var slot = -1
        for i in 0..<notchCount {
            if now >= notchUntilMs[i] && notchGain[i] < 0.08 {
                slot = i
                break
            }
        }

        if slot < 0 { slot = 0 }

        notchF[slot] = f0
        notch[slot].setNotch(fs: fs, f0: f0, q: Q)
        notchUntilMs[slot] = now + holdMs
        notchTarget[slot] = 1.0
    }

    @inline(__always)
    func process(_ xIn: Double) -> Double {
        var x = xIn
        let now = Self.nowMs()

        for i in 0..<notchCount {
            if notchF[i] <= 0.0 { continue }

            if now >= notchUntilMs[i] {
                notchTarget[i] = 0.0
            }

            let target = notchTarget[i]
            let k = target > notchGain[i] ? 0.10 : 0.025
            notchGain[i] += (target - notchGain[i]) * k

            let wet = notch[i].process(x)
            x = x * (1.0 - notchGain[i]) + wet * notchGain[i]

            if notchGain[i] < 0.002 && target == 0.0 {
                notchF[i] = 0.0
                notch[i].resetState()
            }
        }

        return x.isFinite ? x : 0.0
    }

    private func goertzelEnergyFloat(
        buf: UnsafePointer<Float>,
        n: Int,
        freq: Double,
        fs: Double
    ) -> Double {
        let w = 2.0 * Double.pi * freq / fs
        let coeff = 2.0 * cos(w)

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
