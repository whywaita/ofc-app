import 'package:ofc_app_core/ofc_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// A deck dealing [codes] in order.
Deck deck(String codes) => Deck.fromCodes(codes.split(' '));

/// Five cards, then four draws of three: exactly one normal hand.
const fullHand = 'As Ks Qs Js Ts '
    '9s 8s 7s 6s 5s 4s 3s 2s Ah Kh Qh Jh';

void placeAll(PlayerHand h, Map<String, BoardRow> plan) {
  plan.forEach((code, row) => h.place(c(code), row));
}

void main() {
  group('the deal', () {
    test('five cards land in the tray', () {
      final h = PlayerHand.deal(deck(fullHand));
      expect(h.tray, cs('As Ks Qs Js Ts'));
      expect(h.currentDraw, cs('As Ks Qs Js Ts'));
      expect(h.isFantasy, isFalse);
      expect(h.history.single, isA<DrawAction>());
    });

    test('a Fantasy deal lands whole', () {
      final h = PlayerHand.deal(Deck.standard(seed: 1), count: 14);
      expect(h.tray, hasLength(14));
      expect(h.isFantasy, isTrue);
    });
  });

  group('placing', () {
    test('tray to row, then row to row while the card is from this draw', () {
      final h = PlayerHand.deal(deck(fullHand));
      h.place(c('As'), BoardRow.top);
      expect(h.row(BoardRow.top), [c('As')]);
      expect(h.tray, isNot(contains(c('As'))));
      h.place(c('As'), BoardRow.bottom);
      expect(h.row(BoardRow.top), isEmpty);
      expect(h.row(BoardRow.bottom), [c('As')]);
      expect(h.history.whereType<MoveAction>().single.from, BoardRow.top);
    });

    test('placing into the row it is already in changes nothing', () {
      final h = PlayerHand.deal(deck(fullHand));
      h.place(c('As'), BoardRow.top);
      expect(h.placementError(c('As'), BoardRow.top), isNull);
      h.place(c('As'), BoardRow.top);
      expect(h.row(BoardRow.top), [c('As')]);
    });

    test('a full row refuses', () {
      final h = PlayerHand.deal(deck(fullHand));
      placeAll(h, {'As': BoardRow.top, 'Ks': BoardRow.top, 'Qs': BoardRow.top});
      expect(h.placementError(c('Js'), BoardRow.top), PlacementError.rowFull);
      expect(() => h.place(c('Js'), BoardRow.top), throwsStateError);
    });

    test('cards from earlier draws are locked in', () {
      final h = PlayerHand.deal(deck(fullHand));
      placeAll(h, {
        'As': BoardRow.bottom,
        'Ks': BoardRow.bottom,
        'Qs': BoardRow.bottom,
        'Js': BoardRow.middle,
        'Ts': BoardRow.middle,
      });
      h.drawNext();
      expect(h.isMovable(c('As')), isFalse);
      expect(h.placementError(c('As'), BoardRow.top), PlacementError.lockedIn);
      expect(h.canReturnToTray(c('As')), isFalse);
    });

    test('only two of a three-card draw may go on the board', () {
      final h = PlayerHand.deal(deck(fullHand));
      placeAll(h, {
        'As': BoardRow.bottom,
        'Ks': BoardRow.bottom,
        'Qs': BoardRow.bottom,
        'Js': BoardRow.middle,
        'Ts': BoardRow.middle,
      });
      h.drawNext();
      placeAll(h, {'9s': BoardRow.middle, '8s': BoardRow.middle});
      expect(h.placementError(c('7s'), BoardRow.top),
          PlacementError.drawLimitReached);
      // Moving one of the two placed cards is still fine.
      expect(h.placementError(c('9s'), BoardRow.top), isNull);
    });

    test('cards outside the hand are refused', () {
      final h = PlayerHand.deal(deck(fullHand));
      expect(h.placementError(c('2c'), BoardRow.top), PlacementError.notInHand);
    });

    test('a card of this draw can go back to the tray', () {
      final h = PlayerHand.deal(deck(fullHand));
      h.place(c('As'), BoardRow.top);
      expect(h.canReturnToTray(c('As')), isTrue);
      h.returnToTray(c('As'));
      expect(h.tray, contains(c('As')));
      expect(h.row(BoardRow.top), isEmpty);
      expect(h.history.last, isA<ReturnAction>());
    });
  });

  group('drawing the next three', () {
    test('needs all five of the deal placed, then two of each three', () {
      final h = PlayerHand.deal(deck(fullHand));
      placeAll(h, {
        'As': BoardRow.bottom,
        'Ks': BoardRow.bottom,
        'Qs': BoardRow.bottom,
        'Js': BoardRow.middle,
      });
      expect(h.canDrawNext, isFalse);
      h.place(c('Ts'), BoardRow.middle);
      expect(h.canDrawNext, isTrue);
      h.drawNext();
      expect(h.tray, cs('9s 8s 7s'));
      h.place(c('9s'), BoardRow.middle);
      expect(h.canDrawNext, isFalse);
      h.place(c('8s'), BoardRow.middle);
      expect(h.canDrawNext, isTrue);
    });

    test('the leftover card is discarded on the next draw', () {
      final h = PlayerHand.deal(deck(fullHand));
      placeAll(h, {
        'As': BoardRow.bottom,
        'Ks': BoardRow.bottom,
        'Qs': BoardRow.bottom,
        'Js': BoardRow.middle,
        'Ts': BoardRow.middle,
      });
      h.drawNext();
      placeAll(h, {'9s': BoardRow.middle, '8s': BoardRow.middle});
      expect(h.drawNext(), [c('7s')]);
      expect(h.discards, [c('7s')]);
      expect(h.tray, cs('6s 5s 4s'));
    });

    test('a Fantasy hand never draws again', () {
      final h = PlayerHand.deal(Deck.standard(seed: 1), count: 14);
      expect(h.canDrawNext, isFalse);
      expect(h.drawNext, throwsStateError);
    });
  });

  group('playing a whole hand', () {
    PlayerHand playOut() {
      final h = PlayerHand.deal(deck(fullHand));
      placeAll(h, {
        'As': BoardRow.bottom,
        'Ks': BoardRow.bottom,
        'Qs': BoardRow.bottom,
        'Js': BoardRow.bottom,
        'Ts': BoardRow.bottom,
      });
      for (final (a, b) in [
        ('9s', '8s'),
        ('6s', '5s'),
        ('3s', '2s'),
        ('Kh', 'Qh'),
      ]) {
        h.drawNext();
        final row =
            h.row(BoardRow.middle).length < 5 ? BoardRow.middle : BoardRow.top;
        h.place(c(a), row);
        h.place(c(b),
            h.row(BoardRow.middle).length < 5 ? BoardRow.middle : BoardRow.top);
      }
      return h;
    }

    test('ends complete; commit discards what is left', () {
      final h = playOut();
      expect(h.isComplete, isTrue);
      expect(h.canDrawNext, isFalse);
      final b = h.commit();
      expect(b.isComplete, isTrue);
      expect(h.isCommitted, isTrue);
      expect(h.discards, cs('7s 4s Ah Jh'));
      expect(h.tray, isEmpty);
      expect(h.history.last, isA<CommitAction>());
    });

    test('nothing moves after commit', () {
      final h = playOut()..commit();
      expect(
          h.placementError(c('As'), BoardRow.top), PlacementError.handClosed);
      expect(h.commit, throwsStateError);
    });

    test('an incomplete hand cannot commit', () {
      expect(PlayerHand.deal(deck(fullHand)).commit, throwsStateError);
    });
  });

  test('sortTray: rank high to low, spades first, jokers last', () {
    final h = PlayerHand.deal(
        Deck.fromCodes([
          '2h',
          'JK1',
          'As',
          '5d',
          'Ah',
          'Ks',
          '9c',
          ...List.filled(7, '3c')
        ]),
        count: 7);
    h.sortTray();
    expect(h.tray, cs('As Ah Ks 9c 5d 2h JK1'));
  });

  test('exposed lists cannot be modified', () {
    final h = PlayerHand.deal(deck(fullHand));
    h.place(c('As'), BoardRow.top);
    expect(() => h.tray.clear(), throwsUnsupportedError);
    expect(() => h.row(BoardRow.top).clear(), throwsUnsupportedError);
    expect(() => h.history.clear(), throwsUnsupportedError);
    expect(() => h.discards.add(c('2c')), throwsUnsupportedError);
    expect(() => h.board.top.clear(), throwsUnsupportedError);
  });
}
