// DspUtils.kt
package com.example.flutter_application_3

import kotlin.math.*

internal fun softClipCubic(xIn: Double): Double {
  if (!xIn.isFinite()) return 0.0
  var x = xIn
  if (x > 2.5) x = 2.5
  if (x < -2.5) x = -2.5
  val y = x - (x * x * x) / 3.0
  return y.coerceIn(-1.0, 1.0)
}

internal class OnePoleHpf(fs: Double, fc: Double) {
  private var a = 0.0
  private var x1 = 0.0
  private var y1 = 0.0

  init { set(fs, fc) }

  fun set(fs: Double, fc: Double) {
    val c = tan(Math.PI * fc / fs)
    a = (1.0 - c) / (1.0 + c)
    x1 = 0.0
    y1 = 0.0
  }

  fun process(x: Double): Double {
    val y = a * (y1 + x - x1)
    x1 = x
    y1 = y
    return y
  }
}

internal class SimpleCompressor(
  sampleRate: Double,
  threshold: Double,
  ratio: Double,
  attackMs: Double,
  releaseMs: Double
) {
  private val thr = threshold.coerceIn(1e-6, 0.99)
  private val rat = ratio.coerceAtLeast(1.0)
  private val atk = exp(-1.0 / (sampleRate * (attackMs / 1000.0)).coerceAtLeast(1e-6))
  private val rel = exp(-1.0 / (sampleRate * (releaseMs / 1000.0)).coerceAtLeast(1e-6))

  private var env = 0.0

  fun process(xIn: Double): Double {
    var x = xIn
    val a = abs(x)

    env = if (a > env) atk * env + (1.0 - atk) * a
    else rel * env + (1.0 - rel) * a

    if (env <= thr) return x

    val over = env / thr
    val gain = (over).pow((1.0 / rat) - 1.0)
    x *= gain
    return x
  }
}
