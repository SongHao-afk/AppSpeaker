package com.example.flutter_application_3

import kotlin.math.*

internal class AntiFeedbackAfs(private val fs: Double) {
  private val candidates = doubleArrayOf(
    2500.0, 3150.0, 4000.0, 5000.0, 6300.0, 8000.0
  )

  private val notch = Array(2) { Biquad() }
  private val notchF = DoubleArray(notch.size) { 0.0 }
  private val notchUntil = LongArray(notch.size) { 0L }

  private val q = 10.0
  private val ema = DoubleArray(candidates.size) { 1e-6 }
  private val emaAlpha = 0.92

  fun reset() {
    for (i in notch.indices) {
      notchF[i] = 0.0
      notchUntil[i] = 0L
      notch[i].setNotch(fs, 1000.0, q)
    }
    for (i in ema.indices) ema[i] = 1e-6
  }

  fun activeCount(): Int {
    val now = System.currentTimeMillis()
    var c = 0
    for (i in notch.indices) {
      if (notchF[i] > 0.0 && now < notchUntil[i]) c++
    }
    return c
  }

  fun analyze(buf: ShortArray, n: Int) {
    val now = System.currentTimeMillis()
    val e = DoubleArray(candidates.size)

    for (k in candidates.indices) {
      e[k] = goertzelEnergy(buf, n, candidates[k], fs)
      ema[k] = emaAlpha * ema[k] + (1.0 - emaAlpha) * e[k].coerceAtLeast(1e-9)
    }

    var bestK = -1
    var bestScore = 0.0

    for (k in candidates.indices) {
      val score = e[k] / (ema[k] + 1e-9)
      if (score > bestScore) {
        bestScore = score
        bestK = k
      }
    }

    if (bestK < 0) return
    if (bestScore < 18.0) return
    if (e[bestK] < 1.5e-5) return

    val f0 = candidates[bestK]

    for (i in notch.indices) {
      if (notchF[i] > 0.0 && abs(notchF[i] - f0) < 150.0 && now < notchUntil[i]) {
        notchUntil[i] = now + 500L
        return
      }
    }

    var slot = -1
    for (i in notch.indices) {
      if (now >= notchUntil[i]) {
        slot = i
        break
      }
    }

    if (slot < 0) slot = 0

    notchF[slot] = f0
    notch[slot].setNotch(fs, f0, q)
    notchUntil[slot] = now + 500L
  }

  fun process(xIn: Double): Double {
    var x = xIn
    val now = System.currentTimeMillis()

    for (i in notch.indices) {
      if (notchF[i] > 0.0 && now < notchUntil[i]) {
        x = notch[i].process(x)
      }
    }

    return x
  }

  private fun goertzelEnergy(buf: ShortArray, n: Int, freq: Double, fs: Double): Double {
    val w = 2.0 * Math.PI * freq / fs
    val coeff = 2.0 * cos(w)

    var s0 = 0.0
    var s1 = 0.0
    var s2 = 0.0

    var i = 0
    while (i < n) {
      val x = buf[i].toDouble() / 32768.0
      s0 = x + coeff * s1 - s2
      s2 = s1
      s1 = s0
      i++
    }

    return (s1 * s1 + s2 * s2 - coeff * s1 * s2).coerceAtLeast(0.0)
  }
}