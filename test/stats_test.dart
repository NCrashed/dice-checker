import 'dart:math' as math;

import 'package:dice_checker/stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lgamma matches factorials', () {
    expect(lgamma(1), closeTo(0, 1e-10));
    expect(lgamma(5), closeTo(math.log(24), 1e-10));
    expect(lgamma(0.5), closeTo(0.5 * math.log(math.pi), 1e-10));
    expect(lgamma(101), closeTo(363.73937555556347, 1e-8));
  });

  test('chi-square survival function', () {
    expect(chiSquareSf(3.841458820694124, 1), closeTo(0.05, 1e-6));
    expect(chiSquareSf(30.14352720564616, 19), closeTo(0.05, 1e-6));
    expect(chiSquareSf(0, 5), 1.0);
  });

  test('perfectly even counts favour fairness', () {
    final f = FairnessResult(List.filled(6, 50));
    expect(f.chiSquare, 0);
    expect(f.pValue, closeTo(1, 1e-9));
    expect(f.log10Bf01, greaterThan(0.5));
  });

  test('loaded die is detected', () {
    final f = FairnessResult([10, 10, 10, 10, 10, 60]);
    expect(f.pValue, lessThan(1e-6));
    expect(f.log10Bf01, lessThan(-2));
    expect(f.verdict, Verdict.strongBiased);
  });

  test('trajectory endpoint equals closed form', () {
    final rng = math.Random(1);
    final faces = List.generate(500, (_) => rng.nextInt(20));
    final counts = List.filled(20, 0);
    for (final f in faces) {
      counts[f]++;
    }
    expect(bfTrajectory(faces, 20).last, closeTo(FairnessResult(counts).log10Bf01, 1e-8));
  });

  test('fair simulated d20 is mostly not flagged', () {
    final rng = math.Random(42);
    var flagged = 0;
    for (var t = 0; t < 200; t++) {
      final c = List.filled(20, 0);
      for (var i = 0; i < 400; i++) {
        c[rng.nextInt(20)]++;
      }
      if (FairnessResult(c).log10Bf01 < -1) flagged++;
    }
    expect(flagged, lessThan(4));
  });

  test('homogeneity: identical vs different conditions', () {
    final same = HomogeneityResult([
      [25, 25, 25, 25],
      [25, 25, 25, 25],
    ]);
    expect(same.log10Bf10, lessThan(0));
    expect(same.df, 3);
    final diff = HomogeneityResult([
      [70, 10, 10, 10],
      [10, 10, 10, 70],
    ]);
    expect(diff.log10Bf10, greaterThan(2));
    expect(diff.pValue, lessThan(1e-6));
  });

  test('hit rate', () {
    final chance = HitRateResult(hits: 10, n: 200, p0: 0.05);
    expect(chance.z, closeTo(0, 1e-9));
    expect(chance.log10Bf10, lessThan(0));
    final psi = HitRateResult(hits: 40, n: 200, p0: 0.05);
    expect(psi.log10Bf10, greaterThan(2));
    expect(psi.pOneSided, lessThan(1e-6));
  });

  test('wilson interval contains estimate', () {
    final (lo, hi) = wilson(3, 20);
    expect(lo, lessThan(0.15));
    expect(hi, greaterThan(0.15));
  });

  test('formatBf', () {
    expect(formatBf(1), '10.0:1');
    expect(formatBf(-2), '1:100');
  });

  test('moderately loaded d6 is flagged within a few hundred rolls', () {
    // Six comes up ~26% instead of 16.7%.
    final f = FairnessResult([36, 35, 36, 35, 36, 62]);
    expect(f.log10Bf01, lessThan(-0.5));
  });

  test('fair d20 after 340 rolls is not overclaimed', () {
    final rng = math.Random(3);
    final c = List.filled(20, 0);
    for (var i = 0; i < 340; i++) {
      c[rng.nextInt(20)]++;
    }
    expect(FairnessResult(c).pFair, lessThan(0.999));
  });
}
