import 'board.dart';
import 'hand_category3.dart';
import 'hand_category5.dart';

class FantasyState {
  final bool active;
  final int initialCount; // 14/15/16/17 when active
  const FantasyState._(this.active, this.initialCount);
  const FantasyState.inactive() : this._(false, 0);
  const FantasyState.active(int initialCount) : this._(true, initialCount);
}

class FantasyEngine {
  // 0: 通常、14/15/16/17: Fantasy 初期配布枚数
  static int entryCount(BoardEval e) {
    if (e.top.category == Hand3Category.threeOfAKind) return 17;
    if (e.top.category == Hand3Category.pair) {
      final pairRank = e.top.tiebreakers.first;
      if (pairRank == 12) return 14; // QQ
      if (pairRank == 13) return 15; // KK
      if (pairRank == 14) return 16; // AA
    }
    // rddでは Bottom Four+ も突入条件に記載があるが、配布枚数が未定のため
    // todo.mdの定義（Top QQ/KK/AA/Trips のみ突入）を優先。
    return 0;
  }

  static bool shouldContinue(BoardEval e) {
    if (e.top.category == Hand3Category.threeOfAKind) {
      return true; // 上段 Trips
    }
    if (e.bottom.category.index >= Hand5Category.fourOfAKind.index) {
      return true; // 下段 Four+
    }
    return false;
  }

  // 現在の Fantasy 状態とこのハンドの結果から、次ハンドの状態を返す
  static FantasyState nextState(FantasyState current, BoardEval e) {
    if (!current.active) {
      final count = entryCount(e);
      return count > 0
          ? FantasyState.active(count)
          : const FantasyState.inactive();
    }
    // 継続条件を満たせば「突入時の配布枚数」を維持
    if (shouldContinue(e)) {
      return FantasyState.active(current.initialCount);
    }
    return const FantasyState.inactive();
  }
}
