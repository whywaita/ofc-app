import '../../../core/models/deck.dart';
import '../../../core/models/playing_card.dart';
import 'board.dart';
import 'board_builder.dart';

enum Phase { drawing, placing, complete }

enum Slot { top, middle, bottom }

class ActionLogEntry {
  final String type; // draw|place|discard|commit
  final Map<String, Object?> data;
  ActionLogEntry(this.type, this.data);
}

class PineappleEngine {
  final Deck deck;
  final List<ActionLogEntry> history = [];
  final BoardBuilder builder = BoardBuilder();
  final List<PlayingCard> tray = [];
  final List<PlayingCard> discards = [];
  Phase phase = Phase.drawing;

  int initialDrawCount = 5; // 通常 5、Fantasy では14/15/16/17

  PineappleEngine(this.deck);

  void startWithFantasy({required int initialFantasyCount}) {
    startHand(fantasyInitialCount: initialFantasyCount);
  }

  void startHand({int fantasyInitialCount = 0}) {
    if (phase != Phase.drawing ||
        tray.isNotEmpty ||
        builder.top.isNotEmpty ||
        builder.middle.isNotEmpty ||
        builder.bottom.isNotEmpty) {
      throw StateError('Hand already in progress');
    }
    initialDrawCount = fantasyInitialCount > 0 ? fantasyInitialCount : 5;
    discards.clear();
    _draw(initialDrawCount);
  }

  void _draw(int n) {
    final drawn = deck.draw(n);
    tray.addAll(drawn);
    history.add(ActionLogEntry('draw', {
      'count': n,
      'cards': drawn.map((c) => c.toString()).toList(),
    }));
    phase = Phase.placing;
  }

  void place(Slot slot, PlayingCard card) {
    if (phase != Phase.placing) throw StateError('Not in placing phase');
    if (!tray.remove(card)) throw StateError('Card not in tray');
    switch (slot) {
      case Slot.top:
        builder.placeTop(card);
        break;
      case Slot.middle:
        builder.placeMiddle(card);
        break;
      case Slot.bottom:
        builder.placeBottom(card);
        break;
    }
    history.add(
        ActionLogEntry('place', {'slot': slot.name, 'card': card.toString()}));
  }

  void discard(PlayingCard card) {
    if (phase != Phase.placing) throw StateError('Not in placing phase');
    if (!tray.remove(card)) throw StateError('Card not in tray');
    discards.add(card);
    history.add(ActionLogEntry('discard', {'card': card.toString()}));
  }

  bool get needsCycle {
    if (builder.isComplete) return false;
    // 初手は5枚すべて配置する前提。以降は 3 枚サイクルで 2 配置 + 1 捨て。
    if (history.where((e) => e.type == 'draw').isEmpty) return true;
    final firstDrawCount =
        (history.firstWhere((e) => e.type == 'draw').data['count']) as int;
    final placedCount = history.where((e) => e.type == 'place').length;
    final discardedCount = history.where((e) => e.type == 'discard').length;
    final consumed = placedCount + discardedCount;
    if (consumed < firstDrawCount) {
      // まだ初手の5枚を処理中
      return false;
    }
    // 以降は消費が3の倍数になるたび次のサイクルへ
    final afterInitial = consumed - firstDrawCount;
    return tray.isEmpty && (afterInitial % 3 == 0);
  }

  void nextCycle() {
    if (!needsCycle) throw StateError('Cycle not ready');
    _draw(3);
  }

  Board finalize() {
    if (!builder.isComplete) throw StateError('Board not complete');
    phase = Phase.complete;
    final board = Board(
        top: List.of(builder.top),
        middle: List.of(builder.middle),
        bottom: List.of(builder.bottom));
    history.add(ActionLogEntry('commit', {}));
    return board;
  }

}
