import 'package:test/test.dart';
import 'package:ofc_app_core/core/models/deck.dart';
import 'package:ofc_app_core/features/game/domain/game_state.dart';
import 'package:ofc_app_core/features/game/domain/fantasy_engine.dart';
import 'package:ofc_app_core/features/game/domain/board.dart';
import 'helpers.dart';

void main() {
  test('startHand respects FantasyState initial counts', () {
    // A: Fantasy14、B: 通常5
    final deck = Deck.fromCodes([
      // A 初手14
      'As', 'Ks', 'Qs', 'Js', 'Ts', '9s', '8s', '7s', '6s', '5s', '4s', '3s',
      '2s', 'Ah',
      // B 初手5
      'Kh', 'Qh', 'Jh', 'Th', '9h',
    ]);
    final gs = GameState(
        deck: deck,
        fantasyA: const FantasyState.active(14),
        fantasyB: const FantasyState.inactive());
    gs.startHand();
    expect(gs.aEngine.tray.length, 14);
    expect(gs.bEngine.tray.length, 5);
  });

  test(
      'commitWithBoards updates FantasyState and preserves initialCount on continue',
      () {
    final gs = GameState(fantasyA: const FantasyState.active(15));
    // A は継続条件（下段Four）を満たす → initialCount=15を維持
    final a = Board(
      top: [c('2h'), c('3h'), c('4h')],
      middle: [c('5h'), c('6h'), c('7h'), c('8h'), c('9h')],
      bottom: [c('9s'), c('9d'), c('9c'), c('9h'), c('2s')],
    );
    // B は継続/突入なし
    final b = Board(
      top: [c('Ah'), c('Kd'), c('2c')],
      middle: [c('3d'), c('4s'), c('5c'), c('7d'), c('9h')],
      bottom: [c('2d'), c('3c'), c('4d'), c('6s'), c('9c')],
    );
    gs.commitWithBoards(a, b);
    expect(gs.fantasyA.active, isTrue);
    expect(gs.fantasyA.initialCount, 15);
    expect(gs.fantasyB.active, isFalse);
  });
}
