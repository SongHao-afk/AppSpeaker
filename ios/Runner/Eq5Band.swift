import Foundation

// MARK: - Biquad (Direct Form II)
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
        return y
    }

    func resetState() {
        z1 = 0.0
        z2 = 0.0
    }

    private func setNorm(b0u: Double, b1u: Double, b2u: Double,
                         a0u: Double, a1u: Double, a2u: Double) {
        let inv = 1.0 / a0u
        b0 = b0u * inv
        b1 = b1u * inv
        b2 = b2u * inv
        a1 = a1u * inv
        a2 = a2u * inv
    }

    func setPeaking(fs: Double, f0: Double, q: Double, gainDb: Double) {
        let A = pow(10.0, gainDb / 40.0)
        let w0 = 2.0 * Double.pi * (f0 / fs)
        let cw = cos(w0)
        let sw = sin(w0)
        let alpha = sw / (2.0 * q)

        let b0u = 1.0 + alpha * A
        let b1u = -2.0 * cw
        let b2u = 1.0 - alpha * A
        let a0u = 1.0 + alpha / A
        let a1u = -2.0 * cw
        let a2u = 1.0 - alpha / A
        setNorm(b0u: b0u, b1u: b1u, b2u: b2u, a0u: a0u, a1u: a1u, a2u: a2u)
    }

    func setLowShelf(fs: Double, f0: Double, slope: Double, gainDb: Double) {
        let A = pow(10.0, gainDb / 40.0)
        let w0 = 2.0 * Double.pi * (f0 / fs)
        let cw = cos(w0)
        let sw = sin(w0)
        let sqrtA = sqrt(A)

        let alpha = (sw / 2.0) * sqrt((A + 1.0 / A) * (1.0 / slope - 1.0) + 2.0)

        let b0u = A * ((A + 1.0) - (A - 1.0) * cw + 2.0 * sqrtA * alpha)
        let b1u = 2.0 * A * ((A - 1.0) - (A + 1.0) * cw)
        let b2u = A * ((A + 1.0) - (A - 1.0) * cw - 2.0 * sqrtA * alpha)
        let a0u = (A + 1.0) + (A - 1.0) * cw + 2.0 * sqrtA * alpha
        let a1u = -2.0 * ((A - 1.0) + (A + 1.0) * cw)
        let a2u = (A + 1.0) + (A - 1.0) * cw - 2.0 * sqrtA * alpha
        setNorm(b0u: b0u, b1u: b1u, b2u: b2u, a0u: a0u, a1u: a1u, a2u: a2u)
    }

    func setHighShelf(fs: Double, f0: Double, slope: Double, gainDb: Double) {
        let A = pow(10.0, gainDb / 40.0)
        let w0 = 2.0 * Double.pi * (f0 / fs)
        let cw = cos(w0)
        let sw = sin(w0)
        let sqrtA = sqrt(A)

        let alpha = (sw / 2.0) * sqrt((A + 1.0 / A) * (1.0 / slope - 1.0) + 2.0)

        let b0u = A * ((A + 1.0) + (A - 1.0) * cw + 2.0 * sqrtA * alpha)
        let b1u = -2.0 * A * ((A - 1.0) + (A + 1.0) * cw)
        let b2u = A * ((A + 1.0) + (A - 1.0) * cw - 2.0 * sqrtA * alpha)
        let a0u = (A + 1.0) - (A - 1.0) * cw + 2.0 * sqrtA * alpha
        let a1u = 2.0 * ((A - 1.0) - (A + 1.0) * cw)
        let a2u = (A + 1.0) - (A - 1.0) * cw - 2.0 * sqrtA * alpha
        setNorm(b0u: b0u, b1u: b1u, b2u: b2u, a0u: a0u, a1u: a1u, a2u: a2u)
    }

    func setNotch(fs: Double, f0: Double, q: Double) {
        let w0 = 2.0 * Double.pi * f0 / fs
        let cw = cos(w0)
        let sw = sin(w0)
        let alpha = sw / (2.0 * q)

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
    private let m1  = Biquad()
    private let m2  = Biquad()
    private let m3  = Biquad()
    private let high = Biquad()

    init(fs: Double) { self.fs = fs }

    /// db length=5: [low, m1, m2, m3, high]
    func updateGainsDb(_ db: [Double]) {
        guard db.count >= 5 else { return }

        low.setLowShelf(fs: fs, f0: 60.0, slope: 1.0, gainDb: db[0])
        m1.setPeaking(fs: fs, f0: 230.0, q: 1.0, gainDb: db[1])
        m2.setPeaking(fs: fs, f0: 910.0, q: 1.0, gainDb: db[2])
        m3.setPeaking(fs: fs, f0: 3600.0, q: 1.0, gainDb: db[3])

        let nyq = fs * 0.5
        let fHigh = min(14_000.0, nyq * 0.90)
        high.setHighShelf(fs: fs, f0: fHigh, slope: 1.0, gainDb: db[4])
    }

    @inline(__always)
    func process(_ x: Double) -> Double {
        var y = x
        y = low.process(y)
        y = m1.process(y)
        y = m2.process(y)
        y = m3.process(y)
        y = high.process(y)
        return y
    }
}
