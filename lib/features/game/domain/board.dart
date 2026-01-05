import '../../../core/models/playing_card.dart';
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
      return BoardEval(
        top: HandEvaluator.evaluate3DeucesWild(b.top),
        middle: HandEvaluator.evaluate5DeucesWild(b.middle),
        bottom: HandEvaluator.evaluate5DeucesWild(b.bottom),
      );
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
}
