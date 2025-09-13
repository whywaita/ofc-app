import 'board.dart';
import 'hand_category3.dart';
import 'hand_category5.dart';

class FoulChecker {
  static bool isFoul(BoardEval e) {
    // 厳密比較（カテゴリだけでなくキッカーも考慮）。
    final okBottom = _compare5(e.bottom, e.middle) >= 0; // Bottom ≥ Middle
    final okMiddle = _compare5(e.middle, _asFive(e.top)) >= 0; // Middle ≥ Top(3枚を5枚相当化)
    return !(okBottom && okMiddle);
  }

  static Hand5Rank _asFive(Hand3Rank r) {
    switch (r.category) {
      case Hand3Category.threeOfAKind:
        return Hand5Rank(Hand5Category.threeOfAKind, [r.tiebreakers[0]]);
      case Hand3Category.pair:
        return Hand5Rank(Hand5Category.onePair, [r.tiebreakers[0], r.tiebreakers[1]]);
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
}
