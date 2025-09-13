import '../../../core/models/playing_card.dart';

class BoardBuilder {
  final List<PlayingCard> top = [];
  final List<PlayingCard> middle = [];
  final List<PlayingCard> bottom = [];

  bool get isComplete =>
      top.length == 3 && middle.length == 5 && bottom.length == 5;

  void placeTop(PlayingCard c) {
    if (top.length >= 3) throw StateError('Top is full');
    top.add(c);
  }

  void placeMiddle(PlayingCard c) {
    if (middle.length >= 5) throw StateError('Middle is full');
    middle.add(c);
  }

  void placeBottom(PlayingCard c) {
    if (bottom.length >= 5) throw StateError('Bottom is full');
    bottom.add(c);
  }
}
