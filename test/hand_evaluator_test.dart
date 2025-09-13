import 'package:test/test.dart';
import 'package:ofc_app_core/features/game/domain/hand_evaluator.dart';
import 'package:ofc_app_core/features/game/domain/hand_category5.dart';
import 'package:ofc_app_core/features/game/domain/hand_category3.dart';
import 'helpers.dart';

void main() {
  test('evaluate5 detects straight flush and four of a kind', () {
    final sf =
        HandEvaluator.evaluate5([c('Th'), c('Jh'), c('Qh'), c('Kh'), c('Ah')]);
    expect(sf.category, Hand5Category.straightFlush);
    final four =
        HandEvaluator.evaluate5([c('9s'), c('9h'), c('9d'), c('9c'), c('2h')]);
    expect(four.category, Hand5Category.fourOfAKind);
  });

  test('evaluate3 detects trips and pair', () {
    final trips = HandEvaluator.evaluate3([c('2s'), c('2h'), c('2d')]);
    expect(trips.category, Hand3Category.threeOfAKind);
    final pair = HandEvaluator.evaluate3([c('As'), c('Ah'), c('7d')]);
    expect(pair.category, Hand3Category.pair);
  });
}
