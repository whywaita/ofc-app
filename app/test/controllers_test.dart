import 'package:flutter_test/flutter_test.dart';
import 'package:ofc_app/controllers/hand_table_controller.dart';
import 'package:ofc_app/controllers/pass_play_controller.dart';
import 'package:ofc_app/controllers/practice_controller.dart';
import 'package:ofc_app_core/ofc_core.dart';

/// Places the whole tray of a five-card deal, or two of a three-card draw, top-down from Bottom.
void placeDraw(HandTableController c) {
  final hand = c.hand;
  final n = hand.currentDraw.length == 3 ? 2 : hand.tray.length;
  for (final card in hand.tray.take(n).toList()) {
    final row = BoardRow.values.reversed
        .firstWhere((r) => hand.row(r).length < r.capacity);
    c.place(card, row);
  }
}

void main() {
  group('PracticeController', () {
    test('deals five and reports it', () {
      final c = PracticeController(seed: 7);
      expect(c.hand.tray.length, 5);
      expect(c.status, 'Dealt 5');
      expect(c.handSeed, 7);
      expect(c.advanceLabel, 'Next 3');
      expect(c.canAdvance, isFalse);
    });

    test('seed 7 deals the same first cards as before the refactor', () {
      final c = PracticeController(seed: 7);
      expect(c.hand.tray.map((x) => x.code), ['3c', 'Js', '3h', '4h', 'Ac']);
    });

    test('a refused placement leaves a hint and changes nothing', () {
      final c = PracticeController(seed: 7);
      final tray = c.hand.tray.toList();
      for (final card in tray.take(3)) {
        c.place(card, BoardRow.top);
      }
      c.place(tray[3], BoardRow.top);
      expect(c.hint, 'Row is full (3 max)');
      expect(c.hand.row(BoardRow.top).length, 3);
      expect(c.status, 'Placed');
    });

    test('tap path: select then tap a row; selecting twice deselects', () {
      final c = PracticeController(seed: 7);
      final card = c.hand.tray.first;
      c.select(card);
      expect(c.selected, card);
      c.select(card);
      expect(c.selected, isNull);
      c.tapRow(BoardRow.top); // nothing picked up: no-op
      expect(c.hand.row(BoardRow.top), isEmpty);
      c.select(card);
      c.tapRow(BoardRow.middle);
      expect(c.hand.row(BoardRow.middle), [card]);
      expect(c.selected, isNull);
      c.select(card);
      c.tapTray();
      expect(c.hand.tray, contains(card));
      expect(c.status, 'Back to Tray');
    });

    test('a card from an earlier draw cannot come back', () {
      final c = PracticeController(seed: 7);
      placeDraw(c);
      c.drawNext();
      final old = c.hand.row(BoardRow.bottom).first;
      c.returnToTray(old);
      expect(c.hint, 'That card cannot come back');
    });

    test('notifies listeners on every change', () {
      final c = PracticeController(seed: 7);
      var n = 0;
      c.addListener(() => n++);
      c.select(c.hand.tray.first);
      c.place(c.hand.tray.first, BoardRow.bottom);
      c.sortTray();
      expect(n, 3);
    });

    test('a full hand commits, then the next hand uses the next seed', () {
      final c = PracticeController(seed: 7);
      placeDraw(c);
      while (!c.hand.isComplete) {
        c.drawNext();
        expect(c.status, 'Drew 3');
        placeDraw(c);
      }
      expect(c.advanceLabel, 'Commit');
      expect(c.canAdvance, isTrue);
      final r = c.commit();
      expect(r.board.isComplete, isTrue);
      expect(c.status, 'Committed');
      c.nextHand();
      expect(c.handSeed, 8);
      expect(c.status, 'Dealt 5');
      expect(c.hand.tray.map((x) => x.code),
          PlayerHand.deal(Deck.standard(seed: 8)).tray.map((x) => x.code));
    });
  });

  group('PassPlayController', () {
    test('A starts, and each draw passes the turn', () {
      final c = PassPlayController(seed: 1);
      expect(c.current, Player.a);
      expect(c.status, 'Dealt A/B');
      placeDraw(c);
      expect(c.advance(), isNull);
      expect(c.current, Player.b);
      expect(c.status, 'Drew 3');
    });

    test('plays both hands to a result and starts the next one', () {
      final c = PassPlayController(seed: 3);
      MatchResult? result;
      for (var i = 0; i < 40 && result == null; i++) {
        placeDraw(c);
        if (c.hand.isComplete) {
          expect(c.advanceLabel, startsWith('Commit ('));
        }
        result = c.advance();
      }
      expect(result, isNotNull);
      expect(c.status, 'Both committed');
      expect(result!.score.a.total + result.score.b.total, 0,
          reason: 'heads-up points are zero-sum');
      c.nextHand();
      expect(c.match.isOver, isFalse);
      expect(c.status, 'Dealt A/B');
    });
  });
}
