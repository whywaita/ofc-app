import 'package:flutter/foundation.dart';
import 'package:ofc_app_core/ofc_core.dart';

import '../presentation/labels.dart';

/// The interactive state around one [PlayerHand]: the picked-up card, the last refusal and the
/// status line. Dragging and tapping go through the same rules, which live in [PlayerHand].
abstract class HandTableController extends ChangeNotifier {
  /// The hand the table shows and edits.
  PlayerHand get hand;

  String _status = 'Ready';
  PlayingCard? _selected;
  String? _hint;

  /// What the last action did, shown as `Status: …`.
  String get status => _status;

  /// A card picked up by tapping, waiting for a row (or the tray) to be tapped.
  PlayingCard? get selected => _selected;

  /// Why the last attempt was refused. Cleared by any successful action.
  String? get hint => _hint;

  /// The label of the primary button.
  String get advanceLabel => hand.isComplete ? 'Commit' : 'Next 3';

  bool get canAdvance => hand.isComplete || hand.canDrawNext;

  /// Why [card] cannot go into [row], worded for the player, or null.
  String? placementBlock(PlayingCard card, BoardRow row) {
    final e = hand.placementError(card, row);
    return e == null ? null : Labels.placementError(e, row);
  }

  bool canReturnToTray(PlayingCard card) => hand.canReturnToTray(card);

  void select(PlayingCard card) {
    _selected = _selected == card ? null : card;
    _hint = null;
    notifyListeners();
  }

  /// Places [card] in [row] (a drop, or a tap on a row with a card picked up).
  void place(PlayingCard card, BoardRow row) {
    final block = placementBlock(card, row);
    if (block != null) {
      _hint = block;
    } else {
      hand.place(card, row);
      _done('Placed');
    }
    notifyListeners();
  }

  void tapRow(BoardRow row) {
    final card = _selected;
    if (card != null) place(card, row);
  }

  void returnToTray(PlayingCard card) {
    if (!canReturnToTray(card)) {
      _hint = 'That card cannot come back';
    } else {
      hand.returnToTray(card);
      _done('Back to Tray');
    }
    notifyListeners();
  }

  void tapTray() {
    final card = _selected;
    if (card != null) returnToTray(card);
  }

  void sortTray() {
    hand.sortTray();
    _done('Sorted');
    notifyListeners();
  }

  /// Records a successful action: new status, nothing picked up, no refusal shown.
  @protected
  void setStatus(String status) {
    _done(status);
    notifyListeners();
  }

  void _done(String status) {
    _status = status;
    _selected = null;
    _hint = null;
  }
}
