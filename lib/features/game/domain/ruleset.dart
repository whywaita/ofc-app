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
      // 222:+10, 333:+11, ..., KKK:+21, AAA:+22
      if (rank == 14) return 22; // AAA
      return switch (rank) {
        2 => 10,
        3 => 11,
        4 => 12,
        5 => 13,
        6 => 14,
        7 => 15,
        8 => 16,
        9 => 17,
        10 => 18,
        11 => 19,
        12 => 20,
        13 => 21,
        _ => 0,
      };
    }
    if (r.category == Hand3Category.pair) {
      final pair = r.tiebreakers.first;
      // 66:+1, 77:+2, 88:+3, 99:+4, TT:+5, JJ:+6, QQ:+7, KK:+8, AA:+9
      return switch (pair) {
        6 => 1,
        7 => 2,
        8 => 3,
        9 => 4,
        10 => 5,
        11 => 6,
        12 => 7,
        13 => 8,
        14 => 9,
        _ => 0,
      };
    }
    return 0;
  }

  int royaltyMiddle(Hand5Rank r) {
    if (r.category == Hand5Category.straightFlush) {
      // Royal Flush (Ace-high straight flush) = 50, otherwise 30
      return (r.tiebreakers.isNotEmpty && r.tiebreakers[0] == 14) ? 50 : 30;
    }
    return switch (r.category) {
      Hand5Category.threeOfAKind => 2,
      Hand5Category.straight => 4,
      Hand5Category.flush => 8,
      Hand5Category.fullHouse => 12,
      Hand5Category.fourOfAKind => 20,
      _ => 0,
    };
  }

  int royaltyBottom(Hand5Rank r) {
    if (r.category == Hand5Category.straightFlush) {
      // Royal Flush (Ace-high straight flush) = 25, otherwise 15
      return (r.tiebreakers.isNotEmpty && r.tiebreakers[0] == 14) ? 25 : 15;
    }
    return switch (r.category) {
      Hand5Category.straight => 2,
      Hand5Category.flush => 4,
      Hand5Category.fullHouse => 6,
      Hand5Category.fourOfAKind => 10,
      _ => 0,
    };
  }
}
