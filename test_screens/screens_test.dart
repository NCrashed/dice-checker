// Renders app screens to PNG for visual review without a device:
//   SCREEN_FONT_DIR=/path/to/ttf flutter test test_screens --update-goldens
import 'dart:io';
import 'dart:math' as math;

import 'package:dice_checker/die_screen.dart';
import 'package:dice_checker/main.dart';
import 'package:dice_checker/model.dart';
import 'package:dice_checker/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadFonts() async {
  final dir = Platform.environment['SCREEN_FONT_DIR'];
  if (dir != null) {
    final loader = FontLoader('Roboto')
      ..addFont(File('$dir/LiberationSans-Regular.ttf').readAsBytes().then(ByteData.sublistView))
      ..addFont(File('$dir/LiberationSans-Bold.ttf').readAsBytes().then(ByteData.sublistView));
    await loader.load();
  }
  final icons = Platform.environment['SCREEN_ICON_FONT'];
  if (icons != null) {
    await (FontLoader('MaterialIcons')..addFont(File(icons).readAsBytes().then(ByteData.sublistView))).load();
  }
}

Store _sample() {
  final s = Store();
  final rng = math.Random(7);
  final d20 = s.addDie('Красный d20', DieType.d20);
  for (var i = 0; i < 340; i++) {
    d20.condition = i % 40 < 20 ? 'Нейтрально' : 'Намерение';
    d20.target = rng.nextInt(20);
    s.record(d20, rng.nextInt(20));
  }
  d20
    ..condition = 'Намерение'
    ..autoTarget = true
    ..target = 16;
  final d6 = s.addDie('Казино d6', DieType.d6);
  for (var i = 0; i < 240; i++) {
    final x = rng.nextDouble();
    s.record(d6, x < 0.26 ? 5 : rng.nextInt(5));
  }
  s.addDie('Процентник', DieType.percentile);
  return s;
}

void main() {
  setUpAll(() async {
    await _loadFonts();
  });

  Future<void> shoot(WidgetTester tester, Widget home, String name, {int tab = 0, bool tall = false}) async {
    tester.view.physicalSize = Size(1080, tall ? 5600 : 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner: false, theme: buildTheme(), home: home));
    await tester.pumpAndSettle();
    if (tab > 0) {
      DefaultTabController.of(tester.element(find.byType(TabBarView))).animateTo(tab, duration: Duration.zero);
      await tester.pumpAndSettle();
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/$name.png'));
  }

  testWidgets('home', (t) async {
    final s = _sample();
    await shoot(t, HomeScreen(store: s), 'home');
  });
  for (final (i, name) in ['roll', 'fairness', 'mind'].indexed) {
    testWidgets(name, (t) async {
      final s = _sample();
      await shoot(
        t,
        DieScreen(store: s, die: s.dice[0]),
        'd20_$name',
        tab: i,
        tall: i > 0,
      );
    });
  }
  testWidgets('d6 fairness', (t) async {
    final s = _sample();
    await shoot(t, DieScreen(store: s, die: s.dice[1]), 'd6_fairness', tab: 1);
  });
  testWidgets('percentile roll', (t) async {
    final s = _sample();
    await shoot(t, DieScreen(store: s, die: s.dice[2]), 'pct_roll');
  });
}
