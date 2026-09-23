import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ofc_app/game_screen.dart';
import 'package:ofc_app/widgets/card_widget.dart';
import 'package:ofc_app_core/core/models/playing_card.dart';
import 'package:ofc_app_core/features/game/domain/game_options.dart';

/// Basic card operations on the real game screen: drag a card into Top, move it to another row,
/// hand it back to the tray, place it again.
///
/// Expected behaviour is the app's stated rule set, not its implementation:
///   * capacities are Top 3 / Middle 5 / Bottom 5
///   * a three-card draw takes at most two placements, the leftover is discarded on the next draw
///   * only cards drawn in the current cycle can be dragged again or returned to the tray
///   * no card is ever lost or duplicated by moving it around
void main() {
  testWidgets('a card goes to Top, moves to Middle, back to the tray, then to Bottom',
      (tester) async {
    await startHand(tester);
    final card = trayCards(tester).first;

    await dragTrayCardToRow(tester, card, 'Top');
    expect(rowCards(tester, 'Top'), [card]);
    expect(rowCards(tester, 'Middle'), isEmpty);
    expect(trayCards(tester).length, 4);
    expect(statusText(tester), 'Status: Placed');
    expectConsistent(tester, cards: 5);

    await dragRowCardToRow(tester, 'Top', card, 'Middle'); // "その後元に戻したり、他の枠に置いたり"
    expect(rowCards(tester, 'Top'), isEmpty);
    expect(rowCards(tester, 'Middle'), [card]);
    expect(trayCards(tester).length, 4, reason: 'a row-to-row move must not change the tray');
    expectConsistent(tester, cards: 5);

    await dragRowCardToTray(tester, 'Middle', card);
    expect(rowCards(tester, 'Middle'), isEmpty);
    expect(trayCards(tester), contains(card));
    expect(trayCards(tester).length, 5, reason: 'the card came back to the tray');
    expect(statusText(tester), 'Status: Back to Tray');
    expectConsistent(tester, cards: 5);

    await dragTrayCardToRow(tester, card, 'Bottom');
    expect(rowCards(tester, 'Bottom'), [card]);
    expect(trayCards(tester).length, 4);
    expectConsistent(tester, cards: 5);
  });

  testWidgets('a row refuses more cards than its capacity', (tester) async {
    await startHand(tester);
    final tray = trayCards(tester).toList();

    for (final card in tray.take(3)) {
      await dragTrayCardToRow(tester, card, 'Top');
    }
    expect(rowCards(tester, 'Top').length, 3, reason: 'Top holds at most three');
    expect(trayCards(tester).length, 2);

    await dragTrayCardToRow(tester, trayCards(tester).first, 'Top'); // fourth
    expect(rowCards(tester, 'Top').length, 3, reason: 'the fourth card must be refused');
    expect(trayCards(tester).length, 2, reason: 'the refused card stays in the tray');
    expectConsistent(tester, cards: 5);
  });

  testWidgets('a three-card draw takes two placements and refuses the third', (tester) async {
    await startHand(tester);
    await placeWholeTray(tester, 'Bottom'); // five-card deal: the tray must empty
    expect(rowCards(tester, 'Bottom').length, 5);

    await tapAdvance(tester); // draw three
    expect(trayCards(tester).length, 3);
    expect(statusText(tester), 'Status: Drew 3');

    final draw = trayCards(tester).toList();
    await dragTrayCardToRow(tester, draw[0], 'Middle');
    await dragTrayCardToRow(tester, draw[1], 'Middle');
    expect(rowCards(tester, 'Middle').length, 2);

    await dragTrayCardToRow(tester, draw[2], 'Middle'); // third placement of this draw
    expect(rowCards(tester, 'Middle').length, 2, reason: 'only two of three may be placed');
    expect(trayCards(tester).length, 1, reason: 'the third card is the discard');
    expectConsistent(tester, cards: 8);

    await tapAdvance(tester); // the leftover is discarded, three more arrive
    expect(trayCards(tester).length, 3);
    expect(rowCards(tester, 'Middle').length, 2, reason: 'the placed cards stay put');
    expectConsistent(tester, cards: 10);
  });

  testWidgets('a placed card can still be moved between rows once the draw is spent',
      (tester) async {
    await startHand(tester);
    await placeWholeTray(tester, 'Bottom'); // Bottom is now full with the deal's five
    await tapAdvance(tester);

    final draw = trayCards(tester).toList();
    await dragTrayCardToRow(tester, draw[0], 'Middle');
    await dragTrayCardToRow(tester, draw[1], 'Middle');
    await dragTrayCardToRow(tester, draw[2], 'Middle'); // refused: the allowance is spent

    // A row-to-row move is allowed even though this draw may place nothing else.
    await dragRowCardToRow(tester, 'Middle', draw[0], 'Top');
    expect(rowCards(tester, 'Top'), [draw[0]]);
    expect(rowCards(tester, 'Middle'), [draw[1]]);
    expectConsistent(tester, cards: 8);

    // Moving into a full row is refused, and the card stays where it was.
    await dragRowCardToRow(tester, 'Top', draw[0], 'Bottom');
    expect(rowCards(tester, 'Top'), [draw[0]], reason: 'the full row must refuse the card');
    expect(rowCards(tester, 'Bottom').length, 5, reason: 'Bottom holds at most five');

    // The same card moves into a row that has room.
    await dragRowCardToRow(tester, 'Top', draw[0], 'Middle');
    expect(rowCards(tester, 'Top'), isEmpty);
    expect(rowCards(tester, 'Middle').length, 2);
    expectConsistent(tester, cards: 8);
  });

  testWidgets('returning a card to the tray disables the advance until two are placed',
      (tester) async {
    await startHand(tester);
    await placeWholeTray(tester, 'Bottom');
    await tapAdvance(tester);

    final draw = trayCards(tester).toList();
    await dragTrayCardToRow(tester, draw[0], 'Middle');
    expect(advanceEnabled(tester), isFalse, reason: 'one of three placed is not enough');
    await dragTrayCardToRow(tester, draw[1], 'Middle');
    expect(advanceEnabled(tester), isTrue, reason: 'two placed ends the cycle');

    await dragRowCardToTray(tester, 'Middle', draw[1]);
    expect(advanceEnabled(tester), isFalse, reason: 'only one placed again');
    expect(trayCards(tester).length, 2, reason: 'the returned card is back in the tray');
    expectConsistent(tester, cards: 8);

    await dragTrayCardToRow(tester, draw[1], 'Top');
    expect(advanceEnabled(tester), isTrue, reason: 'two placed again');
    expect(rowCards(tester, 'Top'), [draw[1]]);
    expectConsistent(tester, cards: 8);
  });

  testWidgets('cards from an earlier draw cannot be moved again', (tester) async {
    await startHand(tester);
    await placeWholeTray(tester, 'Bottom'); // the deal's five cards fill Bottom
    await tapAdvance(tester);

    // The deal's cards were placed in an earlier cycle, so they are not draggable any more.
    expect(rowDraggables(tester, 'Bottom'), isEmpty,
        reason: 'only cards of the current draw can be re-dragged');

    final draw = trayCards(tester).toList();
    await dragTrayCardToRow(tester, draw[0], 'Middle');
    expect(rowDraggables(tester, 'Middle'), [draw[0]],
        reason: 'the card just placed is draggable');

    // A full row refuses even a fresh card from the tray.
    await dragTrayCardToRow(tester, draw[1], 'Bottom');
    expect(rowCards(tester, 'Bottom').length, 5, reason: 'Bottom is full');
    expect(trayCards(tester).length, 2, reason: 'the refused card stayed in the tray');
    expectConsistent(tester, cards: 8);
  });
  testWidgets('a card dropped outside a target stays where it was', (tester) async {
    await startHand(tester);
    final card = trayCards(tester).first;
    await dragTrayCardToRow(tester, card, 'Top');

    await dropOnEmptySpace(tester, _cardIn(rowTarget('Top'), card)); // from a row
    expect(rowCards(tester, 'Top'), [card], reason: 'the card stays in Top');
    expectConsistent(tester, cards: 5);

    await dropOnEmptySpace(tester, _cardIn(trayTarget(), trayCards(tester).first)); // from the tray
    expect(trayCards(tester).length, 4, reason: 'the card stays in the tray');
    expectConsistent(tester, cards: 5);
  });
  testWidgets('a card can be picked up and placed by tapping', (tester) async {
    final semantics = tester.ensureSemantics();
    await startHand(tester);
    final card = trayCards(tester).first;

    // The card is named for assistive technology, which also gives a click-only driver a handle.
    expect(find.bySemanticsLabel(cardLabel(card)), findsOneWidget,
        reason: 'tray cards must be reachable without dragging');

    await tapCard(tester, trayTarget(), card);
    await tapRowLabel(tester, 'Top');
    expect(rowCards(tester, 'Top'), [card], reason: 'tapping a row places the picked-up card');
    expect(trayCards(tester).length, 4);
    expectConsistent(tester, cards: 5);
    semantics.dispose();
  });

  testWidgets('a tapped card moves to another row and back to the tray', (tester) async {
    await startHand(tester);
    final card = trayCards(tester).first;
    await dragTrayCardToRow(tester, card, 'Top');

    await tapCard(tester, rowTarget('Top'), card);
    await tapRowLabel(tester, 'Middle');
    expect(rowCards(tester, 'Top'), isEmpty);
    expect(rowCards(tester, 'Middle'), [card]);
    expectConsistent(tester, cards: 5);

    await tapCard(tester, rowTarget('Middle'), card);
    await tapTrayLabel(tester);
    expect(rowCards(tester, 'Middle'), isEmpty);
    expect(trayCards(tester), contains(card));
    expectConsistent(tester, cards: 5);
  });

  testWidgets('a refused drag says why', (tester) async {
    await startHand(tester);
    for (final card in trayCards(tester).take(3).toList()) {
      await dragTrayCardToRow(tester, card, 'Top');
    }
    expect(rowCards(tester, 'Top').length, 3);

    // Hold the fourth card over the full row: the reason is shown while dragging.
    final gesture = await tester.startGesture(tester.getCenter(_cardIn(trayTarget(), trayCards(tester).first)));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(tester.getCenter(rowTarget('Top')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Row is full (3 max)'), findsOneWidget,
        reason: 'a refused drop must say why');
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Row is full (3 max)'), findsNothing, reason: 'the reason is not sticky');
    expect(rowCards(tester, 'Top').length, 3);
    expectConsistent(tester, cards: 5);
  });

  testWidgets('a refused tap says why', (tester) async {
    await startHand(tester);
    for (final card in trayCards(tester).take(3).toList()) {
      await dragTrayCardToRow(tester, card, 'Top');
    }
    final spare = trayCards(tester).first;

    await tapCard(tester, trayTarget(), spare);
    await tapRowLabel(tester, 'Top');
    expect(find.text('Row is full (3 max)'), findsOneWidget,
        reason: 'a refused tap must say why');
    expect(rowCards(tester, 'Top').length, 3);
    expect(trayCards(tester), contains(spare));
    expectConsistent(tester, cards: 5);
  });

  testWidgets('a third card in one draw is refused with a reason', (tester) async {
    await startHand(tester);
    await placeWholeTray(tester, 'Bottom');
    await tapAdvance(tester);

    final draw = trayCards(tester).toList();
    await dragTrayCardToRow(tester, draw[0], 'Middle');
    await dragTrayCardToRow(tester, draw[1], 'Middle');
    await tapCard(tester, trayTarget(), draw[2]);
    await tapRowLabel(tester, 'Middle');
    expect(find.text('Two cards per draw'), findsOneWidget);
    expect(rowCards(tester, 'Middle').length, 2);
    expectConsistent(tester, cards: 8);
  });

  testWidgets('each row offers a named place action that works on a row holding cards',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await startHand(tester);
    for (final row in const [['Top', 3], ['Middle', 5], ['Bottom', 5]]) {
      expect(find.bySemanticsLabel('Place in ${row[0]} (${row[1]} max)'), findsOneWidget,
          reason: 'a place action must be reachable without aiming at the cards');
    }

    final card = trayCards(tester).first;
    await tapCard(tester, trayTarget(), card);
    await tester.tap(find.bySemanticsLabel('Place in Top (3 max)'));
    await tester.pumpAndSettle();
    expect(rowCards(tester, 'Top'), [card]);
    expectConsistent(tester, cards: 5);

    // and again once the row already holds a card, which is where a plain tap can miss
    final second = trayCards(tester).first;
    await tapCard(tester, trayTarget(), second);
    await tester.tap(find.bySemanticsLabel('Place in Top (3 max)'));
    await tester.pumpAndSettle();
    expect(rowCards(tester, 'Top').length, 2);
    expectConsistent(tester, cards: 5);
    semantics.dispose();
  });

}

// ---------------------------------------------------------------- harness

Future<void> startHand(WidgetTester tester,
    {int seed = 7, GameOptions options = GameOptions.standard}) async {
  tester.view.physicalSize = const Size(1080, 2400); // the default 800x600 view clips the board
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
      MaterialApp(key: UniqueKey(), home: GameScreen(seed: seed, options: options)));
  await tester.pumpAndSettle();
}

Future<void> placeWholeTray(WidgetTester tester, String row) async {
  for (final card in trayCards(tester).toList()) {
    await dragTrayCardToRow(tester, card, row);
  }
}

Finder advanceButton() => find.ancestor(
      of: find.text('Next 3'),
      matching: find.byType(ElevatedButton),
    );

bool advanceEnabled(WidgetTester tester) =>
    tester.widget<ElevatedButton>(advanceButton()).onPressed != null;

Future<void> tapAdvance(WidgetTester tester) async {
  expect(advanceEnabled(tester), isTrue, reason: 'Next 3 is disabled');
  await tester.tap(advanceButton());
  await tester.pumpAndSettle();
}

String statusText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data)
    .whereType<String>()
    .firstWhere((t) => t.startsWith('Status: '));

List<PlayingCard> trayCards(WidgetTester tester) => draggablesIn(tester, trayTarget());

List<PlayingCard> rowCards(WidgetTester tester, String row) => tester
    .widgetList<CardWidget>(find.descendant(of: rowTarget(row), matching: find.byType(CardWidget)))
    .map((w) => w.card)
    .toList();

List<PlayingCard> rowDraggables(WidgetTester tester, String row) =>
    draggablesIn(tester, rowTarget(row));

List<PlayingCard> draggablesIn(WidgetTester tester, Finder area) => tester
    .widgetList<Draggable<PlayingCard>>(find.descendant(of: area, matching: find.byType(Draggable<PlayingCard>)))
    .map((d) => d.data)
    .whereType<PlayingCard>()
    .toList();

Finder trayTarget() => find.ancestor(
      of: find.textContaining('Tray ('),
      matching: find.byType(DragTarget<PlayingCard>),
    );

Finder rowTarget(String row) => find.ancestor(
      of: find.textContaining('$row ('),
      matching: find.byType(DragTarget<PlayingCard>),
    );

/// Every card is somewhere exactly once: no duplicates, and `cards` cards on the table in total.
void expectConsistent(WidgetTester tester, {required int cards}) {
  final seen = <PlayingCard>[
    ...trayCards(tester),
    for (final row in ['Top', 'Middle', 'Bottom']) ...rowCards(tester, row),
  ];
  final shape = 'tray=${trayCards(tester)} top=${rowCards(tester, 'Top')} '
      'middle=${rowCards(tester, 'Middle')} bottom=${rowCards(tester, 'Bottom')}';
  expect(seen.length, cards, reason: 'card count is wrong: $shape');
  expect(seen.toSet().length, seen.length, reason: 'a card appears twice: $shape');
}

Future<void> dragTrayCardToRow(WidgetTester tester, PlayingCard card, String row) =>
    dragCard(tester, _cardIn(trayTarget(), card), rowTarget(row));

Future<void> dragRowCardToRow(WidgetTester tester, String from, PlayingCard card, String to) =>
    dragCard(tester, _cardIn(rowTarget(from), card), rowTarget(to));

Future<void> dragRowCardToTray(WidgetTester tester, String from, PlayingCard card) =>
    dragCard(tester, _cardIn(rowTarget(from), card), trayTarget());

/// The draggable holding one particular card inside an area.
Finder _cardIn(Finder area, PlayingCard card) => find.descendant(
      of: area,
      matching: find.byWidgetPredicate(
        (w) => w is Draggable<PlayingCard> && w.data == card,
        description: 'the draggable holding $card',
      ),
    );

/// A real pointer drag: press, move onto the target, release.
Future<void> dragCard(WidgetTester tester, Finder source, Finder target) async {
  expect(source, findsOneWidget, reason: 'the card to drag is not draggable here');
  final from = tester.getCenter(source);
  final to = tester.getCenter(target);
  final gesture = await tester.startGesture(from);
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.moveTo(to);
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.up();
  await tester.pumpAndSettle();
}

/// Press on a card, move it over empty space and release: nothing should move.
Future<void> dropOnEmptySpace(WidgetTester tester, Finder source) async {
  expect(source, findsOneWidget, reason: 'the card to drag is not draggable here');
  final gesture = await tester.startGesture(tester.getCenter(source));
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.moveTo(const Offset(4, 4)); // outside every drop target
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<void> tapRowLabel(WidgetTester tester, String row) async {
  await tester.tap(find.textContaining('$row ('));
  await tester.pumpAndSettle();
}

Future<void> tapTrayLabel(WidgetTester tester) async {
  await tester.tap(find.textContaining('Tray ('));
  await tester.pumpAndSettle();
}

Future<void> tapCard(WidgetTester tester, Finder area, PlayingCard card) async {
  await tester.tap(_cardIn(area, card));
  await tester.pumpAndSettle();
}

String cardLabel(PlayingCard card) =>
    card.isJoker ? 'Joker' : '${CardRenderer.rankSymbol(card)} of ${card.suit!.name}';
