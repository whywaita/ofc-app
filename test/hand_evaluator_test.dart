import 'dart:math';

import 'package:ofc_app_core/ofc_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

const natural = HandEvaluator(WildMode.none);
const deuces = HandEvaluator(WildMode.deuces);
const jokers = HandEvaluator(WildMode.joker);

void main() {
  group('natural five-card hands', () {
    void expect5(String cards, Hand5Category cat, List<int> tb) {
      final r = natural.best5(cs(cards));
      expect(r.category, cat, reason: cards);
      expect(r.tiebreakers, tb, reason: cards);
      expect(r.isWild, isFalse);
    }

    test('every category with its tiebreakers', () {
      expect5('Ah Kh Qh Jh Th', Hand5Category.straightFlush, [14]);
      expect5('5d 4d 3d 2d Ad', Hand5Category.straightFlush, [5]);
      expect5('9s 9d 9c 9h 2s', Hand5Category.fourOfAKind, [9, 2]);
      expect5('Ks Kd Kc 4h 4s', Hand5Category.fullHouse, [13, 4]);
      expect5('As Js 9s 4s 2s', Hand5Category.flush, [14, 11, 9, 4, 2]);
      expect5('6c 5d 4h 3s 2s', Hand5Category.straight, [6]);
      expect5('Ac 2d 3h 4s 5s', Hand5Category.straight, [5]);
      expect5('7c 7d 7h Ks 2s', Hand5Category.threeOfAKind, [7, 13, 2]);
      expect5('Jc Jd 4h 4s Ks', Hand5Category.twoPair, [11, 4, 13]);
      expect5('Qc Qd 9h 4s 2s', Hand5Category.onePair, [12, 9, 4, 2]);
      expect5('Kc Qd 9h 4s 2s', Hand5Category.highCard, [13, 12, 9, 4, 2]);
    });

    test('Q-K-A-2-3 is not a straight', () {
      expect(
          natural.best5(cs('Qc Kd Ah 2s 3s')).category, Hand5Category.highCard);
    });

    test('wrong card count is rejected', () {
      expect(() => natural.best5(cs('As Ks')), throwsArgumentError);
      expect(() => natural.best3(cs('As Ks')), throwsArgumentError);
    });
  });

  group('natural three-card hands', () {
    test('trips, pair and high card', () {
      expect(natural.best3(cs('5s 5d 5c')),
          const Hand3Rank(Hand3Category.threeOfAKind, [5]));
      expect(natural.best3(cs('Ks 2d Kc')),
          const Hand3Rank(Hand3Category.pair, [13, 2]));
      expect(natural.best3(cs('2s Ad 9c')),
          const Hand3Rank(Hand3Category.highCard, [14, 9, 2]));
    });

    test('flushes and straights do not count on three cards', () {
      expect(natural.best3(cs('Qs Ks As')).category, Hand3Category.highCard);
    });
  });

  group('ordering', () {
    test('category first, then tiebreakers', () {
      final flush = natural.best5(cs('As Js 9s 4s 2s'));
      final straight = natural.best5(cs('Ac Kd Qh Js Ts'));
      expect(flush.compareTo(straight), greaterThan(0));
      final pairK = natural.best5(cs('Kc Kd 9h 4s 2s'));
      final pairKbetterKicker = natural.best5(cs('Kh Ks Th 4c 2c'));
      expect(pairKbetterKicker.compareTo(pairK), greaterThan(0));
    });

    test('wildness does not change strength', () {
      const wild =
          Hand5Rank(Hand5Category.flush, [14, 12, 10, 8, 6], isWild: true);
      const plain = Hand5Rank(Hand5Category.flush, [14, 12, 10, 8, 6]);
      expect(wild.compareTo(plain), 0);
    });

    test('a top hand compares against a five-card hand by its made hand', () {
      final topPairQ = natural.best3(cs('Qs Qd 3c'));
      expect(topPairQ.compareToFive(natural.best5(cs('Qh Qc Kd 9s 2s'))),
          lessThan(0));
      expect(topPairQ.compareToFive(natural.best5(cs('Jh Jc Kd 9s 2s'))),
          greaterThan(0));
      expect(
          natural
              .best3(cs('Ks 9d 4c'))
              .compareToFive(natural.best5(cs('Kh 9c 3d 2s 4h'))),
          0);
    });
  });

  group('deuces wild', () {
    void expect5(String cards, Hand5Category cat, List<int> tb) {
      final r = deuces.best5(cs(cards));
      expect(r.category, cat, reason: cards);
      expect(r.tiebreakers, tb, reason: cards);
      expect(r.isWild, isTrue, reason: cards);
    }

    test('documented examples (docs/plans/deuces-wild.md)', () {
      expect5('2s 2h 2d 2c 5s', Hand5Category.straightFlush, [9]);
      expect5('2s 2h 2d As Ks', Hand5Category.straightFlush, [14]);
      expect5('2s 2h As Ad Ks', Hand5Category.fourOfAKind, [14, 13]);
      expect5('2s As Ad Ac Ks', Hand5Category.fourOfAKind, [14, 13]);
    });

    test('issue #17: Kd 2d Jd 2s Qd is a royal flush', () {
      expect5('Kd 2d Jd 2s Qd', Hand5Category.straightFlush, [14]);
    });

    test('a wild never duplicates a card already in the hand', () {
      // The flush fills with the jack, not a second ace.
      expect5('2s As Ks Qs 9s', Hand5Category.flush, [14, 13, 12, 11, 9]);
      // The pair of aces takes the best kickers actually left.
      expect5('2s As Kd Qc 9h', Hand5Category.onePair, [14, 13, 12, 9]);
    });

    test('other categories', () {
      expect5('2s 2h 2d As Kh', Hand5Category.fourOfAKind, [14, 13]);
      expect5('2h 6s 7d 8c 9s', Hand5Category.straight, [10]);
      expect5('2s As Ad Ks Kd', Hand5Category.fullHouse, [14, 13]);
      expect5('2s As Ad Ks Qd', Hand5Category.threeOfAKind, [14, 13, 12]);
      expect5('2h 3s 4d 5c 7s', Hand5Category.straight, [7]);
      expect5('2h 3s 4d 5c Ks', Hand5Category.onePair, [13, 5, 4, 3]);
    });

    test('without deuces the hand is natural', () {
      final r = deuces.best5(cs('Th Jh Qh Kh Ah'));
      expect(r.category, Hand5Category.straightFlush);
      expect(r.isWild, isFalse);
    });

    test('three-card rows', () {
      expect(deuces.best3(cs('2s 2h As')),
          const Hand3Rank(Hand3Category.threeOfAKind, [14], isWild: true));
      expect(deuces.best3(cs('2s 9s 9h')),
          const Hand3Rank(Hand3Category.threeOfAKind, [9], isWild: true));
      expect(deuces.best3(cs('2s As Kh')),
          const Hand3Rank(Hand3Category.pair, [14, 13], isWild: true));
      expect(deuces.best3(cs('2s 2h 2d')),
          const Hand3Rank(Hand3Category.threeOfAKind, [14], isWild: true));
      expect(deuces.best3(cs('As Ah Ad')).isWild, isFalse);
    });
  });

  group('joker wild', () {
    test('2s are ordinary cards', () {
      expect(jokers.best5(cs('2s 2h 2d 2c 5s')),
          const Hand5Rank(Hand5Category.fourOfAKind, [2, 5]));
    });

    test('joker completes the best hand', () {
      expect(jokers.best5(cs('JK Ks Qs Js Ts')),
          const Hand5Rank(Hand5Category.straightFlush, [14], isWild: true));
      expect(jokers.best5(cs('JK1 JK2 Kh Kd 4c')),
          const Hand5Rank(Hand5Category.fourOfAKind, [13, 4], isWild: true));
      expect(jokers.best5(cs('JK 9s 9h 4d 3c')),
          const Hand5Rank(Hand5Category.threeOfAKind, [9, 4, 3], isWild: true));
    });

    test('four of a kind plus a joker stays four of a kind', () {
      expect(jokers.best5(cs('As Ah Ad Ac JK')),
          const Hand5Rank(Hand5Category.fourOfAKind, [14, 13], isWild: true));
    });

    test('three-card rows: a joker pairs the highest card', () {
      expect(jokers.best3(cs('JK Ks 6d')),
          const Hand3Rank(Hand3Category.pair, [13, 6], isWild: true));
      expect(jokers.best3(cs('JK Qs Qd')),
          const Hand3Rank(Hand3Category.threeOfAKind, [12], isWild: true));
      expect(jokers.best3(cs('JK1 JK2 7c')),
          const Hand3Rank(Hand3Category.threeOfAKind, [7], isWild: true));
    });
  });

  group('candidates', () {
    test('lists every hand the wild cards can make', () {
      final all = jokers.candidates3(cs('JK Ks 6d'));
      expect(all,
          contains(const Hand3Rank(Hand3Category.pair, [6, 13], isWild: true)));
      expect(
          all,
          contains(const Hand3Rank(Hand3Category.highCard, [13, 12, 6],
              isWild: true)));
      expect(all.any((r) => r.category == Hand3Category.threeOfAKind), isFalse);
    });

    test('a hand without wilds has exactly one candidate', () {
      expect(deuces.candidates5(cs('As Ks Qs Js 9d')), hasLength(1));
    });
  });

  group('matches a brute-force search over real substitute cards', () {
    final rnd = Random(20261115);
    final full = Deck.standard(seed: 0).draw(52).cast<StandardCard>();

    for (final mode in [WildMode.deuces, WildMode.joker]) {
      final ev = HandEvaluator(mode);
      test('${mode.name}, 5 cards', () {
        for (var i = 0; i < 150; i++) {
          final hand = _randomHand(rnd, mode, 5, full);
          final slow = _bruteForce(hand, mode, full)
              .map(natural.best5)
              .reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
          expect(ev.best5(hand).compareTo(slow), 0,
              reason: '$hand: fast=${ev.best5(hand)} brute=$slow');
        }
      });
      test('${mode.name}, 3 cards', () {
        for (var i = 0; i < 150; i++) {
          final hand = _randomHand(rnd, mode, 3, full);
          final slow = _bruteForce(hand, mode, full)
              .map(natural.best3)
              .reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
          expect(ev.best3(hand).compareTo(slow), 0,
              reason: '$hand: fast=${ev.best3(hand)} brute=$slow');
        }
      });
    }
  });
}

/// A random hand holding 0..2 wild cards (more makes the brute force below too slow; hands with
/// 3+ wilds are pinned by the examples above).
List<PlayingCard> _randomHand(
    Random rnd, WildMode mode, int size, List<StandardCard> full) {
  final pool = [
    ...full,
    if (mode == WildMode.joker) ...[const Joker(1), const Joker(2)],
  ]..shuffle(rnd);
  final wilds = pool.where(mode.isWild).toList();
  final want = rnd.nextInt(min(2, wilds.length) + 1);
  final hand = <PlayingCard>[...wilds.take(want)];
  for (final card in pool) {
    if (hand.length == size) break;
    if (!mode.isWild(card)) hand.add(card);
  }
  return hand;
}

/// Every natural hand obtained by replacing the wilds with distinct real cards not already held.
Iterable<List<StandardCard>> _bruteForce(
    List<PlayingCard> hand, WildMode mode, List<StandardCard> full) sync* {
  final fixed =
      hand.where((c) => !mode.isWild(c)).cast<StandardCard>().toList();
  final k = hand.length - fixed.length;
  final pool = full.where((c) => !fixed.contains(c)).toList();
  if (k == 0) {
    yield fixed;
  } else if (k == 1) {
    for (final a in pool) {
      yield [...fixed, a];
    }
  } else {
    for (var i = 0; i < pool.length; i++) {
      for (var j = i + 1; j < pool.length; j++) {
        yield [...fixed, pool[i], pool[j]];
      }
    }
  }
}
