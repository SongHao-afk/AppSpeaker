// MARK: - AntiFeedbackAfs
final class AntiFeedbackAfs {

    private let fs: Double

    private let candidates: [Double] = [
        630.0, 700.0, 800.0, 1000.0, 1250.0,
        1600.0, 2000.0, 2500.0, 3150.0,
        4000.0, 5000.0, 6300.0
    ]

    private let notchCount = 4
    private var notch: [Biquad]
    private var notchF: [Double]
    private var notchUntilMs: [Int64]
    private var notchGain: [Double]
    private var notchTarget: [Double]

    private let Q: Double = 7.0
    private var ema: [Double]
    private let emaAlpha: Double = 0.92

    private let holdMs: Int64 = 1600

    init(fs: Double) {
        self.fs = fs
        self.notch = Array(repeating: Biquad(), count: notchCount)
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

        // Dịu hơn bản cũ: tránh bắt nhầm tiếng nói rồi notch giật gây bộp.
        if bestScore < 6.2 { return }
        if bestEnergy < 5e-6 { return }

        for i in 0..<notchCount {
            if notchF[i] > 0.0,
               abs(notchF[i] - f0) < 160.0,
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

        if slot < 0 {
            var weakest = notchGain[0]
            slot = 0
            for i in 1..<notchCount {
                if notchGain[i] < weakest {
                    weakest = notchGain[i]
                    slot = i
                }
            }
        }

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

        return x
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