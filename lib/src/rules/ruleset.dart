import '../board/board.dart';
import '../hands/hand_rank.dart';

/// Royalties of one board, per row. All zero on a foul.
class Royalties {
  const Royalties(
      {required this.top, required this.middle, required this.bottom});

  static const none = Royalties(top: 0, middle: 0, bottom: 0);

  final int top;
  final int middle;
  final int bottom;

  int get total => top + middle + bottom;

  int of(BoardRow row) => switch (row) {
        BoardRow.top => top,
        BoardRow.middle => middle,
        BoardRow.bottom => bottom,
      };
}

/// Scoring constants and royalty tables (standard Pineapple OFC).
class Ruleset {
  const Ruleset({this.sweepBonus = 3, this.foulPenalty = 6});

  static const standard = Ruleset();

  /// Extra points for winning all three rows.
  final int sweepBonus;

  /// Points a fouled board pays the opponent.
  final int foulPenalty;

  /// Top: 66 pays 1 up to AA 9; trips 222 pay 10 up to AAA 22.
  int royaltyTop(Hand3Rank r) => switch (r.category) {
        Hand3Category.threeOfAKind => r.tiebreakers.first + 8,
        Hand3Category.pair =>
          r.tiebreakers.first >= 6 ? r.tiebreakers.first - 5 : 0,
        Hand3Category.highCard => 0,
      };

  int royaltyMiddle(Hand5Rank r) => switch (r.category) {
        Hand5Category.straightFlush => r.isRoyalFlush ? 50 : 30,
        Hand5Category.fourOfAKind => 20,
        Hand5Category.fullHouse => 12,
        Hand5Category.flush => 8,
        Hand5Category.straight => 4,
        Hand5Category.threeOfAKind => 2,
        _ => 0,
      };

  int royaltyBottom(Hand5Rank r) => switch (r.category) {
        Hand5Category.straightFlush => r.isRoyalFlush ? 25 : 15,
        Hand5Category.fourOfAKind => 10,
        Hand5Category.fullHouse => 6,
        Hand5Category.flush => 4,
        Hand5Category.straight => 2,
        _ => 0,
      };

  Royalties royalties(BoardEvaluation e) => e.isFoul
      ? Royalties.none
      : Royalties(
          top: royaltyTop(e.top),
          middle: royaltyMiddle(e.middle),
          bottom: royaltyBottom(e.bottom),
        );
}
