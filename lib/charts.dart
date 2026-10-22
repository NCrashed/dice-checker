import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'stats.dart';
import 'theme.dart';

/// Bar chart of face frequencies with expected line and Wilson 95% whiskers.
class Histogram extends StatelessWidget {
  const Histogram({
    super.key,
    required this.counts,
    required this.labels,
    this.highlight,
    this.showIntervals = true,
    this.showLabels = true,
    this.color = Palette.brass,
    this.height = 180,
  });

  final List<int> counts;
  final List<String> labels;
  final int? highlight;
  final bool showIntervals;
  final bool showLabels;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => CustomPaint(
        size: Size.infinite,
        painter: _HistogramPainter(
          counts: counts,
          labels: labels,
          highlight: highlight,
          showIntervals: showIntervals,
          showLabels: showLabels,
          color: color,
          t: t,
        ),
      ),
    ),
  );
}

class _HistogramPainter extends CustomPainter {
  _HistogramPainter({
    required this.counts,
    required this.labels,
    required this.highlight,
    required this.showIntervals,
    required this.showLabels,
    required this.color,
    required this.t,
  });

  final List<int> counts;
  final List<String> labels;
  final int? highlight;
  final bool showIntervals;
  final bool showLabels;
  final Color color;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final k = counts.length;
    final n = counts.fold<int>(0, (s, c) => s + c);
    final labelH = showLabels ? 18.0 : 0.0;
    final chartH = size.height - labelH;
    final p0 = 1 / k;

    // Proportion scale: fit bars, intervals and expected line.
    var maxP = p0 * 1.6;
    for (var i = 0; i < k; i++) {
      if (n == 0) break;
      final hi = showIntervals ? wilson(counts[i], n).$2 : counts[i] / n;
      maxP = math.max(maxP, hi);
    }
    maxP = math.min(maxP * 1.05, 1.0);
    double y(double p) => chartH - p / maxP * chartH;

    final slot = size.width / k;
    final barW = math.max(slot * 0.62, 2.0);
    final barPaint = Paint();
    final whisker = Paint()
      ..color = Palette.text.withValues(alpha: 0.55)
      ..strokeWidth = 1.2;

    for (var i = 0; i < k; i++) {
      final cx = slot * (i + 0.5);
      final p = n == 0 ? 0.0 : counts[i] / n;
      final top = y(p * t);
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTRB(cx - barW / 2, top, cx + barW / 2, chartH),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );
      barPaint.color = i == highlight ? Palette.text : color.withValues(alpha: 0.85);
      canvas.drawRRect(rect, barPaint);

      if (showIntervals && n > 0) {
        final (lo, hi) = wilson(counts[i], n);
        final w = barW * 0.25;
        canvas
          ..drawLine(Offset(cx, y(lo)), Offset(cx, y(hi)), whisker)
          ..drawLine(Offset(cx - w, y(lo)), Offset(cx + w, y(lo)), whisker)
          ..drawLine(Offset(cx - w, y(hi)), Offset(cx + w, y(hi)), whisker);
      }

      if (showLabels && (k <= 10 || i % 2 == 0 || i == k - 1)) {
        _text(canvas, labels[i], Offset(cx, chartH + 3), Palette.muted, 11);
      }
    }

    // Expected frequency line.
    final ey = y(p0);
    final dash = Paint()
      ..color = Palette.fair
      ..strokeWidth = 1.4;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, ey), Offset(math.min(x + 4, size.width), ey), dash);
    }
    canvas.drawLine(Offset(0, chartH), Offset(size.width, chartH), Paint()..color = Palette.line);
  }

  @override
  bool shouldRepaint(_HistogramPainter old) => old.t != t || old.highlight != highlight || !_listEq(old.counts, counts);
}

/// Running log10 Bayes factor with evidence bands.
class TrajectoryChart extends StatelessWidget {
  const TrajectoryChart({super.key, required this.values, this.height = 170});

  final List<double> values;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: CustomPaint(size: Size.infinite, painter: _TrajectoryPainter(values)),
  );
}

class _TrajectoryPainter extends CustomPainter {
  _TrajectoryPainter(this.values);
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 30.0;
    final w = size.width - left;
    final h = size.height;
    var lo = -2.0, hi = 2.0;
    for (final v in values) {
      lo = math.min(lo, v);
      hi = math.max(hi, v);
    }
    lo = (lo - 0.3).floorToDouble();
    hi = (hi + 0.3).ceilToDouble();
    double y(double v) => h - (v - lo) / (hi - lo) * h;

    // Bands: green above +0.5 (fair), red below −0.5 (biased).
    canvas
      ..drawRect(Rect.fromLTRB(left, y(hi), size.width, y(0.5)), Paint()..color = Palette.fair.withValues(alpha: 0.08))
      ..drawRect(
        Rect.fromLTRB(left, y(-0.5), size.width, y(lo)),
        Paint()..color = Palette.bias.withValues(alpha: 0.08),
      );

    final grid = Paint()
      ..color = Palette.line
      ..strokeWidth = 1;
    final step = (hi - lo) > 8 ? 2.0 : 1.0;
    for (var v = lo; v <= hi; v += step) {
      canvas.drawLine(Offset(left, y(v)), Offset(size.width, y(v)), grid);
      _text(canvas, v.toStringAsFixed(0), Offset(left / 2 - 2, y(v) - 7), Palette.muted, 10);
    }
    canvas.drawLine(
      Offset(left, y(0)),
      Offset(size.width, y(0)),
      Paint()
        ..color = Palette.muted
        ..strokeWidth = 1,
    );

    if (values.isEmpty) return;
    final path = Path()..moveTo(left, y(0));
    final n = values.length;
    for (var i = 0; i < n; i++) {
      path.lineTo(left + (i + 1) / n * w, y(values[i]));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Palette.brass
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(Offset(size.width, y(values.last)), 3.5, Paint()..color = Palette.brass);
  }

  @override
  bool shouldRepaint(_TrajectoryPainter old) => !_listEq(old.values, values);
}

/// Horizontal interval plot: point estimate with CI against a reference.
class IntervalBar extends StatelessWidget {
  const IntervalBar({
    super.key,
    required this.value,
    required this.lo,
    required this.hi,
    required this.reference,
    required this.color,
  });

  final double value, lo, hi, reference;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 22,
    child: CustomPaint(size: Size.infinite, painter: _IntervalPainter(value, lo, hi, reference, color)),
  );
}

class _IntervalPainter extends CustomPainter {
  _IntervalPainter(this.value, this.lo, this.hi, this.reference, this.color);
  final double value, lo, hi, reference;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = math.min(1.0, math.max(hi, reference * 2.5) * 1.1);
    double x(double v) => v / maxV * size.width;
    final cy = size.height / 2;
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTRB(0, cy - 3, size.width, cy + 3), const Radius.circular(3)),
        Paint()..color = Palette.surfaceHigh,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTRB(x(lo), cy - 3, x(hi), cy + 3), const Radius.circular(3)),
        Paint()..color = color.withValues(alpha: 0.45),
      )
      ..drawLine(
        Offset(x(reference), 2),
        Offset(x(reference), size.height - 2),
        Paint()
          ..color = Palette.fair
          ..strokeWidth = 2,
      )
      ..drawCircle(Offset(x(value), cy), 5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_IntervalPainter old) =>
      old.value != value || old.lo != lo || old.hi != hi || old.reference != reference;
}

void _text(Canvas canvas, String s, Offset topCenter, Color color, double size) {
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(fontFamily: 'Roboto', color: color, fontSize: size, fontFeatures: tabular),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, Offset(topCenter.dx - tp.width / 2, topCenter.dy));
}

bool _listEq<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
