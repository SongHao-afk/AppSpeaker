// AntiFeedbackAfs.kt (FIXED: less false-positive on voice, 2-notch only)
package com.example.flutter_application_3

import kotlin.math.*

internal class AntiFeedbackAfs(private val fs: Double) {

  // Keep candidates (speech-formant heavy zones still possible, but we harden detection)
  private val candidates = doubleArrayOf(
    2000.0, 2500.0, 3150.0, 4000.0, 5000.0, 6300.0, 8000.0, 10000.0
  )

  // ✅ FIX: fewer notches -> less "boxy/roomy" artifacts
  private val notch = Array(2) { Biquad() }
  private val notchF = DoubleArray(notch.size) { 0.0 }
  private val notchUntil = LongArray(notch.size) { 0L }

  // Slightly wider notch (lower Q) reduces harsh ringing, still effective
  private val Q = 8.0

  // EMA baseline for each candidate
  private val ema = DoubleArray(candidates.size) { 1e-6 }
  private val emaAlpha = 0.90

  fun reset() {
    for (i in notch.indices) {
      notchF[i] = 0.0
      notchUntil[i] = 0L
      notch[i].setNotch(fs, 1000.0, Q)
    }
    for (i in ema.indices) ema[i] = 1e-6
  }

  fun activeCount(): Int {
    val now = System.currentTimeMillis()
    var c = 0
    for (i in notch.indices) if (notchF[i] > 0.0 && now < notchUntil[i]) c++
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

    // ✅ HARDEN: avoid catching normal speech peaks / room tone
    // - Raise score threshold (voice often triggers 8~12 on boosted mic)
    // - Raise absolute energy floor (only notch when truly loud)
    if (bestScore < 14.0) return
    if (e[bestK] < 1.2e-5) return

    val f0 = candidates[bestK]

    // If same freq already active, just extend a bit (short hold to avoid "stuck notch")
    for (i in notch.indices) {
      if (notchF[i] > 0.0 && abs(notchF[i] - f0) < 140.0 && now < notchUntil[i]) {
        notchUntil[i] = now + 650L
        return
      }
    }

    // Find free slot
    var slot = -1
    for (i in notch.indices) {
      if (now >= notchUntil[i]) { slot = i; break }
    }
    if (slot < 0) slot = 0

    notchF[slot] = f0
    notch[slot].setNotch(fs, f0, Q)
    notchUntil[slot] = now + 650L
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
    val cosw = cos(w)
    val coeff = 2.0 * cosw

    var s0 = 0.0
    var s1 = 0.0
    var s2 = 0.0

    var i = 0
    while (i < n) {
      val x = buf[i].toDouble() / 32768.0
      s0 = x + coeff * s1 - s2
      s2 = s1
      s1 = s0
      i += 1
    }

    val power = s1 * s1 + s2 * s2 - coeff * s1 * s2
    return power.coerceAtLeast(0.0)
  }
}
