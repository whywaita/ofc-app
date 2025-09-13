import 'package:test/test.dart';
import 'package:ofc_app_core/core/models/deck.dart';
import 'package:ofc_app_core/features/game/domain/pineapple_engine.dart';
import 'package:ofc_app_core/features/game/domain/board.dart';
import 'package:ofc_app_core/features/game/domain/fantasy_engine.dart';
import 'helpers.dart';

void main() {
  test('initial draw 5 then cycles of 3 with 2 place + 1 discard', () {
    final deck = Deck.fromCodes([
      // 初手5
      'As', 'Ks', 'Qs', 'Js', 'Ts',
      // 次の3
      '2h', '3h', '4h',
    ]);
    final eng = PineappleEngine(deck);
    eng.startHand();
    expect(eng.tray.length, 5);
    // 初手は5枚配置可能（ここではトップ3, ミドル2に置く）
    eng.place(Slot.top, c('As'));
    eng.place(Slot.top, c('Ks'));
    eng.place(Slot.top, c('Qs'));
    eng.place(Slot.middle, c('Js'));
    eng.place(Slot.middle, c('Ts'));
    expect(eng.tray, isEmpty);
    // 次サイクルへ
    expect(eng.needsCycle, isTrue);
    eng.nextCycle();
    expect(eng.tray.length, 3);
    // 2枚配置 + 1枚捨て
    eng.place(Slot.bottom, c('2h'));
    eng.place(Slot.bottom, c('3h'));
    eng.discard(c('4h'));
    expect(eng.tray, isEmpty);
  });

  test('Fantasy entry count mapping (board eval only)', () {
    // トップQQ → 14
    final board = Board(
      top: [c('Qh'), c('Qs'), c('2c')],
      middle: [c('3d'), c('4s'), c('5c'), c('7d'), c('9h')],
      bottom: [c('Ah'), c('Kd'), c('7s'), c('6c'), c('2d')],
    );
    expect(FantasyEngine.entryCount(BoardEval.from(board)), 14);
  });
}
