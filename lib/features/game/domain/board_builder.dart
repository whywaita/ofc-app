import 'dart:collection';
import '../../../core/models/playing_card.dart';

class BoardBuilder {
  final List<PlayingCard> _top = [];
  final List<PlayingCard> _middle = [];
  final List<PlayingCard> _bottom = [];

  /// Returns an unmodifiable view of the top cards
  UnmodifiableListView<PlayingCard> get top => UnmodifiableListView(_top);

  /// Returns an unmodifiable view of the middle cards
  UnmodifiableListView<PlayingCard> get middle => UnmodifiableListView(_middle);

  /// Returns an unmodifiable view of the bottom cards
  UnmodifiableListView<PlayingCard> get bottom => UnmodifiableListView(_bottom);

  bool get isComplete =>
      _top.length == 3 && _middle.length == 5 && _bottom.length == 5;

  void placeTop(PlayingCard c) {
    if (_top.length >= 3) throw StateError('Top is full');
    _top.add(c);
  }

  void placeMiddle(PlayingCard c) {
    if (_middle.length >= 5) throw StateError('Middle is full');
    _middle.add(c);
  }

  void placeBottom(PlayingCard c) {
    if (_bottom.length >= 5) throw StateError('Bottom is full');
    _bottom.add(c);
  }

  /// Removes a card from all rows (top, middle, bottom)
  /// Returns true if the card was found and removed, false otherwise
  bool remove(PlayingCard card) {
    return _top.remove(card) || _middle.remove(card) || _bottom.remove(card);
  }
}
