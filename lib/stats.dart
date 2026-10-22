// Statistics for dice fairness and condition comparison.
//
// Two complementary approaches are used:
//  * Bayes factors (Dirichlet–multinomial). They stay valid when you peek after
//    every roll and stop whenever you like (optional stopping), which is exactly
//    how the app is used. This is the primary verdict.
//  * Classic Pearson chi-square with p-value, for reference. Note that checking
//    the p-value after every roll inflates false positives.
import 'dart:math' as math;

const double _ln10 = math.ln10;

/// ln Γ(x) for x > 0 (Lanczos approximation, g = 7, n = 9).
double lgamma(double x) {
  const g = 7.0;
  const c = <double>[
    0.99999999999980993,
    676.5203681218851,
    -1259.1392167224028,
    771.32342877765313,
    -176.61502916214059,
    12.507343278686905,
    -0.13857109526572012,
    9.9843695780195716e-6,
    1.5056327351493116e-7,
  ];
  if (x < 0.5) {
    // Reflection formula.
    return math.log(math.pi / math.sin(math.pi * x)).toDouble() - lgamma(1 - x);
  }
  x -= 1;
  var a = c[0];
  final t = x + g + 0.5;
  for (var i = 1; i < 9; i++) {
    a += c[i] / (x + i);
  }
  return 0.5 * math.log(2 * math.pi) + (x + 0.5) * math.log(t) - t + math.log(a);
}

/// Regularized upper incomplete gamma Q(a, x).
double gammaQ(double a, double x) {
  if (x <= 0) return 1.0;
  if (x < a + 1) {
    // Series for P, then Q = 1 - P.
    var sum = 1.0 / a;
    var del = sum;
    var ap = a;
    for (var n = 0; n < 1000; n++) {
      ap += 1;
      del *= x / ap;
      sum += del;
      if (del.abs() < sum.abs() * 1e-15) break;
    }
    final p = sum * math.exp(-x + a * math.log(x) - lgamma(a));
    return (1.0 - p).clamp(0.0, 1.0);
  }
  // Continued fraction (Lentz).
  const tiny = 1e-300;
  var b = x + 1 - a;
  var c = 1 / tiny;
  var d = 1 / b;
  var h = d;
  for (var i = 1; i < 1000; i++) {
    final an = -i * (i - a);
    b += 2;
    d = an * d + b;
    if (d.abs() < tiny) d = tiny;
    c = b + an / c;
    if (c.abs() < tiny) c = tiny;
    d = 1 / d;
    final del = d * c;
    h *= del;
    if ((del - 1).abs() < 1e-15) break;
  }
  return (math.exp(-x + a * math.log(x) - lgamma(a)) * h).clamp(0.0, 1.0);
}

/// Upper tail of the chi-square distribution.
double chiSquareSf(double x, int df) => df <= 0 ? 1.0 : gammaQ(df / 2.0, x / 2.0);

/// Typical relative deviation of a face probability from 1/k that the "biased"
/// hypothesis expects (±15%). A flat Dirichlet(1) would expect absurdly large
/// biases and then declare almost any die "fair" after a few hundred rolls.
const double biasScale = 0.15;

/// Symmetric Dirichlet concentration giving each face a prior relative
/// standard deviation of [scale] around 1/k.
double dirichletAlpha(int k, {double scale = biasScale}) => ((k - 1) / (scale * scale) - 1) / k;

/// Log marginal likelihood of an ordered sequence with these counts under a
/// symmetric Dirichlet(alpha) prior on face probabilities.
double logDirMult(List<int> counts, {double? alpha}) {
  final k = counts.length;
  final a = alpha ?? dirichletAlpha(k);
  final n = counts.fold<int>(0, (s, c) => s + c);
  var r = lgamma(k * a) - lgamma(n + k * a);
  for (final c in counts) {
    r += lgamma(c + a) - lgamma(a);
  }
  return r;
}

/// Wilson score interval for a binomial proportion.
(double, double) wilson(int hits, int n, {double z = 1.96}) {
  if (n == 0) return (0.0, 1.0);
  final p = hits / n;
  final z2 = z * z;
  final denom = 1 + z2 / n;
  final centre = (p + z2 / (2 * n)) / denom;
  final half = z * math.sqrt(p * (1 - p) / n + z2 / (4 * n * n)) / denom;
  return ((centre - half).clamp(0.0, 1.0), (centre + half).clamp(0.0, 1.0));
}

enum Verdict {
  needMore('Мало данных', 'Нужно больше бросков'),
  strongFair('Честный', 'Сильные свидетельства в пользу честности'),
  fair('Скорее честный', 'Умеренные свидетельства в пользу честности'),
  unclear('Неясно', 'Данные пока не различают гипотезы'),
  biased('Подозрительный', 'Умеренные свидетельства перекоса'),
  strongBiased('Перекошен', 'Сильные свидетельства перекоса');

  const Verdict(this.title, this.description);
  final String title;
  final String description;

  /// Jeffreys-style thresholds on log10 BF01 (fair vs. biased).
  static Verdict fromLog10Bf01(double l, int n, int k) {
    if (n < k) return Verdict.needMore;
    if (l >= 1) return Verdict.strongFair;
    if (l >= 0.5) return Verdict.fair;
    if (l > -0.5) return Verdict.unclear;
    if (l > -1) return Verdict.biased;
    return Verdict.strongBiased;
  }
}

class FairnessResult {
  FairnessResult(this.counts) : n = counts.fold(0, (s, c) => s + c), k = counts.length {
    final expected = n / k;
    var x2 = 0.0;
    if (n > 0) {
      for (final c in counts) {
        x2 += (c - expected) * (c - expected) / expected;
      }
    }
    chiSquare = x2;
    pValue = n == 0 ? 1.0 : chiSquareSf(x2, k - 1);
    final logFair = n * math.log(1.0 / k);
    log10Bf01 = (logFair - logDirMult(counts)) / _ln10;
    verdict = Verdict.fromLog10Bf01(log10Bf01, n, k);
  }

  final List<int> counts;
  final int n;
  final int k;
  late final double chiSquare;
  late final double pValue;

  /// log10 of Bayes factor "fair" vs. "arbitrary bias" (Dirichlet prior with ±15% typical bias).
  /// Positive → evidence for a fair die, negative → evidence for bias.
  late final double log10Bf01;
  late final Verdict verdict;

  double get expected => n / k;

  /// Posterior probability of the fair hypothesis given 50/50 prior odds.
  double get pFair {
    final l = log10Bf01.clamp(-300.0, 300.0);
    final bf = math.pow(10, l).toDouble();
    return bf / (1 + bf);
  }

  /// Chi-square rule of thumb: at least 5 expected per face.
  bool get chiSquareReliable => expected >= 5;
  int get recommendedRolls => 5 * k;

  /// Relative per-face deviation from 1/k that is roughly resolvable now
  /// (≈2.5 standard errors).
  double get detectableBias => n == 0 ? double.infinity : 2.5 * math.sqrt((k - 1) / n);

  /// Standardized residual of a face, (O−E)/√E.
  double residual(int i) => n == 0 ? 0 : (counts[i] - expected) / math.sqrt(expected);
}

/// Running log10 BF01 after each roll, computed incrementally from the
/// sequential predictive probabilities.
List<double> bfTrajectory(Iterable<int> faces, int k) {
  final counts = List<int>.filled(k, 0);
  final out = <double>[];
  var n = 0;
  var l = 0.0;
  final logP0 = math.log(1.0 / k);
  final a = dirichletAlpha(k);
  for (final f in faces) {
    l += logP0 - math.log((counts[f] + a) / (n + k * a));
    counts[f]++;
    n++;
    out.add(l / _ln10);
  }
  return out;
}

class HomogeneityResult {
  /// [table] rows are conditions, columns are faces.
  HomogeneityResult(List<List<int>> table) : rows = table.where((r) => r.any((c) => c > 0)).toList() {
    final k = table.isEmpty ? 0 : table.first.length;
    final colTotals = List<int>.filled(k, 0);
    for (final r in rows) {
      for (var j = 0; j < k; j++) {
        colTotals[j] += r[j];
      }
    }
    final total = colTotals.fold<int>(0, (s, c) => s + c);
    var x2 = 0.0;
    var minExpected = double.infinity;
    for (final r in rows) {
      final rowTotal = r.fold<int>(0, (s, c) => s + c);
      for (var j = 0; j < k; j++) {
        if (colTotals[j] == 0) continue;
        final e = rowTotal * colTotals[j] / total;
        minExpected = math.min(minExpected, e);
        x2 += (r[j] - e) * (r[j] - e) / e;
      }
    }
    final nonEmptyCols = colTotals.where((c) => c > 0).length;
    df = (rows.length - 1) * (nonEmptyCols - 1);
    chiSquare = x2;
    pValue = df <= 0 ? 1.0 : chiSquareSf(x2, df);
    this.minExpected = minExpected.isFinite ? minExpected : 0;
    // H1: each condition has its own face distribution; H0: one shared.
    if (rows.length < 2) {
      log10Bf10 = 0;
    } else {
      final logH1 = rows.fold<double>(0, (s, r) => s + logDirMult(r));
      final logH0 = logDirMult(colTotals);
      log10Bf10 = (logH1 - logH0) / _ln10;
    }
  }

  final List<List<int>> rows;
  late final int df;
  late final double chiSquare;
  late final double pValue;
  late final double minExpected;

  /// log10 BF "conditions differ" vs. "conditions identical".
  late final double log10Bf10;
}

class HitRateResult {
  HitRateResult({required this.hits, required this.n, required this.p0}) {
    if (n == 0) {
      log10Bf10 = 0;
      z = 0;
      return;
    }
    // H1: hit rate ~ Beta centred on p0 with ±50% relative spread (two-sided);
    // H0: hit rate = p0.
    final ab = (1 - p0) / (p0 * hitScale * hitScale) - 1;
    final a = p0 * ab, b = (1 - p0) * ab;
    final logH1 = _lbeta(hits + a, n - hits + b) - _lbeta(a, b);
    final logH0 = hits * math.log(p0) + (n - hits) * math.log(1 - p0);
    log10Bf10 = (logH1 - logH0) / _ln10;
    z = (hits - n * p0) / math.sqrt(n * p0 * (1 - p0));
  }

  final int hits;
  final int n;
  final double p0;
  late final double log10Bf10;
  late final double z;

  double get rate => n == 0 ? 0 : hits / n;
  (double, double) get ci => wilson(hits, n);

  /// One-sided p-value (normal approximation) for "more hits than chance".
  double get pOneSided => n == 0 ? 1.0 : 0.5 * erfc(z / math.sqrt2);
}

/// Complementary error function (Numerical Recipes erfcc, ~1e-7 accuracy).
double erfc(double x) {
  final z = x.abs();
  final t = 1 / (1 + 0.5 * z);
  final r =
      t *
      math.exp(
        -z * z -
            1.26551223 +
            t *
                (1.00002368 +
                    t *
                        (0.37409196 +
                            t *
                                (0.09678418 +
                                    t *
                                        (-0.18628806 +
                                            t *
                                                (0.27886807 +
                                                    t *
                                                        (-1.13520398 +
                                                            t * (1.48851587 + t * (-0.82215223 + t * 0.17087277)))))))),
      );
  return x >= 0 ? r : 2 - r;
}

/// Human-readable Bayes factor, e.g. "12:1" or "1:40".
String formatBf(double log10Bf) {
  if (log10Bf.abs() > 6) {
    return log10Bf > 0 ? '>10⁶:1' : '1:>10⁶';
  }
  final bf = math.pow(10, log10Bf).toDouble();
  String fmt(double v) => v >= 100
      ? v.toStringAsFixed(0)
      : v >= 10
      ? v.toStringAsFixed(1)
      : v.toStringAsFixed(2);
  return bf >= 1 ? '${fmt(bf)}:1' : '1:${fmt(1 / bf)}';
}

String formatP(double p) {
  if (p < 0.0001) return '<0.0001';
  if (p < 0.01) return p.toStringAsFixed(4);
  return p.toStringAsFixed(3);
}

/// Relative change of the hit rate the "effect" hypothesis expects (±50%).
const double hitScale = 0.5;

double _lbeta(double a, double b) => lgamma(a) + lgamma(b) - lgamma(a + b);

String formatPercent(double p) {
  if (p > 0.999) return '>99.9%';
  if (p < 0.001) return '<0.1%';
  return '${(p * 100).toStringAsFixed(1)}%';
}
