import 'package:ofc_app_core/core/models/playing_card.dart';
import 'package:test/test.dart';
import 'package:ofc_app_core/features/game/domain/board.dart';
import 'package:ofc_app_core/features/game/domain/foul_checker.dart';
import 'package:ofc_app_core/features/game/domain/game_options.dart';
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

  group('Joker Wild foul prevention', () {
    test(
        'Joker in top should not cause foul when middle is high card - context-aware evaluation',
        () {
      // Top: Joker, K♠, 6♦ -> should be evaluated as K-Q-6 or less (not A-K-6)
      // Middle: K♠, Q♦, T♣, J♥, 8♦ -> high card K-Q-J-T-8
      // Bottom: 9♣, 9♠, 9♦, 2♣, Joker -> three of a kind 9s
      final b = Board(
        top: [const PlayingCard.joker(), c('Ks'), c('6d')],
        middle: [c('Ks'), c('Qd'), c('Tc'), c('Jh'), c('8d')],
        bottom: [c('9c'), c('9s'), c('9d'), c('2c'), const PlayingCard.joker()],
      );
      final e = BoardEval.from(b, wildMode: WildMode.joker);
      // This should NOT be foul because Joker in top should be optimized
      // to not exceed middle's strength
      expect(FoulChecker.isFoul(e), isFalse);
    });

    test(
        'Joker in top with pair in middle should optimize to not exceed middle',
        () {
      // Top: Joker, 5, 3 -> without optimization: pair of 5s (or Aces)
      // Middle: 7, 7, K, Q, 8 -> pair of 7s
      // Bottom: A, A, A, 2, 3 -> three of a kind Aces
      final b = Board(
        top: [const PlayingCard.joker(), c('5s'), c('3d')],
        middle: [c('7h'), c('7d'), c('Kc'), c('Qs'), c('8h')],
        bottom: [c('As'), c('Ad'), c('Ah'), c('2c'), c('3c')],
      );
      final e = BoardEval.from(b, wildMode: WildMode.joker);
      // Joker + 5 + 3: Without context, this could be A-5-3 high card
      // But with pair 7s in middle, A-5-3 < pair 7s, so no foul
      expect(FoulChecker.isFoul(e), isFalse);
    });
  });
}
