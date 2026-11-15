import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ofc_app/main.dart';
import 'package:ofc_app/screens/pass_play_result_screen.dart';

Finder rowLabel(String row) => find.bySemanticsLabel(RegExp('^Place in $row'));

void main() {
  testWidgets('pass & play opens on Player A with five cards and named rows',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const OfcApp());
    await tester.tap(find.text('Pass & Play (A/B)'));
    await tester.pumpAndSettle();

    expect(find.text('Turn: Player A'), findsOneWidget);
    expect(find.text('Status: Dealt A/B'), findsOneWidget);
    expect(find.text('Tray (5)'), findsOneWidget);
    for (final row in ['Top', 'Middle', 'Bottom']) {
      expect(rowLabel(row), findsOneWidget);
    }
    semantics.dispose();
  });

  testWidgets('two players tap their way to the result screen', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const OfcApp());
    await tester.tap(find.text('Pass & Play (A/B)'));
    await tester.pumpAndSettle();

    final placed = {'A': <String, int>{}, 'B': <String, int>{}};
    const capacity = {'Bottom': 5, 'Middle': 5, 'Top': 3};
    for (var turn = 0;
        turn < 20 && find.byType(PassPlayResultScreen).evaluate().isEmpty;
        turn++) {
      final player =
          find.text('Turn: Player A').evaluate().isNotEmpty ? 'A' : 'B';
      final counts = placed[player]!;
      final tray = find.bySemanticsLabel(RegExp(r' of |^Joker$'));
      final traySize = int.parse(RegExp(r'Tray \((\d+)\)')
          .firstMatch(tester
              .widgetList<Text>(find.textContaining('Tray ('))
              .first
              .data!)!
          .group(1)!);
      final take = traySize == 3 ? 2 : traySize;
      for (var i = 0; i < take; i++) {
        final row =
            capacity.keys.firstWhere((r) => (counts[r] ?? 0) < capacity[r]!);
        // Tray cards come after the board's cards in the tree; take the last one.
        await tester.tap(tray.last);
        await tester.pumpAndSettle();
        await tester.tap(rowLabel(row));
        await tester.pumpAndSettle();
        counts[row] = (counts[row] ?? 0) + 1;
      }
      final advance = find.byWidgetPredicate((w) =>
          w is ElevatedButton &&
          w.child is Text &&
          ((w.child as Text).data!.startsWith('Commit') ||
              (w.child as Text).data == 'Next 3'));
      await tester.tap(advance);
      await tester.pumpAndSettle();
    }

    expect(find.byType(PassPlayResultScreen), findsOneWidget);
    expect(find.text('Player A'), findsOneWidget);
    expect(find.text('Player B'), findsOneWidget);
    expect(find.text('Next Hand'), findsOneWidget);

    await tester.ensureVisible(find.text('Next Hand'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next Hand'));
    await tester.pumpAndSettle();
    expect(find.text('Status: Dealt A/B'), findsOneWidget);
    semantics.dispose();
  });
}
