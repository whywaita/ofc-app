import 'board.dart';
import 'hand_category3.dart';
import 'hand_category5.dart';

class FoulChecker {
  static bool isFoul(BoardEval e) {
    // カテゴリ強度のみで判定（同カテゴリは許容）。
    final bottomStrength = e.bottom.category.index;
    final middleStrength = e.middle.category.index;
    final topStrength = switch (e.top.category) {
      Hand3Category.highCard => Hand5Category.highCard.index,
      Hand3Category.pair => Hand5Category.onePair.index,
      Hand3Category.threeOfAKind => Hand5Category.threeOfAKind.index,
    };
    final okBottom = bottomStrength >= middleStrength;
    final okMiddle = middleStrength >= topStrength;
    return !(okBottom && okMiddle);
  }
}
