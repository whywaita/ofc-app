import 'dart:collection';

import '../board/board.dart';
import '../cards/deck.dart';
import '../cards/playing_card.dart';

/// One step of a hand, as recorded in [PlayerHand.history].
sealed class HandAction {
  const HandAction();
}

final class DrawAction extends HandAction {
  const DrawAction(this.cards);
  final List<PlayingCard> cards;
}

final class PlaceAction extends HandAction {
  const PlaceAction(this.card, this.row);
  final PlayingCard card;
  final BoardRow row;
}

final class MoveAction extends HandAction {
  const MoveAction(this.card, this.from, this.to);
  final PlayingCard card;
  final BoardRow from;
  final BoardRow to;
}

final class ReturnAction extends HandAction {
  const ReturnAction(this.card, this.from);
  final PlayingCard card;
  final BoardRow from;
}

final class DiscardAction extends HandAction {
  const DiscardAction(this.card);
  final PlayingCard card;
}

final class CommitAction extends HandAction {
  const CommitAction();
}

/// Why a card cannot go into a row.
enum PlacementError {
  /// The hand is committed.
  handClosed,

  /// The card is neither in the tray nor on the board.
  notInHand,

  /// The row holds as many cards as it can.
  rowFull,

  /// Two cards of this three-card draw are already on the board.
  drawLimitReached,

  /// The card was placed in an earlier draw and cannot move any more.
  lockedIn,
}

/// One player's hand of Pineapple OFC, from the deal to the commit.
///
/// Normal hands are dealt 5 cards, all of which go on the board; then come draws of 3, two placed
/// and the third discarded when the next draw is taken (or at the commit). A Fantasy hand is dealt
/// 14..17 cards at once, sets 13 and discards the rest at the commit. Cards of the current draw
/// can be moved between rows and back to the tray until the next draw; earlier cards are fixed.
class PlayerHand {
  PlayerHand.deal(this._deck, {int count = 5}) : initialDrawCount = count {
    _draw(count);
  }

  final Deck _deck;

  /// Cards dealt at the start: 5, or 14..17 in Fantasyland.
  final int initialDrawCount;

  final Map<BoardRow, List<PlayingCard>> _rows = {
    for (final r in BoardRow.values) r: <PlayingCard>[],
  };
  final List<PlayingCard> _tray = [];
  final List<PlayingCard> _discards = [];
  final List<HandAction> _history = [];
  List<PlayingCard> _currentDraw = const [];
  bool _committed = false;

  bool get isFantasy => initialDrawCount > 5;
  bool get isCommitted => _committed;

  List<PlayingCard> get tray => UnmodifiableListView(_tray);
  List<PlayingCard> get discards => UnmodifiableListView(_discards);
  List<HandAction> get history => UnmodifiableListView(_history);

  /// The cards of the latest draw.
  List<PlayingCard> get currentDraw => _currentDraw;

  List<PlayingCard> row(BoardRow r) => UnmodifiableListView(_rows[r]!);

  Board get board => Board(
        top: _rows[BoardRow.top]!,
        middle: _rows[BoardRow.middle]!,
        bottom: _rows[BoardRow.bottom]!,
      );

  bool get isComplete =>
      BoardRow.values.every((r) => _rows[r]!.length == r.capacity);

  BoardRow? rowOf(PlayingCard card) {
    for (final r in BoardRow.values) {
      if (_rows[r]!.contains(card)) return r;
    }
    return null;
  }

  /// A card on the board that may still be moved: it belongs to the current draw.
  bool isMovable(PlayingCard card) =>
      !_committed && rowOf(card) != null && _currentDraw.contains(card);

  int get _placedFromCurrentDraw =>
      _currentDraw.where((c) => rowOf(c) != null).length;

  bool get _isPineappleDraw => _history.whereType<DrawAction>().length > 1;

  /// Why [card] cannot go into [row] now, or `null` when it can.
  PlacementError? placementError(PlayingCard card, BoardRow row) {
    if (_committed) return PlacementError.handClosed;
    final from = rowOf(card);
    final inTray = _tray.contains(card);
    if (from == null && !inTray) return PlacementError.notInHand;
    if (from == row) return null;
    if (_rows[row]!.length >= row.capacity) return PlacementError.rowFull;
    if (inTray && _isPineappleDraw && _placedFromCurrentDraw >= 2) {
      return PlacementError.drawLimitReached;
    }
    if (from != null && !_currentDraw.contains(card)) {
      return PlacementError.lockedIn;
    }
    return null;
  }

  /// Puts [card] from the tray into [row], or moves it there from another row.
  void place(PlayingCard card, BoardRow row) {
    final error = placementError(card, row);
    if (error != null) {
      throw StateError('Cannot place $card in ${row.name}: ${error.name}');
    }
    final from = rowOf(card);
    if (from == row) return;
    if (from == null) {
      _tray.remove(card);
      _history.add(PlaceAction(card, row));
    } else {
      _rows[from]!.remove(card);
      _history.add(MoveAction(card, from, row));
    }
    _rows[row]!.add(card);
  }

  bool canReturnToTray(PlayingCard card) => isMovable(card);

  void returnToTray(PlayingCard card) {
    if (!canReturnToTray(card)) {
      throw StateError('$card cannot return to the tray');
    }
    final from = rowOf(card)!;
    _rows[from]!.remove(card);
    _tray.add(card);
    _history.add(ReturnAction(card, from));
  }

  /// Whether the next three cards can be drawn: the deal is placed whole (a normal hand), or two
  /// cards of the current three are placed.
  bool get canDrawNext {
    if (_committed || isFantasy || isComplete || _deck.remaining < 3) {
      return false;
    }
    final needed = _isPineappleDraw ? 2 : initialDrawCount;
    return _placedFromCurrentDraw == needed;
  }

  /// Discards what is left of the current draw and draws three. Returns the discarded cards.
  List<PlayingCard> drawNext() {
    if (!canDrawNext) throw StateError('Cannot draw yet');
    final leftovers = _discardTray();
    _draw(3);
    return leftovers;
  }

  /// Ends the hand: the leftover tray cards are discarded and the board is final.
  Board commit() {
    if (_committed) throw StateError('Hand already committed');
    if (!isComplete) throw StateError('Board not complete');
    _discardTray();
    _committed = true;
    _history.add(const CommitAction());
    return board;
  }

  /// Orders the tray by rank (high first), then suit (spades, hearts, diamonds, clubs); jokers last.
  void sortTray() {
    int key(PlayingCard c) => switch (c) {
          StandardCard(:final rank, :final suit) =>
            -rank.value * 4 + suit.index,
          Joker() => 1,
        };
    _tray.sort((a, b) => key(a).compareTo(key(b)));
  }

  void _draw(int n) {
    final cards = _deck.draw(n);
    _tray.addAll(cards);
    _currentDraw = List.unmodifiable(cards);
    _history.add(DrawAction(_currentDraw));
  }

  List<PlayingCard> _discardTray() {
    final leftovers = List.of(_tray);
    _tray.clear();
    for (final c in leftovers) {
      _discards.add(c);
      _history.add(DiscardAction(c));
    }
    return leftovers;
  }
}
