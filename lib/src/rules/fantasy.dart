import '../board/board.dart';
import '../hands/hand_rank.dart';

/// Whether a player is in Fantasyland, and how many cards the Fantasy deal holds.
class FantasyState {
  const FantasyState.inactive() : initialCount = 0;

  const FantasyState.active(this.initialCount)
      : assert(initialCount > 5, 'a Fantasy deal holds more than 5 cards');

  /// Cards dealt at once in Fantasyland (14..17), or 0 when not in Fantasyland.
  final int initialCount;

  bool get isActive => initialCount > 0;

  /// Cards dealt at the start of the next hand: the Fantasy deal, or the usual 5.
  int get dealCount => isActive ? initialCount : 5;

  /// The state for the next hand after a hand that ended with [result].
  ///
  /// Entry (top QQ 14, KK 15, AA 16, trips 17) and staying in (top trips or bottom quads or better)
  /// both need a board that does not foul. Staying keeps the deal size of the entry.
  static FantasyState next(FantasyState current, BoardEvaluation result) {
    if (result.isFoul) return const FantasyState.inactive();
    if (current.isActive) {
      return _staysIn(result) ? current : const FantasyState.inactive();
    }
    final count = _entryCount(result.top);
    return count == 0
        ? const FantasyState.inactive()
        : FantasyState.active(count);
  }

  static int _entryCount(Hand3Rank top) => switch (top.category) {
        Hand3Category.threeOfAKind => 17,
        Hand3Category.pair => switch (top.tiebreakers.first) {
            12 => 14,
            13 => 15,
            14 => 16,
            _ => 0,
          },
        Hand3Category.highCard => 0,
      };

  static bool _staysIn(BoardEvaluation e) =>
      e.top.category == Hand3Category.threeOfAKind ||
      e.bottom.category.index >= Hand5Category.fourOfAKind.index;

  @override
  bool operator ==(Object other) =>
      other is FantasyState && other.initialCount == initialCount;

  @override
  int get hashCode => initialCount.hashCode;

  @override
  String toString() => isActive
      ? 'FantasyState.active($initialCount)'
      : 'FantasyState.inactive()';
}
