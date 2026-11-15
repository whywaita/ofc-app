import 'package:ofc_app_core/ofc_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('PlayingCard.parse', () {
    test('reads rank and suit symbols, case-insensitively', () {
      expect(c('As'), const StandardCard(Rank.ace, Suit.spades));
      expect(c('td'), const StandardCard(Rank.ten, Suit.diamonds));
      expect(c('2C'), const StandardCard(Rank.two, Suit.clubs));
    });

    test('reads jokers with and without an index', () {
      expect(c('JK'), const Joker());
      expect(c('jk2'), const Joker(2));
    });

    test('rejects malformed codes', () {
      expect(() => c('A'), throwsArgumentError);
      expect(() => c('Xs'), throwsArgumentError);
      expect(() => c('Ax'), throwsArgumentError);
      expect(() => c('Asd'), throwsArgumentError);
    });

    test('code round-trips through parse', () {
      for (final code in ['As', 'Td', '9h', '2c', 'JK', 'JK1']) {
        expect(c(code).code, code);
      }
    });
  });

  group('equality', () {
    test('jokers with different indexes are different cards', () {
      expect(const Joker(1) == const Joker(2), isFalse);
      expect(const Joker(1), const Joker(1));
      expect({const Joker(1), const Joker(2)}.length, 2);
    });

    test('a standard card never equals a joker', () {
      expect(c('As') == const Joker(), isFalse);
    });
  });

  group('Deck', () {
    test('standard deck holds 52 distinct cards', () {
      final deck = Deck.standard(seed: 1);
      final cards = deck.draw(52);
      expect(cards.toSet().length, 52);
      expect(deck.isEmpty, isTrue);
    });

    test('joker deck adds numbered jokers', () {
      final deck = Deck.withJokers(seed: 1, jokerCount: 2);
      final cards = deck.draw(54);
      expect(
          cards.whereType<Joker>().toSet(), {const Joker(1), const Joker(2)});
    });

    test('same seed gives the same order', () {
      expect(
          Deck.standard(seed: 42).draw(10), Deck.standard(seed: 42).draw(10));
    });

    test('shuffle order is stable across versions (seed 7)', () {
      // Pinned by tools/vlmkit/flows/play-hand.flow.json: seed 7 must keep dealing these.
      expect(Deck.standard(seed: 7).draw(5).map((c) => c.code),
          ['3c', 'Js', '3h', '4h', 'Ac']);
    });

    test('fromCodes keeps the given order', () {
      final deck = Deck.fromCodes(['As', 'Kd', 'JK']);
      expect(deck.draw(3), [c('As'), c('Kd'), const Joker()]);
    });

    test('drawing past the end throws', () {
      final deck = Deck.fromCodes(['As']);
      expect(() => deck.draw(2), throwsStateError);
      expect(deck.remaining, 1);
    });
  });
}
