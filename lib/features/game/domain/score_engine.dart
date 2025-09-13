import 'board.dart';
import 'foul_checker.dart';
import 'hand_category3.dart';
import 'hand_category5.dart';
import 'ruleset.dart';

class RowResult {
  final int bottom; // +1/0/-1 from A's perspective
  final int middle;
  final int top;
  const RowResult(
      {required this.bottom, required this.middle, required this.top});

  int get sum => bottom + middle + top;
}

class ScoreBreakdown {
  final RowResult rows;
  final int sweep;
  final int royalties;
  final int foul; // -6 if fouled, else 0
  const ScoreBreakdown(
      {required this.rows,
      required this.sweep,
      required this.royalties,
      required this.foul});

  int get total => rows.sum + sweep + royalties + foul;
}

class VersusScore {
  final ScoreBreakdown a;
  final ScoreBreakdown b;
  const VersusScore(this.a, this.b);
}

class ScoreEngine {
  static VersusScore compare(Board a, Board b,
      {Ruleset ruleset = Ruleset.defaultRules}) {
    final ea = BoardEval.from(a);
    final eb = BoardEval.from(b);
    final afoul = FoulChecker.isFoul(ea);
    final bfoul = FoulChecker.isFoul(eb);

    if (afoul && bfoul) {
      final zeroRows = RowResult(bottom: 0, middle: 0, top: 0);
      return VersusScore(
        ScoreBreakdown(rows: zeroRows, sweep: 0, royalties: 0, foul: 0),
        ScoreBreakdown(rows: zeroRows, sweep: 0, royalties: 0, foul: 0),
      );
    }

    if (afoul && !bfoul) {
      final zeroRows = RowResult(bottom: 0, middle: 0, top: 0);
      return VersusScore(
        ScoreBreakdown(
            rows: zeroRows, sweep: 0, royalties: 0, foul: -ruleset.foulPenalty),
        ScoreBreakdown(
            rows: zeroRows, sweep: 0, royalties: 0, foul: ruleset.foulPenalty),
      );
    }
    if (!afoul && bfoul) {
      final zeroRows = RowResult(bottom: 0, middle: 0, top: 0);
      return VersusScore(
        ScoreBreakdown(
            rows: zeroRows, sweep: 0, royalties: 0, foul: ruleset.foulPenalty),
        ScoreBreakdown(
            rows: zeroRows, sweep: 0, royalties: 0, foul: -ruleset.foulPenalty),
      );
    }

    final bottom = _compare5(ea.bottom, eb.bottom);
    final middle = _compare5(ea.middle, eb.middle);
    final top = _compare3(ea.top, eb.top);
    final rows = RowResult(bottom: bottom, middle: middle, top: top);

    final aSweep = (rows.sum == 3) ? ruleset.sweepBonus : 0;
    final bSweep = (rows.sum == -3) ? ruleset.sweepBonus : 0;

    final aRoyal = ruleset.royaltyTop(ea.top) +
        ruleset.royaltyMiddle(ea.middle) +
        ruleset.royaltyBottom(ea.bottom);
    final bRoyal = ruleset.royaltyTop(eb.top) +
        ruleset.royaltyMiddle(eb.middle) +
        ruleset.royaltyBottom(eb.bottom);

    return VersusScore(
      ScoreBreakdown(rows: rows, sweep: aSweep, royalties: aRoyal, foul: 0),
      ScoreBreakdown(
          rows: RowResult(bottom: -bottom, middle: -middle, top: -top),
          sweep: bSweep,
          royalties: bRoyal,
          foul: 0),
    );
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

  static int _compare3(Hand3Rank a, Hand3Rank b) {
    final c = a.category.index.compareTo(b.category.index);
    if (c != 0) return c > 0 ? 1 : -1;
    for (var i = 0; i < a.tiebreakers.length && i < b.tiebreakers.length; i++) {
      final d = a.tiebreakers[i].compareTo(b.tiebreakers[i]);
      if (d != 0) return d > 0 ? 1 : -1;
    }
    return 0;
  }
}
