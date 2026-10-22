import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'stats.dart';

enum DieType {
  d4('d4', 4),
  d6('d6', 6),
  d8('d8', 8),
  d10('d10', 10),
  percentile('d%', 10),
  d20('d20', 20);

  const DieType(this.label, this.faces);
  final String label;
  final int faces;

  /// Label printed on face [i] (0-based index).
  String faceLabel(int i) => switch (this) {
    DieType.d10 => '${(i + 1) % 10}',
    DieType.percentile => ((i + 1) % 10 * 10).toString().padLeft(2, '0'),
    _ => '${i + 1}',
  };

  int get gridColumns => switch (this) {
    DieType.d4 => 2,
    DieType.d6 => 3,
    DieType.d8 => 4,
    DieType.d10 || DieType.percentile => 5,
    DieType.d20 => 4,
  };
}

class Roll {
  Roll({required this.face, required this.at, this.condition, this.target});

  final int face;
  final DateTime at;
  final String? condition;
  final int? target;

  Map<String, dynamic> toJson() => {
    'f': face,
    't': at.millisecondsSinceEpoch,
    if (condition != null) 'c': condition,
    if (target != null) 'g': target,
  };

  factory Roll.fromJson(Map<String, dynamic> j) => Roll(
    face: j['f'] as int,
    at: DateTime.fromMillisecondsSinceEpoch(j['t'] as int),
    condition: j['c'] as String?,
    target: j['g'] as int?,
  );
}

class Die {
  Die({required this.id, required this.name, required this.type, List<Roll>? rolls}) : rolls = rolls ?? [];

  final String id;
  String name;
  final DieType type;
  final List<Roll> rolls;

  // Ephemeral input state.
  String? condition;
  int? target;
  bool autoTarget = false;

  List<int> counts({String? condition, bool allConditions = true}) {
    final c = List<int>.filled(type.faces, 0);
    for (final r in rolls) {
      if (!allConditions && r.condition != condition) continue;
      c[r.face]++;
    }
    return c;
  }

  FairnessResult get fairness => FairnessResult(counts());

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'rolls': rolls.map((r) => r.toJson()).toList(),
    if (condition != null) 'cond': condition,
    'auto': autoTarget,
  };

  factory Die.fromJson(Map<String, dynamic> j) =>
      Die(
          id: j['id'] as String,
          name: j['name'] as String,
          type: DieType.values.byName(j['type'] as String),
          rolls: (j['rolls'] as List).map((r) => Roll.fromJson(r as Map<String, dynamic>)).toList(),
        )
        ..condition = j['cond'] as String?
        ..autoTarget = j['auto'] as bool? ?? false;
}

class Store extends ChangeNotifier {
  static const _channel = MethodChannel('dice_checker/storage');
  final _rng = math.Random.secure();

  final List<Die> dice = [];
  final List<String> conditions = ['Нейтрально', 'Намерение'];
  File? _file;
  Future<void> _pending = Future.value();

  /// Loads data from the app's private files directory (provided by
  /// MainActivity). Without it (tests, other platforms) data is in-memory only.
  Future<void> load() async {
    final dir = await _channel.invokeMethod<String>('filesDir');
    if (dir == null) return;
    final file = _file = File('$dir/dice_checker.json');
    if (!await file.exists()) return;
    _fromJson(jsonDecode(await file.readAsString()) as Map<String, dynamic>);
  }

  void _fromJson(Map<String, dynamic> j) {
    final imported = (j['dice'] as List).map((d) => Die.fromJson(d as Map<String, dynamic>)).toList();
    final conds = (j['conditions'] as List).cast<String>();
    dice
      ..clear()
      ..addAll(imported);
    conditions
      ..clear()
      ..addAll(conds);
  }

  void _save() {
    notifyListeners();
    final file = _file;
    if (file == null) return;
    final data = exportJson();
    // Serialize writes; write-then-rename so a crash never leaves a torn file.
    _pending = _pending
        .then((_) async {
          final tmp = File('${file.path}.tmp');
          await tmp.writeAsString(data, flush: true);
          await tmp.rename(file.path);
        })
        .catchError((Object e) => debugPrint('save failed: $e'));
  }

  Die addDie(String name, DieType type) {
    final d = Die(id: DateTime.now().microsecondsSinceEpoch.toRadixString(36), name: name, type: type);
    dice.add(d);
    _save();
    return d;
  }

  void renameDie(Die d, String name) {
    d.name = name;
    _save();
  }

  void deleteDie(Die d) {
    dice.remove(d);
    _save();
  }

  void clearRolls(Die d) {
    d.rolls.clear();
    _save();
  }

  void record(Die d, int face) {
    d.rolls.add(Roll(face: face, at: DateTime.now(), condition: d.condition, target: d.target));
    if (d.autoTarget) d.target = _rng.nextInt(d.type.faces);
    _save();
  }

  Roll? undo(Die d) {
    if (d.rolls.isEmpty) return null;
    final r = d.rolls.removeLast();
    _save();
    return r;
  }

  void setCondition(Die d, String? c) {
    d.condition = c;
    _save();
  }

  void setTarget(Die d, int? t) {
    d.target = t;
    notifyListeners();
  }

  /// Picks a target with a cryptographically secure RNG, so that any physical
  /// bias of the die averages out over targets.
  void randomTarget(Die d) => setTarget(d, _rng.nextInt(d.type.faces));

  void setAutoTarget(Die d, bool v) {
    d.autoTarget = v;
    if (v) d.target ??= _rng.nextInt(d.type.faces);
    _save();
  }

  void addCondition(String c) {
    if (c.isEmpty || conditions.contains(c)) return;
    conditions.add(c);
    _save();
  }

  void removeCondition(String c) {
    conditions.remove(c);
    for (final d in dice) {
      if (d.condition == c) d.condition = null;
    }
    _save();
  }

  String exportCsv() {
    final b = StringBuffer('die_id,die_name,die_type,timestamp,face,face_label,condition,target,target_label\n');
    String q(String s) => '"${s.replaceAll('"', '""')}"';
    for (final d in dice) {
      for (final r in d.rolls) {
        b.writeln(
          [
            d.id,
            q(d.name),
            d.type.label,
            r.at.toIso8601String(),
            r.face,
            d.type.faceLabel(r.face),
            q(r.condition ?? ''),
            r.target ?? '',
            r.target == null ? '' : d.type.faceLabel(r.target!),
          ].join(','),
        );
      }
    }
    return b.toString();
  }

  String exportJson() => jsonEncode({'dice': dice.map((d) => d.toJson()).toList(), 'conditions': conditions});

  void importJson(String raw) {
    _fromJson(jsonDecode(raw) as Map<String, dynamic>);
    _save();
  }
}
