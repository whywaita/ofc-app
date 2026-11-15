import '../board/board.dart';
import '../rules/ruleset.dart';

/// Row results from one player's side: +1 win, 0 tie, -1 loss.
class RowResults {
  const RowResults(
      {required this.top, required this.middle, required this.bottom});

  static const zero = RowResults(top: 0, middle: 0, bottom: 0);

  final int top;
  final int middle;
  final int bottom;

  int get sum => top + middle + bottom;

  RowResults get negated =>
      RowResults(top: -top, middle: -middle, bottom: -bottom);
}

/// One player's points for a hand.
class ScoreBreakdown {
  const ScoreBreakdown({
    required this.rows,
    required this.sweep,
    required this.royalties,
    required this.foul,
  });

  final RowResults rows;

  /// The sweep bonus: positive for the side that won all three rows, negative for the other.
  final int sweep;

  /// Royalties won net of the opponent's.
  final int royalties;

  /// Foul points: negative for the player who fouled, positive for the opponent.
  final int foul;

  int get total => rows.sum + sweep + royalties + foul;

  /// The same hand from the opponent's side.
  ScoreBreakdown get negated => ScoreBreakdown(
      rows: rows.negated, sweep: -sweep, royalties: -royalties, foul: -foul);
}

class VersusScore {
  const VersusScore(this.a, this.b);

  final ScoreBreakdown a;
  final ScoreBreakdown b;
}

/// Scores two evaluated boards against each other.
class ScoreEngine {
  const ScoreEngine([this.ruleset = Ruleset.standard]);

  final Ruleset ruleset;

  /// Scores [a] against [b]. Every component is zero-sum: B's breakdown is A's negated.
  ///
  /// * Neither fouls: one point per row, the sweep bonus when one side wins all three, and the
  ///   difference of the two sides' royalties.
  /// * One fouls: the fouler pays the foul penalty (which stands for losing every row and the
  ///   sweep) plus the opponent's royalties; the fouler's own royalties are void.
  /// * Both foul: nothing changes hands.
  VersusScore compare(BoardEvaluation a, BoardEvaluation b) {
    final ScoreBreakdown forA;
    if (a.isFoul && b.isFoul) {
      forA = const ScoreBreakdown(
          rows: RowResults.zero, sweep: 0, royalties: 0, foul: 0);
    } else if (a.isFoul || b.isFoul) {
      // Royalties of a fouled board are zero, so this nets to the clean side's royalties.
      forA = ScoreBreakdown(
        rows: RowResults.zero,
        sweep: 0,
        royalties: _netRoyalties(a, b),
        foul: a.isFoul ? -ruleset.foulPenalty : ruleset.foulPenalty,
      );
    } else {
      final rows = RowResults(
        top: a.top.compareTo(b.top),
        middle: a.middle.compareTo(b.middle),
        bottom: a.bottom.compareTo(b.bottom),
      );
      forA = ScoreBreakdown(
        rows: rows,
        sweep: switch (rows.sum) {
          3 => ruleset.sweepBonus,
          -3 => -ruleset.sweepBonus,
          _ => 0,
        },
        royalties: _netRoyalties(a, b),
        foul: 0,
      );
    }
    return VersusScore(forA, forA.negated);
  }

  int _netRoyalties(BoardEvaluation a, BoardEvaluation b) =>
      ruleset.royalties(a).total - ruleset.royalties(b).total;
}
