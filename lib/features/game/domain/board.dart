import '../../../core/models/playing_card.dart';
import 'hand_category3.dart';
import 'hand_category5.dart';
import 'hand_evaluator.dart';

class Board {
  final List<PlayingCard> top; // 3 cards
  final List<PlayingCard> middle; // 5 cards
  final List<PlayingCard> bottom; // 5 cards
  const Board({required this.top, required this.middle, required this.bottom});
}

class BoardEval {
  final Hand3Rank top;
  final Hand5Rank middle;
  final Hand5Rank bottom;
  const BoardEval(
      {required this.top, required this.middle, required this.bottom});

  factory BoardEval.from(Board b) {
    return BoardEval(
      top: HandEvaluator.evaluate3(b.top),
      middle: HandEvaluator.evaluate5(b.middle),
      bottom: HandEvaluator.evaluate5(b.bottom),
    );
  }
}
