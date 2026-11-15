import '../cards/playing_card.dart';
import '../hands/hand_evaluator.dart';
import '../hands/hand_rank.dart';
import '../rules/game_options.dart';

/// The three rows of a board, top to bottom.
enum BoardRow {
  top(3),
  middle(5),
  bottom(5);

  const BoardRow(this.capacity);

  final int capacity;
}

/// A player's cards by row. Immutable.
class Board {
  Board({
    required List<PlayingCard> top,
    required List<PlayingCard> middle,
    required List<PlayingCard> bottom,
  })  : top = List.unmodifiable(top),
        middle = List.unmodifiable(middle),
        bottom = List.unmodifiable(bottom);

  final List<PlayingCard> top;
  final List<PlayingCard> middle;
  final List<PlayingCard> bottom;

  List<PlayingCard> row(BoardRow r) => switch (r) {
        BoardRow.top => top,
        BoardRow.middle => middle,
        BoardRow.bottom => bottom,
      };

  Iterable<PlayingCard> get cards => [...top, ...middle, ...bottom];

  bool get isComplete =>
      BoardRow.values.every((r) => row(r).length == r.capacity);
}

/// The made hand of every row of a complete board, and whether the board fouls.
///
/// Wild cards are assigned for the player's benefit: the bottom takes its strongest hand, the
/// middle the strongest hand not above the bottom, the top the strongest not above the middle.
/// That one greedy pass maximises every row at once among the boards that do not foul (a stronger
/// row only loosens the limit on the row above it), so it is the best outcome for scoring,
/// royalties and Fantasyland alike. When no assignment avoids the foul, each row shows its
/// strongest hand.
class BoardEvaluation {
  const BoardEvaluation({
    required this.top,
    required this.middle,
    required this.bottom,
    required this.isFoul,
  });

  factory BoardEvaluation.of(Board board, {WildMode wildMode = WildMode.none}) {
    if (!board.isComplete) {
      throw ArgumentError('Board is not complete');
    }
    final ev = HandEvaluator(wildMode);
    final bottoms = ev.candidates5(board.bottom);
    final middles = ev.candidates5(board.middle);
    final tops = ev.candidates3(board.top);

    final bottom = _best(bottoms)!;
    final middle = _best(middles.where((m) => m.compareTo(bottom) <= 0));
    final top = middle == null
        ? null
        : _best(tops.where((t) => t.compareToFive(middle) <= 0));
    if (middle != null && top != null) {
      return BoardEvaluation(
          top: top, middle: middle, bottom: bottom, isFoul: false);
    }
    return BoardEvaluation(
      top: _best(tops)!,
      middle: _best(middles)!,
      bottom: bottom,
      isFoul: true,
    );
  }

  final Hand3Rank top;
  final Hand5Rank middle;
  final Hand5Rank bottom;
  final bool isFoul;
}

T? _best<T extends Comparable<T>>(Iterable<T> xs) {
  T? best;
  for (final x in xs) {
    if (best == null || x.compareTo(best) > 0) best = x;
  }
  return best;
}
