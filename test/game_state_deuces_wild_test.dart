import 'package:test/test.dart';
import 'package:ofc_app_core/features/game/domain/game_state.dart';
import 'package:ofc_app_core/features/game/domain/game_options.dart';
import 'package:ofc_app_core/features/game/domain/board.dart';
import 'package:ofc_app_core/features/game/domain/score_engine.dart';
import 'package:ofc_app_core/features/game/domain/fantasy_engine.dart';
import 'package:ofc_app_core/features/game/domain/hand_category5.dart';
import 'package:ofc_app_core/features/game/domain/hand_category3.dart';
import 'helpers.dart';

void main() {
  group('GameState with DeucesWild', () {
    test('GameState can be created with DeucesWild option', () {
      final state = GameState(options: GameOptions.deucesWild);
      expect(state.options.wildMode, WildMode.deuces);
      expect(state.options.isDeucesWild, true);
    });

    test('GameState default is standard (no wild)', () {
      final state = GameState();
      expect(state.options.wildMode, WildMode.none);
      expect(state.options.isDeucesWild, false);
    });
  });

  group('BoardEval with DeucesWild', () {
    test('BoardEval.from with DeucesWild evaluates hands correctly', () {
      // Board with deuces in top row
      final board = Board(
        top: [c('2s'), c('As'), c('Ks')], // Deuce + A + K = Pair of Aces
        middle: [c('Ah'), c('Ad'), c('Ac'), c('Kh'), c('Qh')], // Trips Aces
        bottom: [
          c('2h'),
          c('2d'),
          c('Jh'),
          c('Th'),
          c('9h')
        ], // 2 deuces + heart cards
      );

      final evalStandard = BoardEval.from(board, wildMode: WildMode.none);
      final evalWild = BoardEval.from(board, wildMode: WildMode.deuces);

      // Standard: top row has no pair (2-A-K all different)
      expect(evalStandard.top.category, Hand3Category.highCard);

      // DeucesWild: top row has pair of Aces (2 becomes A)
      expect(evalWild.top.category, Hand3Category.pair);
      expect(evalWild.top.isWild, true);

      // Bottom: 2 deuces + J-T-9 hearts = Straight Flush (K-high or Q-high)
      expect(evalWild.bottom.category, Hand5Category.straightFlush);
      expect(evalWild.bottom.isWild, true);
    });
  });

  group('ScoreEngine with DeucesWild', () {
    test('ScoreEngine.compare uses wildMode correctly', () {
      final boardA = Board(
        top: [c('2s'), c('As'), c('Ks')], // Wild: Pair of Aces
        middle: [c('Ah'), c('Kh'), c('Qh'), c('Jh'), c('9h')], // Flush
        bottom: [c('5s'), c('5h'), c('5d'), c('5c'), c('3s')], // Four 5s
      );

      final boardB = Board(
        top: [c('Qs'), c('Qh'), c('7d')], // Pair of Queens
        middle: [c('As'), c('Ad'), c('Ac'), c('Ks'), c('Kd')], // Full House
        bottom: [c('Ts'), c('Js'), c('Qs'), c('Ks'), c('As')], // Royal Flush
      );

      final scoreWild =
          ScoreEngine.compare(boardA, boardB, wildMode: WildMode.deuces);

      // Board B has Royal Flush on bottom, should win that row
      expect(scoreWild.b.rows.bottom, 1);
    });
  });

  group('Fantasy with DeucesWild', () {
    test('Fantasy entry with wild trips on top', () {
      // Board with 2 deuces + Ace on top = Trips Aces (Wild)
      final board = Board(
        top: [c('2s'), c('2h'), c('As')], // 2 deuces + A = Trips Aces
        middle: [c('Ah'), c('Kh'), c('Qh'), c('Jh'), c('9h')], // Flush
        bottom: [c('5s'), c('5h'), c('5d'), c('5c'), c('3s')], // Four 5s
      );

      final evalWild = BoardEval.from(board, wildMode: WildMode.deuces);

      // Top should be Three of a Kind
      expect(evalWild.top.category, Hand3Category.threeOfAKind);
      expect(evalWild.top.isWild, true);

      // Fantasy entry should work with wild trips
      final entryCount = FantasyEngine.entryCount(evalWild);
      expect(entryCount, 17); // Trips on top = 17 cards
    });

    test('Fantasy continue with wild Four of a Kind on bottom', () {
      final board = Board(
        top: [c('As'), c('Ah'), c('Kd')], // Pair of Aces
        middle: [c('Ks'), c('Kh'), c('Kd'), c('Qh'), c('Jh')], // Trips Kings
        bottom: [
          c('2s'),
          c('2h'),
          c('2d'),
          c('Ts'),
          c('Th')
        ], // 3 deuces + pair = Four Tens
      );

      final evalWild = BoardEval.from(board, wildMode: WildMode.deuces);

      // Bottom should be Four of a Kind
      expect(evalWild.bottom.category, Hand5Category.fourOfAKind);
      expect(evalWild.bottom.isWild, true);

      // Fantasy continue should work with wild Four+
      expect(FantasyEngine.shouldContinue(evalWild), true);
    });
  });

}
