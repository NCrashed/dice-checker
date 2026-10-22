import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'charts.dart';
import 'main.dart' show VerdictPill, confirm;
import 'model.dart';
import 'stats.dart';
import 'theme.dart';

class DieScreen extends StatelessWidget {
  const DieScreen({super.key, required this.store, required this.die});
  final Store store;
  final Die die;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text('${die.name} · ${die.type.label}'),
          actions: [_DieMenu(store: store, die: die)],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Броски'),
              Tab(text: 'Честность'),
              Tab(text: 'Сознание'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _RollTab(store: store, die: die),
            _FairnessTab(die: die),
            _MindTab(die: die),
          ],
        ),
      ),
    ),
  );
}

class _DieMenu extends StatelessWidget {
  const _DieMenu({required this.store, required this.die});
  final Store store;
  final Die die;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    onSelected: (v) async {
      switch (v) {
        case 'rename':
          final name = await _prompt(context, 'Название', die.name);
          if (name != null && name.isNotEmpty) store.renameDie(die, name);
        case 'clear':
          if (await confirm(context, 'Очистить броски?', 'Все ${die.rolls.length} бросков будут удалены.')) {
            store.clearRolls(die);
          }
        case 'delete':
          if (await confirm(context, 'Удалить кубик?', 'Кубик и все его броски будут удалены.')) {
            store.deleteDie(die);
            if (context.mounted) Navigator.pop(context);
          }
      }
    },
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'rename', child: Text('Переименовать')),
      PopupMenuItem(value: 'clear', child: Text('Очистить броски')),
      PopupMenuItem(value: 'delete', child: Text('Удалить кубик')),
    ],
  );
}

Future<String?> _prompt(BuildContext context, String title, [String initial = '']) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('OK')),
      ],
    ),
  ).whenComplete(c.dispose);
}

// ───────────────────────────── Roll input ─────────────────────────────

class _RollTab extends StatefulWidget {
  const _RollTab({required this.store, required this.die});
  final Store store;
  final Die die;

  @override
  State<_RollTab> createState() => _RollTabState();
}

class _RollTabState extends State<_RollTab> {
  int? flash;

  Store get store => widget.store;
  Die get die => widget.die;

  void _tap(int face) {
    HapticFeedback.lightImpact();
    store.record(die, face);
    setState(() => flash = face);
    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted && flash == face) setState(() => flash = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final f = die.fairness;
    final type = die.type;
    final last = die.rolls.isEmpty ? null : die.rolls.last;
    return Column(
      children: [
        _ConditionBar(store: store, die: die),
        _TargetBar(store: store, die: die),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: LayoutBuilder(
              builder: (context, box) {
                final cols = type.gridColumns;
                final rows = (type.faces / cols).ceil();
                const gap = 8.0;
                final cellW = (box.maxWidth - gap * (cols - 1)) / cols;
                final cellH = math.min((box.maxHeight - gap * (rows - 1)) / rows, cellW * 1.1);
                return Align(
                  alignment: Alignment.topCenter,
                  child: Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (var i = 0; i < type.faces; i++)
                        SizedBox(
                          width: cellW,
                          height: cellH,
                          child: _FaceButton(
                            label: type.faceLabel(i),
                            count: f.counts[i],
                            isTarget: die.target == i,
                            flashing: flash == i,
                            onTap: () => _tap(i),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        _StatusStrip(
          fairness: f,
          lastLabel: last == null ? null : type.faceLabel(last.face),
          onUndo: last == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  store.undo(die);
                },
        ),
      ],
    );
  }
}

class _FaceButton extends StatelessWidget {
  const _FaceButton({
    required this.label,
    required this.count,
    required this.isTarget,
    required this.flashing,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool isTarget;
  final bool flashing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    decoration: BoxDecoration(
      color: flashing ? Palette.brass.withValues(alpha: 0.35) : Palette.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: isTarget ? Palette.brass : Palette.line, width: isTarget ? 2 : 1),
    ),
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Stack(
          children: [
            Center(
              child: FittedBox(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                      color: isTarget ? Palette.brass : Palette.text,
                      fontFeatures: tabular,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 5,
              child: Text(
                '$count',
                style: const TextStyle(fontSize: 11, color: Palette.muted, fontFeatures: tabular),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ConditionBar extends StatelessWidget {
  const _ConditionBar({required this.store, required this.die});
  final Store store;
  final Die die;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      children: [
        _chip('Без метки', die.condition == null, () => store.setCondition(die, null)),
        for (final c in store.conditions)
          GestureDetector(
            onLongPress: () async {
              if (await confirm(context, 'Удалить состояние «$c»?', 'Уже записанные броски сохранят эту метку.')) {
                store.removeCondition(c);
              }
            },
            child: _chip(c, die.condition == c, () => store.setCondition(die, c)),
          ),
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: const Text('Состояние'),
            onPressed: () async {
              final c = await _prompt(context, 'Новое состояние сознания');
              if (c != null && c.isNotEmpty) {
                store.addCondition(c);
                store.setCondition(die, c);
              }
            },
          ),
        ),
      ],
    ),
  );

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap(), showCheckmark: false),
  );
}

class _TargetBar extends StatelessWidget {
  const _TargetBar({required this.store, required this.die});
  final Store store;
  final Die die;

  @override
  Widget build(BuildContext context) {
    final t = die.target;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(
        children: [
          const Text('Цель', style: TextStyle(color: Palette.muted)),
          const SizedBox(width: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: Text(
              t == null ? '—' : die.type.faceLabel(t),
              key: ValueKey('${t}_${die.rolls.length}'),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: t == null ? Palette.muted : Palette.brass,
                fontFeatures: tabular,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Случайная цель',
            icon: const Icon(Icons.casino_outlined),
            onPressed: () => store.randomTarget(die),
          ),
          if (t != null)
            IconButton(
              tooltip: 'Без цели',
              icon: const Icon(Icons.close),
              onPressed: () {
                store.setAutoTarget(die, false);
                store.setTarget(die, null);
              },
            ),
          const Spacer(),
          const Text('новая после броска', style: TextStyle(color: Palette.muted, fontSize: 12)),
          Switch(value: die.autoTarget, onChanged: (v) => store.setAutoTarget(die, v)),
        ],
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.fairness, required this.lastLabel, required this.onUndo});
  final FairnessResult fairness;
  final String? lastLabel;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final f = fairness;
    final vc = Palette.verdict(f.verdict);
    return Container(
      decoration: const BoxDecoration(
        color: Palette.surface,
        border: Border(top: BorderSide(color: Palette.line)),
      ),
      padding: EdgeInsets.fromLTRB(16, 10, 8, 10 + MediaQuery.paddingOf(context).bottom),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${f.n}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, fontFeatures: tabular),
              ),
              const Text('бросков', style: TextStyle(color: Palette.muted, fontSize: 11)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                VerdictPill(label: f.verdict.title, color: vc),
                const SizedBox(height: 4),
                Text(
                  f.n == 0
                      ? 'нажимайте на выпавшую грань'
                      : 'P(честный) ${formatPercent(f.pFair)} · BF ${formatBf(f.log10Bf01)}',
                  style: const TextStyle(color: Palette.muted, fontSize: 12, fontFeatures: tabular),
                ),
              ],
            ),
          ),
          if (lastLabel != null)
            TextButton.icon(
              onPressed: onUndo,
              icon: const Icon(Icons.undo, size: 18),
              label: Text('отменить $lastLabel'),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Fairness ─────────────────────────────

class _FairnessTab extends StatelessWidget {
  const _FairnessTab({required this.die});
  final Die die;

  @override
  Widget build(BuildContext context) {
    final f = die.fairness;
    final type = die.type;
    final labels = List.generate(type.faces, type.faceLabel);
    final traj = bfTrajectory(die.rolls.map((r) => r.face), type.faces);
    final vc = Palette.verdict(f.verdict);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Section(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                f.verdict.title,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: vc),
              ),
              const SizedBox(height: 2),
              Text(f.verdict.description, style: const TextStyle(color: Palette.muted)),
              const SizedBox(height: 16),
              Row(
                children: [
                  _Metric('бросков', '${f.n}'),
                  _Metric('P(честный)', f.n == 0 ? '—' : formatPercent(f.pFair)),
                  _Metric('BF чест./перекос', f.n == 0 ? '—' : formatBf(f.log10Bf01)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Metric('χ²', f.n == 0 ? '—' : f.chiSquare.toStringAsFixed(2)),
                  _Metric('ст. свободы', '${f.k - 1}'),
                  _Metric('p-value', f.n == 0 ? '—' : formatP(f.pValue)),
                ],
              ),
              if (f.n > 0) ...[
                const SizedBox(height: 12),
                Text(
                  'При ${f.n} бросках различим перекос грани примерно от ±${(f.detectableBias * 100).toStringAsFixed(0)}% '
                  'от её честной вероятности; меньшие перекосы пока не видны. '
                  '${f.chiSquareReliable ? '' : 'χ² надёжен от ~${f.recommendedRolls} бросков.'}',
                  style: const TextStyle(color: Palette.muted, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Частоты граней',
          subtitle: 'Столбик — доля, усы — 95% интервал, пунктир — ожидаемое 1/${f.k}',
          child: Histogram(counts: f.counts, labels: labels),
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Накопление свидетельств',
          subtitle:
              'log₁₀ BF после каждого броска: выше +0.5 — за честность, ниже −0.5 — за перекос. '
              'Можно останавливаться в любой момент — байесов фактор от этого не портится.',
          child: TrajectoryChart(values: traj),
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'По граням',
          subtitle: 'Отклонение z = (наблюдено − ожидалось)/√ожидалось; |z| > 2 выделено',
          child: Column(
            children: [
              for (var i = 0; i < f.k; i++) _FaceRow(label: labels[i], count: f.counts[i], n: f.n, z: f.residual(i)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _Section(
          title: 'Как это считается',
          child: Text(
            'Байесов фактор сравнивает две гипотезы: «все грани равновероятны» и «вероятности граней '
            'отклоняются от 1/k» (априор Дирихле с типичным отклонением ±15%). Он обновляется с каждым броском и остаётся корректным, '
            'даже если вы смотрите на результат постоянно и останавливаетесь когда захочется.\n\n'
            'p-value критерия χ² приведён для сравнения. Учтите: если проверять его после каждого броска '
            'и остановиться, как только p < 0.05, ложные срабатывания будут гораздо чаще 5%.\n\n'
            'Бросайте одинаково: на ту же поверхность, с той же высоты, с перемешиванием в руке/стакане.',
            style: TextStyle(color: Palette.muted, height: 1.4),
          ),
        ),
      ],
    );
  }
}

class _FaceRow extends StatelessWidget {
  const _FaceRow({required this.label, required this.count, required this.n, required this.z});
  final String label;
  final int count, n;
  final double z;

  @override
  Widget build(BuildContext context) {
    final hot = z.abs() > 2;
    final zc = hot ? (z > 0 ? Palette.bias : Palette.fair) : Palette.muted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontFeatures: tabular),
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: const TextStyle(fontFeatures: tabular),
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              n == 0 ? '' : '${(count / n * 100).toStringAsFixed(1)}%',
              textAlign: TextAlign.right,
              style: const TextStyle(color: Palette.muted, fontFeatures: tabular),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _ZBar(z: z, color: zc),
          ),
          SizedBox(
            width: 48,
            child: Text(
              z.toStringAsFixed(1),
              textAlign: TextAlign.right,
              style: TextStyle(color: zc, fontWeight: hot ? FontWeight.w700 : null, fontFeatures: tabular),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZBar extends StatelessWidget {
  const _ZBar({required this.z, required this.color});
  final double z;
  final Color color;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final half = box.maxWidth / 2;
      final w = (z.abs() / 4).clamp(0.0, 1.0) * half;
      return SizedBox(
        height: 8,
        child: Stack(
          children: [
            Positioned(
              left: half - 0.5,
              top: 0,
              bottom: 0,
              child: Container(width: 1, color: Palette.line),
            ),
            Positioned(
              left: z >= 0 ? half : half - w,
              width: w,
              top: 1,
              bottom: 1,
              child: Container(
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
              ),
            ),
          ],
        ),
      );
    },
  );
}

// ───────────────────────────── Mind experiment ─────────────────────────────

class _MindTab extends StatelessWidget {
  const _MindTab({required this.die});
  final Die die;

  @override
  Widget build(BuildContext context) {
    final type = die.type;
    final k = type.faces;
    final labels = List.generate(k, type.faceLabel);

    // Group by condition, preserving first-seen order; null → "Без метки".
    final groups = <String?, List<Roll>>{};
    for (final r in die.rolls) {
      groups.putIfAbsent(r.condition, () => []).add(r);
    }
    final names = groups.keys.toList();
    final tables = [for (final c in names) die.counts(condition: c, allConditions: false)];
    final homo = HomogeneityResult(tables);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _Section(
          title: 'Протокол',
          child: Text(
            '1. Перед серией выберите состояние (метка сверху на вкладке «Броски»).\n'
            '2. Включите «новая после броска»: цель выбирается криптографически случайно, '
            'поэтому перекос самого кубика не создаёт ложных «попаданий».\n'
            '3. Чередуйте состояния блоками (например, по 20 бросков), включая «Нейтрально» как контроль.\n'
            '4. Заранее решите, сколько бросков сделаете, и что будете считать эффектом.',
            style: TextStyle(color: Palette.muted, height: 1.45),
          ),
        ),
        const SizedBox(height: 12),
        if (names.length < 2)
          const _Section(
            title: 'Сравнение состояний',
            child: Text('Нужны броски хотя бы в двух разных состояниях.', style: TextStyle(color: Palette.muted)),
          )
        else
          _Section(
            title: 'Различаются ли распределения граней?',
            subtitle: 'Своё распределение у каждого состояния против одного общего',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Metric('BF разл./одинак.', formatBf(homo.log10Bf10), color: Palette.evidence(homo.log10Bf10)),
                    _Metric('χ² (df ${homo.df})', homo.chiSquare.toStringAsFixed(1)),
                    _Metric('p-value', formatP(homo.pValue)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _homoText(homo.log10Bf10) +
                      (homo.minExpected < 5 ? '\nχ² пока ненадёжен: мало бросков на грань в каждом состоянии.' : ''),
                  style: const TextStyle(color: Palette.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        for (var i = 0; i < names.length; i++) ...[
          const SizedBox(height: 12),
          _ConditionCard(
            name: names[i] ?? 'Без метки',
            rolls: groups[names[i]]!,
            counts: tables[i],
            labels: labels,
            k: k,
          ),
        ],
      ],
    );
  }

  static String _homoText(double l) {
    if (l >= 1) return 'Сильные свидетельства, что в разных состояниях выпадает по-разному.';
    if (l >= 0.5) return 'Умеренные свидетельства различия между состояниями.';
    if (l <= -1) return 'Сильные свидетельства, что состояние не влияет на распределение.';
    if (l <= -0.5) return 'Умеренные свидетельства отсутствия влияния.';
    return 'Пока не ясно — продолжайте бросать.';
  }
}

class _ConditionCard extends StatelessWidget {
  const _ConditionCard({
    required this.name,
    required this.rolls,
    required this.counts,
    required this.labels,
    required this.k,
  });
  final String name;
  final List<Roll> rolls;
  final List<int> counts;
  final List<String> labels;
  final int k;

  @override
  Widget build(BuildContext context) {
    final targeted = rolls.where((r) => r.target != null).toList();
    final hits = targeted.where((r) => r.face == r.target).length;
    final hr = HitRateResult(hits: hits, n: targeted.length, p0: 1 / k);
    final (lo, hi) = hr.ci;
    final ec = Palette.evidence(hr.log10Bf10);
    return _Section(
      title: name,
      subtitle: '${rolls.length} бросков',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Histogram(counts: counts, labels: labels, height: 110, showIntervals: false),
          if (targeted.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Попадания в цель', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                _Metric('попаданий', '$hits / ${targeted.length}'),
                _Metric('доля', '${(hr.rate * 100).toStringAsFixed(1)}%'),
                _Metric('случайно', '${(100 / k).toStringAsFixed(1)}%'),
              ],
            ),
            const SizedBox(height: 10),
            IntervalBar(value: hr.rate, lo: lo, hi: hi, reference: 1 / k, color: ec),
            const SizedBox(height: 10),
            Row(
              children: [
                _Metric('BF эффект/шанс', formatBf(hr.log10Bf10), color: ec),
                _Metric('z', hr.z.toStringAsFixed(2)),
                _Metric('p (одностор.)', formatP(hr.pOneSided)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────────── Shared bits ─────────────────────────────

class _Section extends StatelessWidget {
  const _Section({this.title, this.subtitle, required this.child});
  final String? title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) Text(title!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: const TextStyle(color: Palette.muted, fontSize: 12, height: 1.35)),
          ],
          if (title != null || subtitle != null) const SizedBox(height: 14),
          child,
        ],
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, {this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: color, fontFeatures: tabular),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Palette.muted, fontSize: 11)),
      ],
    ),
  );
}
