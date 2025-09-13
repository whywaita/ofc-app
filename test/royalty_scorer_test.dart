import 'package:test/test.dart';
import 'package:ofc_app_core/features/game/domain/hand_evaluator.dart';
import 'package:ofc_app_core/features/game/domain/ruleset.dart';
import 'helpers.dart';

void main() {
  final rules = Ruleset.defaultRules;
  test('top pair/trips royalties (baseline from docs)', () {
    final topJJ = HandEvaluator.evaluate3([c('Jc'), c('Jd'), c('2h')]);
    expect(rules.royaltyTop(topJJ), 2);
    final topAA = HandEvaluator.evaluate3([c('As'), c('Ad'), c('7c')]);
    expect(rules.royaltyTop(topAA), 5);
    final t222 = HandEvaluator.evaluate3([c('2s'), c('2d'), c('2c')]);
    expect(rules.royaltyTop(t222), 7);
    final tAAA = HandEvaluator.evaluate3([c('As'), c('Ah'), c('Ad')]);
    expect(rules.royaltyTop(tAAA), 22);
  });

  test('middle/bottom royalties', () {
    final midFlush =
        HandEvaluator.evaluate5([c('2h'), c('6h'), c('9h'), c('Jh'), c('Qh')]);
    expect(rules.royaltyMiddle(midFlush), 8);
    final botSF =
        HandEvaluator.evaluate5([c('6d'), c('7d'), c('8d'), c('9d'), c('Td')]);
    expect(rules.royaltyBottom(botSF), 15);
  });
}
