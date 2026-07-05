// DspEq.kt (FINAL: separated Low/Bass/Mid/Treble/High bands)
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

  fun reset() {
    z1 = 0.0
    z2 = 0.0
  }

  fun process(x: Double): Double {
    val y = b0 * x + z1
    z1 = b1 * x - a1 * y + z2
    z2 = b2 * x - a2 * y
    return if (y.isFinite()) y else 0.0
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
    val db = gainDb.coerceIn(-24.0, 24.0)
    val A = 10.0.pow(db / 40.0)
    val w0 = 2.0 * Math.PI * (f0 / fs)
    val cw = cos(w0)
    val sw = sin(w0)
    val alpha = sw / (2.0 * q.coerceAtLeast(0.05))

    setNorm(
      1.0 + alpha * A,
      -2.0 * cw,
      1.0 - alpha * A,
      1.0 + alpha / A,
      -2.0 * cw,
      1.0 - alpha / A
    )
  }

  fun setLowShelf(fs: Double, f0: Double, slope: Double, gainDb: Double) {
    val db = gainDb.coerceIn(-24.0, 24.0)
    val A = 10.0.pow(db / 40.0)
    val w0 = 2.0 * Math.PI * (f0 / fs)
    val cw = cos(w0)
    val sw = sin(w0)
    val sqrtA = sqrt(A)
    val s = slope.coerceIn(0.1, 2.0)
    val alpha = sw / 2.0 * sqrt((A + 1.0 / A) * (1.0 / s - 1.0) + 2.0)

    setNorm(
      A * ((A + 1.0) - (A - 1.0) * cw + 2.0 * sqrtA * alpha),
      2.0 * A * ((A - 1.0) - (A + 1.0) * cw),
      A * ((A + 1.0) - (A - 1.0) * cw - 2.0 * sqrtA * alpha),
      (A + 1.0) + (A - 1.0) * cw + 2.0 * sqrtA * alpha,
      -2.0 * ((A - 1.0) + (A + 1.0) * cw),
      (A + 1.0) + (A - 1.0) * cw - 2.0 * sqrtA * alpha
    )
  }

  fun setHighShelf(fs: Double, f0: Double, slope: Double, gainDb: Double) {
    val db = gainDb.coerceIn(-24.0, 24.0)
    val A = 10.0.pow(db / 40.0)
    val w0 = 2.0 * Math.PI * (f0 / fs)
    val cw = cos(w0)
    val sw = sin(w0)
    val sqrtA = sqrt(A)
    val s = slope.coerceIn(0.1, 2.0)
    val alpha = sw / 2.0 * sqrt((A + 1.0 / A) * (1.0 / s - 1.0) + 2.0)

    setNorm(
      A * ((A + 1.0) + (A - 1.0) * cw + 2.0 * sqrtA * alpha),
      -2.0 * A * ((A - 1.0) + (A + 1.0) * cw),
      A * ((A + 1.0) + (A - 1.0) * cw - 2.0 * sqrtA * alpha),
      (A + 1.0) - (A - 1.0) * cw + 2.0 * sqrtA * alpha,
      2.0 * ((A - 1.0) - (A + 1.0) * cw),
      (A + 1.0) - (A - 1.0) * cw - 2.0 * sqrtA * alpha
    )
  }

  fun setNotch(fs: Double, f0: Double, q: Double) {
    val w0 = 2.0 * Math.PI * f0 / fs
    val cw = cos(w0)
    val sw = sin(w0)
    val alpha = sw / (2.0 * q.coerceAtLeast(0.05))

    setNorm(
      1.0, -2.0 * cw, 1.0,
      1.0 + alpha, -2.0 * cw, 1.0 - alpha
    )
  }
}

internal class Eq5Band(private val fs: Double) {
  private val low = Biquad()
  private val bass = Biquad()
  private val mid = Biquad()
  private val treble = Biquad()
  private val high = Biquad()

  private val gainsDb = DoubleArray(5) { 0.0 }

  init { updateGainsDb(gainsDb) }

  fun reset() {
    low.reset()
    bass.reset()
    mid.reset()
    treble.reset()
    high.reset()
  }

  /**
   * db order:
   * [0] Low    = sub/trầm nền       ~ 75Hz shelf
   * [1] Bass   = lực bass           ~ 170Hz bell
   * [2] Mid    = giọng/vang         ~ 1.1kHz bell rộng
   * [3] Treble = chói/sắc           ~ 5.2kHz bell
   * [4] High   = sáng/chi tiết      ~ 9.5kHz shelf
   */
  fun updateGainsDb(db: DoubleArray) {
    if (db.size < 5) return
    for (i in 0 until 5) gainsDb[i] = db[i].coerceIn(-24.0, 24.0)

    low.setLowShelf(fs, 75.0, 0.70, gainsDb[0])
    bass.setPeaking(fs, 170.0, 0.80, gainsDb[1])
    mid.setPeaking(fs, 1100.0, 0.55, gainsDb[2])
    treble.setPeaking(fs, 5200.0, 1.05, gainsDb[3])

    val nyq = fs * 0.5
    val highFreq = min(9500.0, nyq * 0.82)
    high.setHighShelf(fs, highFreq, 0.85, gainsDb[4])
  }

  fun process(x: Double): Double {
    var y = x
    y = low.process(y)
    y = bass.process(y)
    y = mid.process(y)
    y = treble.process(y)
    y = high.process(y)
    return if (y.isFinite()) y else 0.0
  }
}
