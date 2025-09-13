import 'package:test/test.dart';
import 'package:ofc_app_core/features/game/domain/board.dart';
import 'package:ofc_app_core/features/game/domain/fantasy_engine.dart';
import 'package:ofc_app_core/features/game/domain/foul_checker.dart';
import 'helpers.dart';

void main() {
  test('debug A board not foul and continues', () {
    final a = Board(
      top: [c('2h'), c('3h'), c('4h')], // High
      middle: [c('2d'), c('6d'), c('8d'), c('9d'), c('Td')], // Flush (not straight flush)
      bottom: [c('9s'), c('9d'), c('9c'), c('9h'), c('2s')], // Four of a kind
    );
    final e = BoardEval.from(a);
    expect(FoulChecker.isFoul(e), isFalse);
    final st = FantasyEngine.nextState(const FantasyState.active(15), e);
    expect(st.active, isTrue);
    expect(st.initialCount, 15);
  });
}
