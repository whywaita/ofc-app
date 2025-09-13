import 'package:test/test.dart';
import 'package:ofc_app_core/features/game/domain/board.dart';
import 'package:ofc_app_core/features/game/domain/foul_checker.dart';
import 'helpers.dart';

void main() {
  test('foul when middle weaker than top (pair on top, high on middle)', () {
    final b = Board(
      top: [c('Kh'), c('Kd'), c('2s')],
      middle: [c('As'), c('Qd'), c('9c'), c('7h'), c('3d')],
      bottom: [c('2h'), c('2d'), c('5s'), c('6c'), c('9h')],
    );
    final e = BoardEval.from(b);
    expect(FoulChecker.isFoul(e), isTrue);
  });

  test('foul when middle pair lower than top pair', () {
    // Top: Q K K  (Pair K)
    // Middle: 3 8 8 J A (Pair 8)
    // Bottom: T 9 9 6 T (Two pair T&9)
    final b = Board(
      top: [c('Qh'), c('Ks'), c('Kd')],
      middle: [c('3c'), c('8d'), c('8s'), c('Jc'), c('Ah')],
      bottom: [c('Td'), c('9s'), c('9h'), c('6c'), c('Tc')],
    );
    final e = BoardEval.from(b);
    expect(FoulChecker.isFoul(e), isTrue);
  });
}
