import 'package:test/test.dart';
import 'package:ofc_app_core/core/models/deck.dart';
import 'package:ofc_app_core/features/game/domain/pineapple_engine.dart';
import 'package:ofc_app_core/features/game/domain/cycle_logic.dart';
import 'helpers.dart';

void main() {
  test('initial 5 requires 5 placed to canNext', () {
    final deck = Deck.fromCodes(['As','Ks','Qs','Js','Ts', '2h','3h','4h']);
    final eng = PineappleEngine(deck)..startHand();
    // place 5
    eng.place(Slot.top, c('As'));
    eng.place(Slot.top, c('Ks'));
    eng.place(Slot.top, c('Qs'));
    eng.place(Slot.middle, c('Js'));
    eng.place(Slot.middle, c('Ts'));
    expect(CycleLogic.canNext(eng), isTrue);
  });

  test('3-card cycle requires 2 placed, leftover auto-discard', () {
    final deck = Deck.fromCodes([
      // first 5
      'As','Ks','Qs','Js','Ts',
      // next 3
      '2h','3h','4h',
      // another 3 (for nextCycle after autoDiscard)
      '5h','6h','7h',
    ]);
    final eng = PineappleEngine(deck)..startHand();
    // place 5
    eng.place(Slot.top, c('As'));
    eng.place(Slot.top, c('Ks'));
    eng.place(Slot.top, c('Qs'));
    eng.place(Slot.middle, c('Js'));
    eng.place(Slot.middle, c('Ts'));
    // next cycle draw
    eng.nextCycle();
    // place 2, leave 1 in tray
    eng.place(Slot.bottom, c('2h'));
    eng.place(Slot.bottom, c('3h'));
    expect(CycleLogic.canNext(eng), isTrue);
    final discarded = CycleLogic.autoDiscardForNext(eng);
    expect(discarded.length, 1);
    // proceed
    eng.nextCycle();
  });
}
