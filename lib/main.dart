import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'charts.dart';
import 'die_screen.dart';
import 'model.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = Store();
  try {
    await store.load();
  } on MissingPluginException {
    // Not on Android: keep data in memory.
  }
  runApp(DiceCheckerApp(store: store));
}

class DiceCheckerApp extends StatelessWidget {
  const DiceCheckerApp({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Dice Checker',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: HomeScreen(store: store),
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('Кубики', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [_HomeMenu(store: store)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addDie(context),
        icon: const Icon(Icons.add),
        label: const Text('Кубик'),
      ),
      body: store.dice.isEmpty
          ? const _Empty()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: store.dice.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _DieCard(store: store, die: store.dice[i]),
            ),
    ),
  );

  Future<void> _addDie(BuildContext context) async {
    final result = await showModalBottomSheet<(String, DieType)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Palette.surface,
      builder: (_) => const _AddDieSheet(),
    );
    if (result == null || !context.mounted) return;
    final die = store.addDie(result.$1, result.$2);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DieScreen(store: store, die: die),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DieBadge(type: DieType.d20, size: 72),
          const SizedBox(height: 20),
          Text('Добавьте первый кубик', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'Каждый физический кубик — отдельная запись: так перекос одного не смешается с другим.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Palette.muted),
          ),
        ],
      ),
    ),
  );
}

class _DieCard extends StatelessWidget {
  const _DieCard({required this.store, required this.die});
  final Store store;
  final Die die;

  @override
  Widget build(BuildContext context) {
    final f = die.fairness;
    final vc = Palette.verdict(f.verdict);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DieScreen(store: store, die: die),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              DieBadge(type: die.type),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(die.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      '${f.n} бросков',
                      style: const TextStyle(color: Palette.muted, fontFeatures: tabular),
                    ),
                    const SizedBox(height: 10),
                    Histogram(
                      counts: f.counts,
                      labels: List.generate(die.type.faces, die.type.faceLabel),
                      showIntervals: false,
                      showLabels: false,
                      height: 34,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              VerdictPill(label: f.verdict.title, color: vc),
            ],
          ),
        ),
      ),
    );
  }
}

class VerdictPill extends StatelessWidget {
  const VerdictPill({super.key, required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
    ),
  );
}

/// Polygon silhouette roughly matching the die shape.
class DieBadge extends StatelessWidget {
  const DieBadge({super.key, required this.type, this.size = 52});
  final DieType type;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _BadgePainter(type),
      child: Center(
        child: Text(
          type.label,
          style: TextStyle(color: Palette.brass, fontWeight: FontWeight.w700, fontSize: size * 0.27),
        ),
      ),
    ),
  );
}

class _BadgePainter extends CustomPainter {
  _BadgePainter(this.type);
  final DieType type;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 1;
    final (sides, rot) = switch (type) {
      DieType.d4 => (3, -90.0),
      DieType.d6 => (4, 45.0),
      DieType.d8 => (4, 0.0),
      DieType.d10 || DieType.percentile => (4, 90.0),
      DieType.d20 => (6, 30.0),
    };
    final path = Path();
    for (var i = 0; i < sides; i++) {
      final a = (rot + 360 / sides * i) * 3.141592653589793 / 180;
      final sx = type == DieType.d10 || type == DieType.percentile ? 0.78 : 1.0;
      final p = c + Offset(r * sx * _cos(a), r * _sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas
      ..drawPath(path, Paint()..color = Palette.brass.withValues(alpha: 0.10))
      ..drawPath(
        path,
        Paint()
          ..color = Palette.brass.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeJoin = StrokeJoin.round,
      );
  }

  @override
  bool shouldRepaint(_BadgePainter old) => old.type != type;
}

double _cos(double a) => Offset.fromDirection(a).dx;
double _sin(double a) => Offset.fromDirection(a).dy;

class _AddDieSheet extends StatefulWidget {
  const _AddDieSheet();

  @override
  State<_AddDieSheet> createState() => _AddDieSheetState();
}

class _AddDieSheetState extends State<_AddDieSheet> {
  DieType type = DieType.d20;
  final name = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Новый кубик', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final t in DieType.values)
              GestureDetector(
                onTap: () => setState(() => type = t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: t == type ? Palette.brass : Palette.line, width: t == type ? 2 : 1),
                    color: t == type ? Palette.brass.withValues(alpha: 0.08) : null,
                  ),
                  child: DieBadge(type: t, size: 48),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: name,
          autofocus: false,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Название',
            hintText: 'например, «Красный ${type.label}»',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              final n = name.text.trim();
              Navigator.pop(context, (n.isEmpty ? type.label : n, type));
            },
            child: const Padding(padding: EdgeInsets.all(12), child: Text('Добавить')),
          ),
        ),
      ],
    ),
  );
}

class _HomeMenu extends StatelessWidget {
  const _HomeMenu({required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    onSelected: (v) async {
      final messenger = ScaffoldMessenger.of(context);
      switch (v) {
        case 'csv':
          await Clipboard.setData(ClipboardData(text: store.exportCsv()));
          messenger.showSnackBar(const SnackBar(content: Text('CSV скопирован в буфер обмена')));
        case 'backup':
          await Clipboard.setData(ClipboardData(text: store.exportJson()));
          messenger.showSnackBar(const SnackBar(content: Text('Резервная копия (JSON) в буфере обмена')));
        case 'restore':
          final data = await Clipboard.getData(Clipboard.kTextPlain);
          if (!context.mounted) return;
          final ok = await confirm(context, 'Восстановить из буфера?', 'Текущие данные будут заменены.');
          if (!ok) return;
          try {
            store.importJson(data?.text ?? '');
            messenger.showSnackBar(const SnackBar(content: Text('Восстановлено')));
          } catch (_) {
            messenger.showSnackBar(const SnackBar(content: Text('В буфере нет корректной резервной копии')));
          }
      }
    },
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'csv', child: Text('Экспорт CSV в буфер')),
      PopupMenuItem(value: 'backup', child: Text('Резервная копия в буфер')),
      PopupMenuItem(value: 'restore', child: Text('Восстановить из буфера')),
    ],
  );
}

Future<bool> confirm(BuildContext context, String title, String body) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Да')),
        ],
      ),
    ) ??
    false;
