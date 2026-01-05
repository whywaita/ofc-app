import 'package:test/test.dart';
import 'package:ofc_app_core/features/game/domain/hand_evaluator.dart';
import 'package:ofc_app_core/features/game/domain/hand_category5.dart';
import 'package:ofc_app_core/features/game/domain/hand_category3.dart';
import 'helpers.dart';

void main() {
  group('evaluate5DeucesWild', () {
    test('No deuces: returns normal evaluation', () {
      final sf = HandEvaluator.evaluate5DeucesWild(
          [c('Th'), c('Jh'), c('Qh'), c('Kh'), c('Ah')]);
      expect(sf.category, Hand5Category.straightFlush);
      expect(sf.isWild, false);
    });

    test('Four Deuces + 5s = Straight Flush (9-high)', () {
      // 4 deuces + 5s: must use 5s, so best straight flush is 5-6-7-8-9
      final cards = [c('2s'), c('2h'), c('2d'), c('2c'), c('5s')];
      final rank = HandEvaluator.evaluate5DeucesWild(cards);
      expect(rank.category, Hand5Category.straightFlush);
      expect(rank.tiebreakers.first, 9); // 9-high straight flush
      expect(rank.isWild, true);
    });

    test('Four Deuces + As = Straight Flush (Royal)', () {
      // 4 deuces + As: can make Royal Flush (As-Ks-Qs-Js-Ts)
      final cards = [c('2s'), c('2h'), c('2d'), c('2c'), c('As')];
      final rank = HandEvaluator.evaluate5DeucesWild(cards);
      expect(rank.category, Hand5Category.straightFlush);
      expect(rank.tiebreakers.first, 14); // Royal (Ace-high)
      expect(rank.isWild, true);
    });

    test('Royal Flush with deuces', () {
      final cards = [c('As'), c('Ks'), c('Qs'), c('2h'), c('2d')];
      final rank = HandEvaluator.evaluate5DeucesWild(cards);
      expect(rank.category, Hand5Category.straightFlush);
      expect(rank.tiebreakers.first, 14); // Ace high
      expect(rank.isWild, true);
    });

    test('Issue #17: Kd, 2d, Jd, 2s, Qd should be Royal Flush', () {
      // Kd, Jd, Qd (diamond) + 2d, 2s (two deuces)
      // With 2 deuces as Ad and Td, this makes a Royal Flush (A-K-Q-J-T of diamonds)
      final cards = [c('Kd'), c('2d'), c('Jd'), c('2s'), c('Qd')];
      final rank = HandEvaluator.evaluate5DeucesWild(cards);
      expect(rank.category, Hand5Category.straightFlush);
      expect(rank.tiebreakers.first, 14); // Royal (Ace-high)
      expect(rank.isWild, true);
    });

    test('Three deuces + two same-suit cards = Straight Flush', () {
      // 3 deuces + As + Ks can make a Royal Flush (As-Ks-Qs-Js-Ts)
      final cards = [c('2s'), c('2h'), c('2d'), c('As'), c('Ks')];
      final rank = HandEvaluator.evaluate5DeucesWild(cards);
      expect(rank.category, Hand5Category.straightFlush);
      expect(rank.tiebreakers.first, 14); // Royal (Ace-high)
      expect(rank.isWild, true);
    });

    test('Three deuces + two different-suit cards = Four of a Kind', () {
      // 3 deuces + As + Kh: cannot make straight flush (only 1 spade)
      // Can make Four Aces
      final cards = [c('2s'), c('2h'), c('2d'), c('As'), c('Kh')];
      final rank = HandEvaluator.evaluate5DeucesWild(cards);
      expect(rank.category, Hand5Category.fourOfAKind);
      expect(rank.isWild, true);
    });

    test('Two deuces + pair = Four of a Kind', () {
      final cards = [c('2s'), c('2h'), c('As'), c('Ad'), c('Ks')];
      final rank = HandEvaluator.evaluate5DeucesWild(cards);
      expect(rank.category, Hand5Category.fourOfAKind);
      expect(rank.isWild, true);
    });

    test('One deuce + trips = Four of a Kind', () {
      final cards = [c('2s'), c('As'), c('Ad'), c('Ac'), c('Ks')];
      final rank = HandEvaluator.evaluate5DeucesWild(cards);
      expect(rank.category, Hand5Category.fourOfAKind);
      expect(rank.isWild, true);
    });

    test('One deuce + flush draw = Flush', () {
      final cards = [c('2s'), c('As'), c('Ks'), c('Qs'), c('9s')];
      final rank = HandEvaluator.evaluate5DeucesWild(cards);
      // This could be straight flush (A-K-Q-J-T) with 2 as J and T
      // Actually with only 1 deuce: A-K-Q-?-9, need J and T, but only 1 deuce
      // So it's a flush
      expect(rank.category, Hand5Category.flush);
      expect(rank.isWild, true);
    });

    test('One deuce + straight draw = Straight', () {
      final cards = [c('2h'), c('6s'), c('7d'), c('8c'), c('9s')];
      final rank = HandEvaluator.evaluate5DeucesWild(cards);
      // 6-7-8-9-? can make T-high straight (6-7-8-9-T)
      expect(rank.category, Hand5Category.straight);
      expect(rank.tiebreakers.first, 10); // Ten high
      expect(rank.isWild, true);
    });

    test('Wild with higher category beats Natural with lower category', () {
      final wildFlush =
          Hand5Rank(Hand5Category.flush, [14, 12, 10, 8, 6], isWild: true);
      final naturalStraight =
          Hand5Rank(Hand5Category.straight, [14], isWild: false);
      expect(wildFlush.compareTo(naturalStraight), greaterThan(0));
    });

    test('One deuce + two pair = Full House', () {
      final cards = [c('2s'), c('As'), c('Ad'), c('Ks'), c('Kd')];
      final rank = HandEvaluator.evaluate5DeucesWild(cards);
      expect(rank.category, Hand5Category.fullHouse);
      expect(rank.isWild, true);
    });

    test('One deuce + pair = Three of a Kind', () {
      final cards = [c('2s'), c('As'), c('Ad'), c('Ks'), c('Qd')];
      final rank = HandEvaluator.evaluate5DeucesWild(cards);
      expect(rank.category, Hand5Category.threeOfAKind);
      expect(rank.isWild, true);
    });

    test('One deuce + high cards = Pair', () {
      final cards = [c('2s'), c('As'), c('Kd'), c('Qc'), c('9h')];
      final rank = HandEvaluator.evaluate5DeucesWild(cards);
      // Deuce pairs with highest card (Ace)
      expect(rank.category, Hand5Category.onePair);
      expect(rank.isWild, true);
    });
  });

  group('evaluate3DeucesWild', () {
    test('No deuces: returns normal evaluation', () {
      final trips =
          HandEvaluator.evaluate3DeucesWild([c('As'), c('Ah'), c('Ad')]);
      expect(trips.category, Hand3Category.threeOfAKind);
      expect(trips.isWild, false);
    });

    test('Two deuces + any card = Three of a Kind', () {
      final cards = [c('2s'), c('2h'), c('As')];
      final rank = HandEvaluator.evaluate3DeucesWild(cards);
      expect(rank.category, Hand3Category.threeOfAKind);
      expect(rank.isWild, true);
    });

    test('One deuce + pair = Three of a Kind', () {
      final cards = [c('2s'), c('As'), c('Ah')];
      final rank = HandEvaluator.evaluate3DeucesWild(cards);
      expect(rank.category, Hand3Category.threeOfAKind);
      expect(rank.isWild, true);
    });

    test('One deuce + two different cards = Pair', () {
      final cards = [c('2s'), c('As'), c('Kh')];
      final rank = HandEvaluator.evaluate3DeucesWild(cards);
      // Deuce pairs with Ace
      expect(rank.category, Hand3Category.pair);
      expect(rank.isWild, true);
    });

    test('Three deuces = Three of a Kind (Aces)', () {
      final cards = [c('2s'), c('2h'), c('2d')];
      final rank = HandEvaluator.evaluate3DeucesWild(cards);
      expect(rank.category, Hand3Category.threeOfAKind);
      expect(rank.tiebreakers.first, 14); // Aces
      expect(rank.isWild, true);
    });

    test('Natural Three of a Kind', () {
      final cards = [c('As'), c('Ah'), c('Ad')];
      final rank = HandEvaluator.evaluate3DeucesWild(cards);
      expect(rank.category, Hand3Category.threeOfAKind);
      expect(rank.isWild, false);
    });
  });

  group('Hand rank comparison with isWild', () {
    test('Hand3Rank: Higher category Wild beats lower category Natural', () {
      final wildTrips =
          Hand3Rank(Hand3Category.threeOfAKind, [14], isWild: true);
      final naturalPair =
          Hand3Rank(Hand3Category.pair, [14, 13], isWild: false);
      expect(wildTrips.compareTo(naturalPair), greaterThan(0));
    });
  });
}
