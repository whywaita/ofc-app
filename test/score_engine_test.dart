import 'package:test/test.dart';
import 'package:ofc_app_core/features/game/domain/board.dart';
import 'package:ofc_app_core/features/game/domain/score_engine.dart';
import 'package:ofc_app_core/features/game/domain/ruleset.dart';
import 'helpers.dart';

void main() {
  test('row wins + sweep + royalties', () {
    final a = Board(
      top: [c('9s'), c('9d'), c('2c')], // pair 9
      middle: [c('Qs'), c('Qd'), c('3h'), c('5c'), c('8d')], // pair Q
      bottom: [c('Ks'), c('Kd'), c('Th'), c('Tc'), c('3d')], // two pair K&10
    );
    final b = Board(
      top: [c('8s'), c('8h'), c('3d')], // pair 8
      middle: [c('Js'), c('Jd'), c('4h'), c('6c'), c('9d')], // pair J
      bottom: [c('Jc'), c('Jh'), c('9s'), c('9h'), c('4c')], // two pair J&9
    );
    final res = ScoreEngine.compare(a, b, ruleset: Ruleset.defaultRules);
    final aTotal = res.a.total;
    final bTotal = res.b.total;
    // A wins all 3 rows (+3), sweep (+3), top royalty +1。B top royalty +1。
    expect(aTotal, 7);
    expect(bTotal, -2);
  });
}
