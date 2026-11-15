import 'package:ofc_app_core/ofc_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

BoardEvaluation eval(Board b, [WildMode mode = WildMode.none]) =>
    BoardEvaluation.of(b, wildMode: mode);

void main() {
  group('Board', () {
    test('rows by BoardRow and completeness', () {
      final b = board('As Ad 2c', '3c 8d 8s Jc Ah', 'Td 9s 9h 6c Tc');
      expect(b.row(BoardRow.top), cs('As Ad 2c'));
      expect(b.isComplete, isTrue);
      expect(b.cards, hasLength(13));
      expect(board('As', '', '').isComplete, isFalse);
    });

    test('row capacities', () {
      expect(BoardRow.values.map((r) => r.capacity), [3, 5, 5]);
    });

    test('an incomplete board cannot be evaluated', () {
      expect(() => eval(board('As Ad', '3c 8d 8s Jc Ah', 'Td 9s 9h 6c Tc')),
          throwsArgumentError);
    });
  });

  group('foul (natural)', () {
    test('bottom >= middle >= top is not a foul', () {
      final e = eval(board('Qh Qs 2c', 'Kd Kc 3d 7s 9h', 'Ah Ad 7c 6c 4d'));
      expect(e.isFoul, isFalse);
    });

    test('middle stronger than bottom fouls', () {
      expect(eval(board('As Ad 2c', '3c 8d 8s Jc Ah', 'Td 9s 9h 6c Tc')).isFoul,
          isTrue);
    });

    test('pair on top over high card in the middle fouls', () {
      expect(eval(board('Kh Kd 2s', 'As Qd 9c 7h 3d', '2h 2d 5s 6c 9h')).isFoul,
          isTrue);
    });

    test('kickers decide: middle pair of 8s under top pair of Ks fouls', () {
      expect(eval(board('Qh Ks Kd', '3c 8d 8s Jc Ah', 'Td 9s 9h 6c Tc')).isFoul,
          isTrue);
    });

    test('a top hand no stronger than the middle is allowed', () {
      final e = eval(board('Ks 9d 3c', 'Kh 9c 3d 2s 4h', 'Ac Ad 5h 6h 7d'));
      expect(e.isFoul, isFalse);
    });
  });

  group('wild cards resolve to the strongest board that does not foul', () {
    test('deuces on top drop to a pair to stay under the middle', () {
      // Best top would be trips of tens; under middle two pair the best is a pair of aces.
      final e = eval(board('2s 2d Ts', '8c 6s 8d 3c 3d', 'Qd Th Kh Kd Qh'),
          WildMode.deuces);
      expect(e.isFoul, isFalse);
      expect(
          e.top, const Hand3Rank(Hand3Category.pair, [14, 10], isWild: true));
    });

    test('one deuce with a pair on top stays a pair', () {
      final e = eval(board('2s 6s 6d', '7h 7d Kc Qs 8h', 'As Ad Ah 2c 3c'),
          WildMode.deuces);
      expect(e.isFoul, isFalse);
      expect(e.top, const Hand3Rank(Hand3Category.pair, [6, 14], isWild: true));
      expect(e.bottom,
          const Hand5Rank(Hand5Category.fourOfAKind, [14, 3], isWild: true));
    });

    test('deuces in the middle stay at or under the bottom', () {
      final e = eval(board('As Qs Qc', '7c 7d 2c 2d 4h', '8s 8d 6c 6h Ac'),
          WildMode.deuces);
      expect(e.isFoul, isFalse);
      expect(e.middle,
          const Hand5Rank(Hand5Category.twoPair, [7, 6, 4], isWild: true));
    });

    test('when a foul cannot be avoided every row shows its best hand', () {
      final e = eval(board('2s 2h 5h', '6h 6c 4h 2c 6s', 'Ts Qc Jd Qh Tc'),
          WildMode.deuces);
      expect(e.isFoul, isTrue);
      expect(e.top,
          const Hand3Rank(Hand3Category.threeOfAKind, [5], isWild: true));
      expect(e.middle.category, Hand5Category.fourOfAKind);
      expect(e.middle.tiebreakers.first, 6);
    });

    test('joker on top: pair of kings would foul, so K-Q-6 high', () {
      final e = eval(board('JK1 Ks 6d', 'Kh Qd Tc Jh 8d', '9c 9s 9d 2c JK2'),
          WildMode.joker);
      expect(e.isFoul, isFalse);
      expect(e.top,
          const Hand3Rank(Hand3Category.highCard, [13, 12, 6], isWild: true));
    });

    test('joker on top pairs the five under a middle pair of sevens', () {
      final e = eval(board('JK 5s 3d', '7h 7d Kc Qs 8h', 'As Ad Ah 2c 3c'),
          WildMode.joker);
      expect(e.isFoul, isFalse);
      expect(e.top, const Hand3Rank(Hand3Category.pair, [5, 3], isWild: true));
    });

    test('when nothing constrains it a joker on top takes its best hand', () {
      final e = eval(board('JK Ks 6d', 'Ah Ad Ac 9h 8d', '9c 9s 9d 2c 2s'),
          WildMode.joker);
      expect(e.top, const Hand3Rank(Hand3Category.pair, [13, 6], isWild: true));
    });
  });
}
