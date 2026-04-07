import Foundation

// MARK: - AntiFeedbackAfs
// Bản này ưu tiên built-in speaker: bắt các đỉnh ring phổ biến,
// nhưng threshold đã nới để bớt ăn nhầm giọng nói.
final class AntiFeedbackAfs {

    private let fs: Double

    // Các vùng hay ring/chói trên speaker phone
    private let candidates: [Double] = [
        800.0, 1000.0, 1250.0, 1600.0, 2000.0, 2500.0, 3150.0, 4000.0, 5000.0
    ]

    private let notchCount = 3
    private var notch: [Biquad]
    private var notchF: [Double]
    private var notchUntilMs: [Int64]

    // notch hẹp hơn để bớt làm mỏng giọng
    private let Q: Double = 10.0

    private var ema: [Double]
    private let emaAlpha: Double = 0.88

    // giữ notch ngắn hơn để đỡ “kẹt” giọng
    private let holdMs: Int64 = 900

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

        let f0 = candidates[bestK]
        let bestEnergy = e[bestK]

        // speaker default cần trigger sớm hơn để chặn ring / chói
        if bestScore < 4.8 { return }
        if bestEnergy < 3e-6 { return }

        // nếu notch hiện tại gần tần số đó thì chỉ refresh
        for i in 0..<notchCount {
            if notchF[i] > 0.0,
               abs(notchF[i] - f0) < 180.0,
               now < notchUntilMs[i] {
                notchUntilMs[i] = now + holdMs
                return
            }
        }

        // tìm slot rảnh
        var slot = -1
        for i in 0..<notchCount {
            if now >= notchUntilMs[i] {
                slot = i
                break
            }
        }

        // nếu hết slot thì thay slot có expiry sớm nhất
        if slot < 0 {
            var minUntil = notchUntilMs[0]
            slot = 0
            for i in 1..<notchCount {
                if notchUntilMs[i] < minUntil {
                    minUntil = notchUntilMs[i]
                    slot = i
                }
            }
        }

        notchF[slot] = f0
        notch[slot].setNotch(fs: fs, f0: f0, q: Q)
        notchUntilMs[slot] = now + holdMs
    }

    @inline(__always)
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