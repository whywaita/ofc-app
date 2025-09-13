import '../../../core/models/playing_card.dart';
import 'pineapple_engine.dart';
import 'board_builder.dart';

class CycleLogic {
  static Set<String> currentCycleIds(List<ActionLogEntry> history) {
    for (var i = history.length - 1; i >= 0; i--) {
      final e = history[i];
      if (e.type == 'draw') {
        final list = (e.data['cards'] as List).cast<String>();
        return list.toSet();
      }
    }
    return {};
  }

  static int lastDrawCount(List<ActionLogEntry> history) {
    for (var i = history.length - 1; i >= 0; i--) {
      final e = history[i];
      if (e.type == 'draw') {
        return (e.data['count'] as int);
      }
    }
    return 0;
  }

  static int placedCountForCycle(BoardBuilder builder, Set<String> ids) {
    bool inCycle(PlayingCard c) => ids.contains(c.toString());
    return builder.top.where(inCycle).length +
        builder.middle.where(inCycle).length +
        builder.bottom.where(inCycle).length;
  }

  static List<PlayingCard> trayCardsForCycle(
      List<PlayingCard> tray, Set<String> ids) {
    return tray.where((c) => ids.contains(c.toString())).toList();
  }

  static bool canNext(PineappleEngine eng) {
    final last = lastDrawCount(eng.history);
    final ids = currentCycleIds(eng.history);
    final placed = placedCountForCycle(eng.builder, ids);
    if (last == 5) return placed >= 5;
    if (last == 3) return placed >= 2;
    return false;
  }

  // Remove leftover tray cards for this cycle and record discards
  static List<PlayingCard> autoDiscardForNext(PineappleEngine eng) {
    final last = lastDrawCount(eng.history);
    if (last != 3) return const [];
    final ids = currentCycleIds(eng.history);
    final leftovers = trayCardsForCycle(eng.tray, ids);
    for (final c in leftovers) {
      eng.tray.remove(c);
      eng.history.add(ActionLogEntry('discard', {'card': c.toString()}));
    }
    return leftovers;
  }
}

