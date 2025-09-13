import 'hand_category3.dart';
import 'hand_category5.dart';

class Ruleset {
  final int sweepBonus; // +3
  final int foulPenalty; // -6 for fouler, +6 to opponent
  const Ruleset({this.sweepBonus = 3, this.foulPenalty = 6});

  static const defaultRules = Ruleset();

  int royaltyTop(Hand3Rank r) {
    if (r.category == Hand3Category.threeOfAKind) {
      final rank = r.tiebreakers.first;
      // 222:+7, 333:+8, ..., KKK:+18, AAA:+22 (docsの例/ベースライン)
      if (rank == 14) return 22; // AAA
      return switch (rank) {
        2 => 7,
        3 => 8,
        4 => 9,
        5 => 10,
        6 => 11,
        7 => 12,
        8 => 13,
        9 => 14,
        10 => 15,
        11 => 16,
        12 => 17,
        13 => 18,
        _ => 0,
      };
    }
    if (r.category == Hand3Category.pair) {
      final pair = r.tiebreakers.first;
      if (pair >= 6 && pair <= 10) return 1; // 66–TT
      return switch (pair) {
        11 => 2, // JJ
        12 => 3, // QQ
        13 => 4, // KK
        14 => 5, // AA
        _ => 0,
      };
    }
    return 0;
  }

  int royaltyMiddle(Hand5Rank r) {
    return switch (r.category) {
      Hand5Category.threeOfAKind => 2,
      Hand5Category.straight => 4,
      Hand5Category.flush => 8,
      Hand5Category.fullHouse => 12,
      Hand5Category.fourOfAKind => 20,
      Hand5Category.straightFlush => 30,
      _ => 0,
    };
  }

  int royaltyBottom(Hand5Rank r) {
    return switch (r.category) {
      Hand5Category.straight => 2,
      Hand5Category.flush => 4,
      Hand5Category.fullHouse => 6,
      Hand5Category.fourOfAKind => 10,
      Hand5Category.straightFlush => 15,
      _ => 0,
    };
  }
}
