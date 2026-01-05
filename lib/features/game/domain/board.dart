import '../../../core/models/playing_card.dart';
import '../../../core/models/rank.dart';
import 'game_options.dart';
import 'hand_category3.dart';
import 'hand_category5.dart';
import 'hand_evaluator.dart';

class Board {
  final List<PlayingCard> top; // 3 cards
  final List<PlayingCard> middle; // 5 cards
  final List<PlayingCard> bottom; // 5 cards
  const Board({required this.top, required this.middle, required this.bottom});
}

class BoardEval {
  final Hand3Rank top;
  final Hand5Rank middle;
  final Hand5Rank bottom;
  const BoardEval(
      {required this.top, required this.middle, required this.bottom});

  factory BoardEval.from(Board b, {WildMode wildMode = WildMode.none}) {
    if (wildMode == WildMode.deuces) {
      final middle = HandEvaluator.evaluate5DeucesWild(b.middle);
      final bottom = HandEvaluator.evaluate5DeucesWild(b.bottom);
      // Optimize top with context-awareness to avoid foul
      final top = _optimizeTopDeucesWild(b.top, middle);
      return BoardEval(top: top, middle: middle, bottom: bottom);
    }
    if (wildMode == WildMode.joker) {
      final middle = HandEvaluator.evaluate5JokerWild(b.middle);
      final bottom = HandEvaluator.evaluate5JokerWild(b.bottom);
      // Optimize top with context-awareness to avoid foul
      final top = _optimizeTopJokerWild(b.top, middle);
      return BoardEval(top: top, middle: middle, bottom: bottom);
    }
    return BoardEval(
      top: HandEvaluator.evaluate3(b.top),
      middle: HandEvaluator.evaluate5(b.middle),
      bottom: HandEvaluator.evaluate5(b.bottom),
    );
  }

  /// Optimize top hand with jokers to avoid foul when possible.
  /// Tries the best evaluation first, then finds alternatives if it would cause foul.
  static Hand3Rank _optimizeTopJokerWild(
      List<PlayingCard> topCards, Hand5Rank middle) {
    final jokerCount = topCards.where((c) => c.isJoker).length;
    if (jokerCount == 0) {
      // No jokers, just evaluate normally
      return HandEvaluator.evaluate3JokerWild(topCards);
    }

    final nonJokers = topCards.where((c) => !c.isJoker).toList();
    final nonJokerRanks = nonJokers.map((c) => c.rank!.value).toList()..sort();

    // Try best evaluation first
    final bestEval = HandEvaluator.evaluate3JokerWild(topCards);
    if (!_wouldCauseFoul(bestEval, middle)) {
      return bestEval;
    }

    // Best eval would cause foul; try to find alternative
    // Try different joker values from high to low to find one that doesn't foul
    final alternativeEval =
        _findNonFoulingEval(nonJokerRanks, jokerCount, middle);
    return alternativeEval ?? bestEval;
  }

  /// Check if top rank would cause foul against middle
  static bool _wouldCauseFoul(Hand3Rank top, Hand5Rank middle) {
    final topAs5 = _asFive(top);
    return _compare5(middle, topAs5) < 0; // middle < top means foul
  }

  static Hand5Rank _asFive(Hand3Rank r) {
    switch (r.category) {
      case Hand3Category.threeOfAKind:
        return Hand5Rank(Hand5Category.threeOfAKind, [r.tiebreakers[0]]);
      case Hand3Category.pair:
        return Hand5Rank(
            Hand5Category.onePair, [r.tiebreakers[0], r.tiebreakers[1]]);
      case Hand3Category.highCard:
        return Hand5Rank(Hand5Category.highCard, List<int>.from(r.tiebreakers));
    }
  }

  static int _compare5(Hand5Rank a, Hand5Rank b) {
    final c = a.category.index.compareTo(b.category.index);
    if (c != 0) return c > 0 ? 1 : -1;
    for (var i = 0; i < a.tiebreakers.length && i < b.tiebreakers.length; i++) {
      final d = a.tiebreakers[i].compareTo(b.tiebreakers[i]);
      if (d != 0) return d > 0 ? 1 : -1;
    }
    return 0;
  }

  /// Find a non-fouling evaluation for top with jokers
  static Hand3Rank? _findNonFoulingEval(
      List<int> nonJokerRanks, int jokerCount, Hand5Rank middle) {
    // Count non-joker ranks
    final counts = <int, int>{};
    for (final r in nonJokerRanks) {
      counts[r] = (counts[r] ?? 0) + 1;
    }
    final maxCount =
        counts.isEmpty ? 0 : counts.values.reduce((a, b) => a > b ? a : b);

    // Natural pair exists: joker can make trips
    // This might be valid if trips <= middle
    if (jokerCount == 1 && maxCount >= 2) {
      final pairRank = counts.entries.firstWhere((e) => e.value >= 2).key;
      final tripsRank =
          Hand3Rank(Hand3Category.threeOfAKind, [pairRank], isWild: true);
      if (!_wouldCauseFoul(tripsRank, middle)) {
        return tripsRank;
      }
      // Trips would foul; try pair instead
      final otherRanks = nonJokerRanks.where((r) => r != pairRank).toList();
      final kicker =
          otherRanks.isEmpty ? 14 : otherRanks.reduce((a, b) => a > b ? a : b);
      final pairEval =
          Hand3Rank(Hand3Category.pair, [pairRank, kicker], isWild: true);
      if (!_wouldCauseFoul(pairEval, middle)) {
        return pairEval;
      }
    }

    // Try different high card configurations with joker at various values
    // Try joker values from high (14=Ace) down to low (2)
    for (int jokerVal = 14; jokerVal >= 2; jokerVal--) {
      // Skip if joker would match a non-joker rank (creating a pair)
      if (nonJokerRanks.contains(jokerVal)) continue;

      final allRanks = [...nonJokerRanks];
      for (int j = 0; j < jokerCount; j++) {
        allRanks.add(jokerVal);
      }
      allRanks.sort((a, b) => b - a);

      final evalTry = Hand3Rank(
          Hand3Category.highCard, allRanks.take(3).toList(),
          isWild: true);
      if (!_wouldCauseFoul(evalTry, middle)) {
        return evalTry;
      }
    }

    return null; // No alternative found
  }

  /// Optimize top hand with deuces to avoid foul when possible.
  /// Tries the best evaluation first, then finds alternatives if it would cause foul.
  static Hand3Rank _optimizeTopDeucesWild(
      List<PlayingCard> topCards, Hand5Rank middle) {
    final deuceCount = topCards.where((c) => c.rank == Rank.two).length;
    if (deuceCount == 0) {
      // No deuces, just evaluate normally
      return HandEvaluator.evaluate3DeucesWild(topCards);
    }

    final nonDeuces = topCards.where((c) => c.rank != Rank.two).toList();
    final nonDeuceRanks = nonDeuces.map((c) => c.rank!.value).toList()..sort();

    // Try best evaluation first
    final bestEval = HandEvaluator.evaluate3DeucesWild(topCards);
    if (!_wouldCauseFoul(bestEval, middle)) {
      return bestEval;
    }

    // Best eval would cause foul; try to find alternative
    final alternativeEval =
        _findNonFoulingEvalDeuces(nonDeuceRanks, deuceCount, middle);
    return alternativeEval ?? bestEval;
  }

  /// Find a non-fouling evaluation for top with deuces
  static Hand3Rank? _findNonFoulingEvalDeuces(
      List<int> nonDeuceRanks, int deuceCount, Hand5Rank middle) {
    // Count non-deuce ranks
    final counts = <int, int>{};
    for (final r in nonDeuceRanks) {
      counts[r] = (counts[r] ?? 0) + 1;
    }
    final maxCount =
        counts.isEmpty ? 0 : counts.values.reduce((a, b) => a > b ? a : b);

    // Natural pair exists: deuce can make trips
    // This might be valid if trips <= middle
    if (deuceCount == 1 && maxCount >= 2) {
      final pairRank = counts.entries.firstWhere((e) => e.value >= 2).key;
      final tripsRank =
          Hand3Rank(Hand3Category.threeOfAKind, [pairRank], isWild: true);
      if (!_wouldCauseFoul(tripsRank, middle)) {
        return tripsRank;
      }
      // Trips would foul; try pair instead
      final otherRanks = nonDeuceRanks.where((r) => r != pairRank).toList();
      final kicker =
          otherRanks.isEmpty ? 14 : otherRanks.reduce((a, b) => a > b ? a : b);
      final pairEval =
          Hand3Rank(Hand3Category.pair, [pairRank, kicker], isWild: true);
      if (!_wouldCauseFoul(pairEval, middle)) {
        return pairEval;
      }
    }

    // Try making a pair with deuces
    // Deuces can become any rank to form a pair
    // Try highest rank pairs first (Aces down)
    for (int pairVal = 14; pairVal >= 3; pairVal--) {
      // Skip ranks that exist in non-deuces (would need 2+ to make trips, not pair)
      // For pair: deuce becomes pairVal, paired with a non-deuce of pairVal
      // Or: two deuces become a pair of pairVal

      List<int> allRanks;
      if (deuceCount >= 2) {
        // Two+ deuces can become a pair of any rank
        allRanks = [...nonDeuceRanks, pairVal, pairVal];
        if (deuceCount > 2) {
          // Third deuce becomes highest kicker
          allRanks.add(14);
        }
      } else {
        // One deuce: can pair with a non-deuce rank
        if (nonDeuceRanks.contains(pairVal)) {
          // Deuce matches an existing card
          allRanks = [...nonDeuceRanks, pairVal];
        } else {
          continue; // Can't make this pair with one deuce
        }
      }

      // Build the hand from allRanks
      final testCounts = <int, int>{};
      for (final r in allRanks) {
        testCounts[r] = (testCounts[r] ?? 0) + 1;
      }

      // Check if we have a pair (not trips or better)
      final pairs = testCounts.entries.where((e) => e.value == 2).toList();
      final trips = testCounts.entries.where((e) => e.value >= 3).toList();

      if (trips.isNotEmpty) continue; // Skip if it makes trips

      if (pairs.isNotEmpty) {
        final pair = pairs.reduce((a, b) => a.key > b.key ? a : b);
        final kickers = allRanks.where((r) => r != pair.key).toList()
          ..sort((a, b) => b - a);
        final kicker = kickers.isEmpty ? 14 : kickers.first;
        final pairEval =
            Hand3Rank(Hand3Category.pair, [pair.key, kicker], isWild: true);
        if (!_wouldCauseFoul(pairEval, middle)) {
          return pairEval;
        }
      }
    }

    // Try high card configurations with deuces at various values
    for (int deuceVal = 14; deuceVal >= 3; deuceVal--) {
      // Skip if deuce value would match a non-deuce rank (creating a pair)
      if (nonDeuceRanks.contains(deuceVal)) continue;

      final allRanks = [...nonDeuceRanks];
      for (int d = 0; d < deuceCount; d++) {
        // Each additional deuce at a different value
        var val = deuceVal - d;
        while (allRanks.contains(val) || val <= 2) {
          val--;
        }
        if (val >= 3) allRanks.add(val);
      }
      allRanks.sort((a, b) => b - a);

      // Ensure no pairs
      final testCounts = <int, int>{};
      for (final r in allRanks) {
        testCounts[r] = (testCounts[r] ?? 0) + 1;
      }
      if (testCounts.values.any((c) => c >= 2)) continue;

      final evalTry = Hand3Rank(
          Hand3Category.highCard, allRanks.take(3).toList(),
          isWild: true);
      if (!_wouldCauseFoul(evalTry, middle)) {
        return evalTry;
      }
    }

    return null; // No alternative found
  }
}
