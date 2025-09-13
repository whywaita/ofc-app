import '../../../core/models/playing_card.dart';
import 'hand_category3.dart';
import 'hand_category5.dart';

class HandEvaluator {
  static Hand5Rank evaluate5(List<PlayingCard> cards) {
    if (cards.length != 5) {
      throw ArgumentError('Need 5 cards');
    }
    final ranks = cards.map((c) => c.rank.value).toList()..sort();
    final suits = cards.map((c) => c.suit).toList();
    final isFlush = suits.toSet().length == 1;

    final uniqueRanks = ranks.toSet().toList()..sort();
    bool isStraight = false;
    int straightHigh = 0;
    if (uniqueRanks.length == 5) {
      // Regular straight
      if (ranks[4] - ranks[0] == 4) {
        isStraight = true;
        straightHigh = ranks[4];
      } else {
        // Wheel: A-2-3-4-5
        if (ranks[0] == 2 &&
            ranks[1] == 3 &&
            ranks[2] == 4 &&
            ranks[3] == 5 &&
            ranks[4] == 14) {
          isStraight = true;
          straightHigh = 5;
        }
      }
    }

    // Count ranks
    final counts = <int, int>{};
    for (final r in ranks) {
      counts[r] = (counts[r] ?? 0) + 1;
    }
    final sortedByCountThenRank = counts.keys.toList()
      ..sort((a, b) {
        final c = (counts[b]! - counts[a]!);
        if (c != 0) return c;
        return b - a; // high rank first
      });

    // Straight flush
    if (isStraight && isFlush) {
      return Hand5Rank(Hand5Category.straightFlush, [straightHigh]);
    }

    // Four of a kind
    if (counts.values.any((c) => c == 4)) {
      final four = sortedByCountThenRank.firstWhere((r) => counts[r] == 4);
      final kicker = sortedByCountThenRank.firstWhere((r) => counts[r] == 1);
      return Hand5Rank(Hand5Category.fourOfAKind, [four, kicker]);
    }

    // Full house
    if (counts.values.toSet().containsAll({3, 2})) {
      final three = sortedByCountThenRank.firstWhere((r) => counts[r] == 3);
      final pair = sortedByCountThenRank.firstWhere((r) => counts[r] == 2);
      return Hand5Rank(Hand5Category.fullHouse, [three, pair]);
    }

    // Flush
    if (isFlush) {
      final highs = ranks.reversed.toList();
      return Hand5Rank(Hand5Category.flush, highs);
    }

    // Straight
    if (isStraight) {
      return Hand5Rank(Hand5Category.straight, [straightHigh]);
    }

    // Three of a kind
    if (counts.values.any((c) => c == 3)) {
      final three = sortedByCountThenRank.firstWhere((r) => counts[r] == 3);
      final kickers = sortedByCountThenRank
          .where((r) => counts[r] == 1)
          .toList()
        ..sort((a, b) => b - a);
      return Hand5Rank(Hand5Category.threeOfAKind, [three, ...kickers]);
    }

    // Two pair
    final pairs = sortedByCountThenRank.where((r) => counts[r] == 2).toList();
    if (pairs.length == 2) {
      pairs.sort((a, b) => b - a);
      final kicker = sortedByCountThenRank.firstWhere((r) => counts[r] == 1);
      return Hand5Rank(Hand5Category.twoPair, [pairs[0], pairs[1], kicker]);
    }

    // One pair
    if (pairs.length == 1) {
      final pair = pairs.single;
      final kickers = sortedByCountThenRank
          .where((r) => counts[r] == 1)
          .toList()
        ..sort((a, b) => b - a);
      return Hand5Rank(Hand5Category.onePair, [pair, ...kickers]);
    }

    // High card
    final highs = ranks.reversed.toList();
    return Hand5Rank(Hand5Category.highCard, highs);
  }

  static Hand3Rank evaluate3(List<PlayingCard> cards) {
    if (cards.length != 3) {
      throw ArgumentError('Need 3 cards');
    }
    final ranks = cards.map((c) => c.rank.value).toList()..sort();
    final counts = <int, int>{};
    for (final r in ranks) {
      counts[r] = (counts[r] ?? 0) + 1;
    }
    if (counts.values.any((c) => c == 3)) {
      final trips = counts.entries.firstWhere((e) => e.value == 3).key;
      return Hand3Rank(Hand3Category.threeOfAKind, [trips]);
    }
    if (counts.values.any((c) => c == 2)) {
      final pair = counts.entries.firstWhere((e) => e.value == 2).key;
      final kicker = counts.entries.firstWhere((e) => e.value == 1).key;
      return Hand3Rank(Hand3Category.pair, [pair, kicker]);
    }
    return Hand3Rank(Hand3Category.highCard, ranks.reversed.toList());
  }
}
