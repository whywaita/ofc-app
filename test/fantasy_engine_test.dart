import 'package:test/test.dart';
import 'package:ofc_app_core/features/game/domain/board.dart';
import 'package:ofc_app_core/features/game/domain/fantasy_engine.dart';
import 'helpers.dart';

void main() {
  test('enter then continue with same initialCount on bottom Four+', () {
    // 突入（Top QQ → 14）
    final b1 = Board(
      top: [c('Qh'), c('Qs'), c('2c')], // Pair Q (entry)
      middle: [c('2d'), c('6d'), c('8d'), c('9d'), c('Td')], // Flush
      bottom: [c('9s'), c('9d'), c('9h'), c('9c'), c('2s')], // Four of a kind (>= Flush)
    );
    final e1 = BoardEval.from(b1);
    final enter = FantasyState.inactive();
    final st1 = FantasyEngine.nextState(enter, e1);
    expect(st1.active, isTrue);
    expect(st1.initialCount, 14);

    // 継続（下段 Four of a Kind）→ 配布枚数は 14 を維持
    final b2 = Board(
      top: [c('2h'), c('3h'), c('4h')], // High
      middle: [c('2h'), c('6h'), c('8h'), c('9h'), c('Th')], // Flush (not straight flush)
      bottom: [c('9s'), c('9d'), c('9c'), c('9h'), c('2s')], // Four
    );
    final e2 = BoardEval.from(b2);
    final st2 = FantasyEngine.nextState(st1, e2);
    expect(st2.active, isTrue);
    expect(st2.initialCount, 14);
  });

  test('active then drop when no continue condition', () {
    final current = FantasyState.active(16);
    // どの継続条件も満たさない
    final b = Board(
      top: [c('Ah'), c('Kd'), c('2c')],
      middle: [c('3d'), c('4s'), c('5c'), c('7d'), c('9h')],
      bottom: [c('2d'), c('3c'), c('4d'), c('6s'), c('9c')],
    );
    final e = BoardEval.from(b);
    final next = FantasyEngine.nextState(current, e);
    expect(next.active, isFalse);
    expect(next.initialCount, 0);
  });

  test('no fantasy entry on foul even with top pair', () {
    // Top AA but Middle stronger than Bottom/Top order invalid → FOUL → no entry
    final b = Board(
      top: [c('As'), c('Ad'), c('2c')],
      middle: [c('3c'), c('8d'), c('8s'), c('Jc'), c('Ah')],
      bottom: [c('Td'), c('9s'), c('9h'), c('6c'), c('Tc')],
    );
    final e = BoardEval.from(b);
    final st = FantasyEngine.nextState(const FantasyState.inactive(), e);
    expect(st.active, isFalse);
  });

  test('active then continue on top trips keeps original initialCount', () {
    final current = FantasyState.active(15);
    final b = Board(
      top: [c('5h'), c('5d'), c('5s')], // Trips Top
      middle: [c('2h'), c('6h'), c('8h'), c('9h'), c('Th')], // Flush (>= Top)
      bottom: [c('9s'), c('9d'), c('9c'), c('4d'), c('4s')], // Full House or Trips? (here Trips 9 + 4 4 makes Full House? Actually 9 9 9 4 4)
    );
    final e = BoardEval.from(b);
    final next = FantasyEngine.nextState(current, e);
    expect(next.active, isTrue);
    expect(next.initialCount, 15);
  });
}
