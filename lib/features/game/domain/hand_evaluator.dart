import '../../../core/models/playing_card.dart';
import '../../../core/models/rank.dart';
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

  // ========== Deuces Wild Evaluation ==========

  /// Deuces Wild: 5-card hand evaluation
  static Hand5Rank evaluate5DeucesWild(List<PlayingCard> cards) {
    if (cards.length != 5) {
      throw ArgumentError('Need 5 cards');
    }

    final deuces = cards.where((c) => c.rank == Rank.two).length;
    final nonDeuces = cards.where((c) => c.rank != Rank.two).toList();

    if (deuces == 0) {
      return evaluate5(cards);
    }

    return _findBestWithDeuces5(nonDeuces, deuces);
  }

  /// Deuces Wild: 3-card hand evaluation
  static Hand3Rank evaluate3DeucesWild(List<PlayingCard> cards) {
    if (cards.length != 3) {
      throw ArgumentError('Need 3 cards');
    }

    final deuces = cards.where((c) => c.rank == Rank.two).length;
    final nonDeuces = cards.where((c) => c.rank != Rank.two).toList();

    if (deuces == 0) {
      return evaluate3(cards);
    }

    return _findBestWithDeuces3(nonDeuces, deuces);
  }

  /// Find best 5-card hand with deuces as wild cards
  static Hand5Rank _findBestWithDeuces5(
      List<PlayingCard> nonDeuces, int deuces) {
    final ranks = nonDeuces.map((c) => c.rank.value).toList()..sort();
    final suits = nonDeuces.map((c) => c.suit).toList();

    // Count ranks of non-deuces
    final counts = <int, int>{};
    for (final r in ranks) {
      counts[r] = (counts[r] ?? 0) + 1;
    }

    // Count suits of non-deuces
    final suitCounts = <dynamic, int>{};
    for (final s in suits) {
      suitCounts[s] = (suitCounts[s] ?? 0) + 1;
    }

    // Check Straight Flush (including Royal Flush)
    final sfHigh = _canMakeStraightFlush(nonDeuces, deuces);
    if (sfHigh != null) {
      return Hand5Rank(Hand5Category.straightFlush, [sfHigh], isWild: true);
    }

    // Check Four of a Kind
    // Need (4 - deuces) of the same rank among non-deuces
    final maxCount =
        counts.isEmpty ? 0 : counts.values.reduce((a, b) => a > b ? a : b);
    if (maxCount + deuces >= 4) {
      // Find the highest rank that can form Four of a Kind
      int fourRank = 0;
      for (final entry in counts.entries) {
        if (entry.value + deuces >= 4 && entry.key > fourRank) {
          fourRank = entry.key;
        }
      }
      // If all deuces, best Four of a Kind is Aces
      if (fourRank == 0 && deuces >= 4) {
        fourRank = 14; // Ace
      }
      // Kicker is highest non-four rank, or Ace if kicker is from deuces
      final remaining = ranks.where((r) => r != fourRank).toList();
      final kicker =
          remaining.isEmpty ? 14 : remaining.reduce((a, b) => a > b ? a : b);
      return Hand5Rank(Hand5Category.fourOfAKind, [fourRank, kicker],
          isWild: true);
    }

    // Check Full House
    // Need 3 of one rank + 2 of another rank (with deuces)
    if (_canMakeFullHouse(counts, deuces)) {
      final fhResult = _bestFullHouse(counts, deuces);
      return Hand5Rank(Hand5Category.fullHouse, fhResult, isWild: true);
    }

    // Check Flush
    // Need (5 - deuces) cards of the same suit
    final maxSuitCount = suitCounts.isEmpty
        ? 0
        : suitCounts.values.reduce((a, b) => a > b ? a : b);
    if (maxSuitCount + deuces >= 5) {
      // Find the flush suit
      final flushSuit =
          suitCounts.entries.firstWhere((e) => e.value == maxSuitCount).key;
      final flushRanks = nonDeuces
          .where((c) => c.suit == flushSuit)
          .map((c) => c.rank.value)
          .toList()
        ..sort((a, b) => b - a);
      // Fill with Aces for deuces
      while (flushRanks.length < 5) {
        flushRanks.add(14); // Ace as wild
      }
      return Hand5Rank(Hand5Category.flush, flushRanks.take(5).toList(),
          isWild: true);
    }

    // Check Straight
    final straightHigh = _canMakeStraight(ranks, deuces);
    if (straightHigh != null) {
      return Hand5Rank(Hand5Category.straight, [straightHigh], isWild: true);
    }

    // Check Three of a Kind
    if (maxCount + deuces >= 3) {
      int threeRank = 0;
      for (final entry in counts.entries) {
        if (entry.value + deuces >= 3 && entry.key > threeRank) {
          threeRank = entry.key;
        }
      }
      if (threeRank == 0 && deuces >= 3) {
        threeRank = 14; // Ace
      }
      final kickers = ranks.where((r) => r != threeRank).toList()
        ..sort((a, b) => b - a);
      // Fill with best kickers (Ace, King...)
      while (kickers.length < 2) {
        kickers.add(kickers.isEmpty ? 14 : 13);
      }
      return Hand5Rank(
          Hand5Category.threeOfAKind, [threeRank, ...kickers.take(2)],
          isWild: true);
    }

    // Check Two Pair (only possible with 1 deuce and existing pair)
    final pairsInHand = counts.entries.where((e) => e.value >= 2).length;
    if (pairsInHand >= 2) {
      // Natural two pair (no deuces needed for this)
      final pairRanks = counts.entries
          .where((e) => e.value >= 2)
          .map((e) => e.key)
          .toList()
        ..sort((a, b) => b - a);
      final kicker = ranks.where((r) => !pairRanks.contains(r)).isEmpty
          ? 14
          : ranks
              .where((r) => !pairRanks.contains(r))
              .reduce((a, b) => a > b ? a : b);
      return Hand5Rank(
          Hand5Category.twoPair, [pairRanks[0], pairRanks[1], kicker],
          isWild: true);
    }
    if (pairsInHand >= 1 && deuces >= 1) {
      // One natural pair + deuce makes three of a kind (handled above)
      // So two pair with deuces is: 1 pair + 1 deuce forms another pair
      // But actually deuce would upgrade to three of a kind, which is better
      // So two pair with deuces is rare - skip to one pair
    }

    // Check One Pair (with deuces, always possible)
    if (deuces >= 1) {
      // Best pair: Aces (deuce becomes Ace to pair with highest card or itself)
      final highestNonDeuce =
          ranks.isEmpty ? 0 : ranks.reduce((a, b) => a > b ? a : b);
      final pairRank = highestNonDeuce > 0 ? highestNonDeuce : 14;
      final kickers = ranks.where((r) => r != pairRank).toList()
        ..sort((a, b) => b - a);
      while (kickers.length < 3) {
        kickers.add(14); // Fill with Aces
      }
      return Hand5Rank(Hand5Category.onePair, [pairRank, ...kickers.take(3)],
          isWild: true);
    }

    // High card (shouldn't reach here with deuces > 0)
    final highs = ranks.reversed.toList();
    return Hand5Rank(Hand5Category.highCard, highs, isWild: true);
  }

  /// Check if Straight Flush can be made, returns high card value or null
  static int? _canMakeStraightFlush(List<PlayingCard> nonDeuces, int deuces) {
    if (nonDeuces.isEmpty) {
      // All deuces: make Royal Flush
      return 14;
    }

    // Group by suit
    final bySuit = <dynamic, List<int>>{};
    for (final c in nonDeuces) {
      bySuit.putIfAbsent(c.suit, () => []).add(c.rank.value);
    }

    int? bestHigh;
    for (final suitRanks in bySuit.values) {
      if (suitRanks.length + deuces < 5) continue;

      suitRanks.sort();
      final uniqueRanks = suitRanks.toSet().toList()..sort();

      // Check each possible straight high (14 down to 5)
      for (int high = 14; high >= 5; high--) {
        final needed = <int>[];
        if (high == 5) {
          // Wheel: A-2-3-4-5, but 2 is wild, so need A,3,4,5
          needed.addAll([14, 3, 4, 5]);
        } else {
          for (int r = high; r > high - 5; r--) {
            if (r != 2) needed.add(r); // 2 is wild, don't need it
          }
        }
        final have = uniqueRanks.where((r) => needed.contains(r)).length;
        final gaps = needed.length - have;
        if (gaps <= deuces) {
          if (bestHigh == null || high > bestHigh) {
            bestHigh = high;
            break; // Found best for this suit
          }
        }
      }
    }
    return bestHigh;
  }

  /// Check if Straight can be made, returns high card value or null
  static int? _canMakeStraight(List<int> ranks, int deuces) {
    if (ranks.isEmpty && deuces >= 5) {
      return 14; // Royal straight with all deuces
    }

    final uniqueRanks = ranks.toSet().toList()..sort();

    // Check each possible straight high (14 down to 5)
    for (int high = 14; high >= 5; high--) {
      final needed = <int>[];
      if (high == 5) {
        // Wheel: A-2-3-4-5, but 2 is wild
        needed.addAll([14, 3, 4, 5]);
      } else {
        for (int r = high; r > high - 5; r--) {
          if (r != 2) needed.add(r); // 2 is wild
        }
      }
      final have = uniqueRanks.where((r) => needed.contains(r)).length;
      final gaps = needed.length - have;
      if (gaps <= deuces && uniqueRanks.length + deuces >= 5) {
        // Also check no duplicate ranks
        if (uniqueRanks.length <= 5) {
          return high;
        }
      }
    }
    return null;
  }

  /// Check if Full House can be made
  static bool _canMakeFullHouse(Map<int, int> counts, int deuces) {
    if (counts.isEmpty) {
      return deuces >= 5; // All deuces: AAA + KK
    }

    final sortedCounts = counts.values.toList()..sort((a, b) => b - a);

    // Need 3 + 2 total
    // Best case: highest count becomes 3, second becomes 2
    if (sortedCounts.length >= 2) {
      final needFor3 = 3 - sortedCounts[0];
      final needFor2 = 2 - sortedCounts[1];
      if (needFor3 >= 0 && needFor2 >= 0 && needFor3 + needFor2 <= deuces) {
        return true;
      }
    }
    if (sortedCounts.length == 1) {
      // One rank: make it 3 or 5
      final c = sortedCounts[0];
      if (c + deuces >= 5) {
        // e.g., 3 of a rank + 2 deuces = full house (3+2)
        return deuces >= 2 && c >= 3 || deuces >= 3 && c >= 2;
      }
    }
    return false;
  }

  /// Get best Full House configuration
  static List<int> _bestFullHouse(Map<int, int> counts, int deuces) {
    // Sort by count desc, then by rank desc
    final entries = counts.entries.toList()
      ..sort((a, b) {
        final c = b.value.compareTo(a.value);
        if (c != 0) return c;
        return b.key.compareTo(a.key);
      });

    if (entries.isEmpty) {
      return [14, 13]; // Aces full of Kings
    }

    if (entries.length == 1) {
      final rank = entries[0].key;
      // If we have 3+ of this rank, make it trips and pair of Aces (or next best)
      return [rank, 14];
    }

    // Have at least 2 different ranks
    final threeRank = entries[0].key;
    final pairRank = entries[1].key;
    return [threeRank, pairRank];
  }

  /// Find best 3-card hand with deuces as wild cards
  static Hand3Rank _findBestWithDeuces3(
      List<PlayingCard> nonDeuces, int deuces) {
    final ranks = nonDeuces.map((c) => c.rank.value).toList()..sort();

    // Count ranks
    final counts = <int, int>{};
    for (final r in ranks) {
      counts[r] = (counts[r] ?? 0) + 1;
    }

    final maxCount =
        counts.isEmpty ? 0 : counts.values.reduce((a, b) => a > b ? a : b);

    // Check Three of a Kind
    // Need (3 - deuces) of the same rank, or all deuces
    if (maxCount + deuces >= 3) {
      int threeRank = 0;
      for (final entry in counts.entries) {
        if (entry.value + deuces >= 3 && entry.key > threeRank) {
          threeRank = entry.key;
        }
      }
      if (threeRank == 0) {
        threeRank = 14; // All deuces -> Aces
      }
      return Hand3Rank(Hand3Category.threeOfAKind, [threeRank], isWild: true);
    }

    // Check Pair
    // With deuces, can always make at least a pair
    if (deuces >= 1 || maxCount >= 2) {
      int pairRank = 0;
      // Find best pair rank
      for (final entry in counts.entries) {
        if (entry.value + deuces >= 2 && entry.key > pairRank) {
          pairRank = entry.key;
        }
      }
      if (pairRank == 0 && deuces >= 2) {
        pairRank = 14; // Two deuces -> pair of Aces
      } else if (pairRank == 0 && deuces == 1 && ranks.isNotEmpty) {
        pairRank = ranks.reduce((a, b) => a > b ? a : b);
      }
      final kickers = ranks.where((r) => r != pairRank).toList();
      final kicker =
          kickers.isEmpty ? 14 : kickers.reduce((a, b) => a > b ? a : b);
      return Hand3Rank(Hand3Category.pair, [pairRank, kicker], isWild: true);
    }

    // High card (shouldn't reach here with deuces > 0)
    return Hand3Rank(Hand3Category.highCard, ranks.reversed.toList(),
        isWild: true);
  }
}
