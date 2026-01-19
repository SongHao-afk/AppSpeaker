// DspEq.kt
package com.example.flutter_application_3

import kotlin.math.*

internal class Biquad {
  private var b0 = 1.0
  private var b1 = 0.0
  private var b2 = 0.0
  private var a1 = 0.0
  private var a2 = 0.0
  private var z1 = 0.0
  private var z2 = 0.0

  fun process(x: Double): Double {
    val y = b0 * x + z1
    z1 = b1 * x - a1 * y + z2
    z2 = b2 * x - a2 * y
    return y
  }

  private fun setNorm(
    b0u: Double, b1u: Double, b2u: Double,
    a0u: Double, a1u: Double, a2u: Double
  ) {
    val inv = 1.0 / a0u
    b0 = b0u * inv
    b1 = b1u * inv
    b2 = b2u * inv
    a1 = a1u * inv
    a2 = a2u * inv
  }

  fun setPeaking(fs: Double, f0: Double, q: Double, gainDb: Double) {
    val A = 10.0.pow(gainDb / 40.0)
    val w0 = 2.0 * Math.PI * (f0 / fs)
    val cw = cos(w0)
    val sw = sin(w0)
    val alpha = sw / (2.0 * q)

    val b0u = 1.0 + alpha * A
    val b1u = -2.0 * cw
    val b2u = 1.0 - alpha * A
    val a0u = 1.0 + alpha / A
    val a1u = -2.0 * cw
    val a2u = 1.0 - alpha / A
    setNorm(b0u, b1u, b2u, a0u, a1u, a2u)
  }

  fun setLowShelf(fs: Double, f0: Double, slope: Double, gainDb: Double) {
    val A = 10.0.pow(gainDb / 40.0)
    val w0 = 2.0 * Math.PI * (f0 / fs)
    val cw = cos(w0)
    val sw = sin(w0)
    val sqrtA = sqrt(A)
    val alpha = sw / 2.0 * sqrt((A + 1.0 / A) * (1.0 / slope - 1.0) + 2.0)

    val b0u = A * ((A + 1) - (A - 1) * cw + 2 * sqrtA * alpha)
    val b1u = 2 * A * ((A - 1) - (A + 1) * cw)
    val b2u = A * ((A + 1) - (A - 1) * cw - 2 * sqrtA * alpha)
    val a0u = (A + 1) + (A - 1) * cw + 2 * sqrtA * alpha
    val a1u = -2 * ((A - 1) + (A + 1) * cw)
    val a2u = (A + 1) + (A - 1) * cw - 2 * sqrtA * alpha
    setNorm(b0u, b1u, b2u, a0u, a1u, a2u)
  }

  fun setHighShelf(fs: Double, f0: Double, slope: Double, gainDb: Double) {
    val A = 10.0.pow(gainDb / 40.0)
    val w0 = 2.0 * Math.PI * (f0 / fs)
    val cw = cos(w0)
    val sw = sin(w0)
    val sqrtA = sqrt(A)
    val alpha = sw / 2.0 * sqrt((A + 1.0 / A) * (1.0 / slope - 1.0) + 2.0)

    val b0u = A * ((A + 1) + (A - 1) * cw + 2 * sqrtA * alpha)
    val b1u = -2 * A * ((A - 1) + (A + 1) * cw)
    val b2u = A * ((A + 1) + (A - 1) * cw - 2 * sqrtA * alpha)
    val a0u = (A + 1) - (A - 1) * cw + 2 * sqrtA * alpha
    val a1u = 2 * ((A - 1) - (A + 1) * cw)
    val a2u = (A + 1) - (A - 1) * cw - 2 * sqrtA * alpha
    setNorm(b0u, b1u, b2u, a0u, a1u, a2u)
  }

  fun setNotch(fs: Double, f0: Double, q: Double) {
    val w0 = 2.0 * Math.PI * (f0 / fs)
    val cw = cos(w0)
    val sw = sin(w0)
    val alpha = sw / (2.0 * q)

    val b0u = 1.0
    val b1u = -2.0 * cw
    val b2u = 1.0
    val a0u = 1.0 + alpha
    val a1u = -2.0 * cw
    val a2u = 1.0 - alpha
    setNorm(b0u, b1u, b2u, a0u, a1u, a2u)
  }
}

internal class Eq5Band(private val fs: Double) {
  private val low = Biquad()
  private val m1 = Biquad()
  private val m2 = Biquad()
  private val m3 = Biquad()
  private val high = Biquad()

  fun updateGainsDb(db: DoubleArray) {
    low.setLowShelf(fs, 60.0, 1.0, db[0])
    m1.setPeaking(fs, 230.0, 1.0, db[1])
    m2.setPeaking(fs, 910.0, 1.0, db[2])
    m3.setPeaking(fs, 3600.0, 1.0, db[3])

    val nyq = fs * 0.5
    val fHigh = min(14000.0, nyq * 0.90)
    high.setHighShelf(fs, fHigh, 1.0, db[4])
  }

  fun process(x: Double): Double {
    var y = x
    y = low.process(y)
    y = m1.process(y)
    y = m2.process(y)
    y = m3.process(y)
    y = high.process(y)
    return y
  }
}
