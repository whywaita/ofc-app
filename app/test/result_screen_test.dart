import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ofc_app/screens/practice_result_screen.dart';
import 'package:ofc_app_core/ofc_core.dart';

/// The result screen on a phone-sized viewport.
///
/// Two defects found by the verification layer are checked here: the page did not scroll, which put
/// the action log out of reach on a short screen, and the seed was rendered by a widget that the
/// web build turns into an empty, unlabelled textarea.
void main() {
  const seed = 20260923;

  testWidgets(
      'the page scrolls, so the action log is reachable on a short screen',
      (tester) async {
    tester.view.physicalSize =
        const Size(1080, 1440); // 360x480 logical: a short phone
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: buildResultScreen(seed)));
    await tester.pumpAndSettle();

    final log = find.text('Action Log (This hand)');
    expect(log, findsOneWidget,
        reason: 'the action log is missing from the result screen');
    expect(tester.getTopLeft(log).dy, greaterThan(480),
        reason:
            'this case is only meaningful when the log starts below the fold');

    expect(find.byType(SingleChildScrollView), findsOneWidget,
        reason: 'the page itself must be scrollable');
    await tester.scrollUntilVisible(log, 120,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(log).dy, lessThanOrEqualTo(480),
        reason: 'scrolling must bring the action log into view');
  });

  testWidgets('the seed is readable by assistive technology', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(home: buildResultScreen(seed)));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Seed: $seed'), findsOneWidget,
        reason: 'a screen reader must be able to read the seed');
    semantics.dispose();
  });

  testWidgets('the seed text is dark enough to read', (tester) async {
    await tester.pumpWidget(MaterialApp(home: buildResultScreen(seed)));
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(find.text('Seed: $seed'));
    final color = text.style!.color!;
    expect(color.computeLuminance(), lessThan(0.18),
        reason: 'a light grey measured 2.55:1 against the background');
  });
}

PracticeResultScreen buildResultScreen(int seed) {
  // A full hand logs over twenty actions, which puts the log below the fold of a short screen.
  final session = PracticeSession(seed: seed);
  final hand = session.hand;
  for (final c in hand.tray.toList()) {
    hand.place(c, BoardRow.bottom);
  }
  var row = BoardRow.middle;
  while (!hand.isComplete) {
    hand.drawNext();
    for (final c in hand.tray.take(2).toList()) {
      if (hand.row(row).length == row.capacity) row = BoardRow.top;
      hand.place(c, row);
    }
  }
  return PracticeResultScreen(result: session.commit(), seed: seed);
}
