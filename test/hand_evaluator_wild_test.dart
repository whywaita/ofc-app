import 'package:test/test.dart';
import 'package:ofc_app/core/models/playing_card.dart';
import 'package:ofc_app/core/models/rank.dart';
import 'package:ofc_app/core/models/suit.dart';
import 'package:ofc_app/features/game/domain/hand_evaluator.dart';
import 'package:ofc_app/features/game/domain/hand_category5.dart';
import 'package:ofc_app/features/game/domain/hand_category3.dart';

void main() {
  group('HandEvaluator.evaluate5Wild', () {
    test('Five of a Kind: 4 Aces + Joker', () {
      final cards = [
        PlayingCard(Rank.ace, Suit.spade),
        PlayingCard(Rank.ace, Suit.heart),
        PlayingCard(Rank.ace, Suit.diamond),
        PlayingCard(Rank.ace, Suit.club),
        const PlayingCard.joker(),
      ];
      final rank = HandEvaluator.evaluate5Wild(cards);
      expect(rank.category, Hand5Category.fiveOfAKind);
      expect(rank.isWild, true);
      expect(rank.tiebreakers.first, 14); // Ace
    });

    test('Natural Royal Flush without joker', () {
      final cards = [
        PlayingCard(Rank.ten, Suit.spade),
        PlayingCard(Rank.jack, Suit.spade),
        PlayingCard(Rank.queen, Suit.spade),
        PlayingCard(Rank.king, Suit.spade),
        PlayingCard(Rank.ace, Suit.spade),
      ];
      final rank = HandEvaluator.evaluate5Wild(cards);
      expect(rank.category, Hand5Category.naturalRoyalFlush);
      expect(rank.isWild, false);
    });

    test('Wild Royal Flush with joker', () {
      final cards = [
        PlayingCard(Rank.ten, Suit.heart),
        PlayingCard(Rank.jack, Suit.heart),
        PlayingCard(Rank.queen, Suit.heart),
        PlayingCard(Rank.king, Suit.heart),
        const PlayingCard.joker(),
      ];
      final rank = HandEvaluator.evaluate5Wild(cards);
      expect(rank.category, Hand5Category.wildRoyalFlush);
      expect(rank.isWild, true);
    });

    test('Four of a Kind with joker', () {
      final cards = [
        PlayingCard(Rank.king, Suit.spade),
        PlayingCard(Rank.king, Suit.heart),
        PlayingCard(Rank.king, Suit.diamond),
        const PlayingCard.joker(),
        PlayingCard(Rank.two, Suit.club),
      ];
      final rank = HandEvaluator.evaluate5Wild(cards);
      expect(rank.category, Hand5Category.fourOfAKind);
      expect(rank.isWild, true);
      expect(rank.tiebreakers.first, 13); // King
    });

    test('Full House with joker (3 + 2)', () {
      final cards = [
        PlayingCard(Rank.queen, Suit.spade),
        PlayingCard(Rank.queen, Suit.heart),
        PlayingCard(Rank.jack, Suit.diamond),
        PlayingCard(Rank.jack, Suit.club),
        const PlayingCard.joker(),
      ];
      final rank = HandEvaluator.evaluate5Wild(cards);
      expect(rank.category, Hand5Category.fullHouse);
      expect(rank.isWild, true);
    });

    test('Straight with joker', () {
      final cards = [
        PlayingCard(Rank.five, Suit.spade),
        PlayingCard(Rank.six, Suit.heart),
        PlayingCard(Rank.seven, Suit.diamond),
        PlayingCard(Rank.eight, Suit.club),
        const PlayingCard.joker(),
      ];
      final rank = HandEvaluator.evaluate5Wild(cards);
      expect(rank.category, Hand5Category.straight);
      expect(rank.isWild, true);
      expect(rank.tiebreakers.first, 9); // High card is 9
    });

    test('Flush with joker', () {
      final cards = [
        PlayingCard(Rank.two, Suit.club),
        PlayingCard(Rank.five, Suit.club),
        PlayingCard(Rank.seven, Suit.club),
        PlayingCard(Rank.nine, Suit.club),
        const PlayingCard.joker(),
      ];
      final rank = HandEvaluator.evaluate5Wild(cards);
      expect(rank.category, Hand5Category.flush);
      expect(rank.isWild, true);
    });

    test('Three of a Kind with joker', () {
      final cards = [
        PlayingCard(Rank.ten, Suit.spade),
        PlayingCard(Rank.ten, Suit.heart),
        const PlayingCard.joker(),
        PlayingCard(Rank.five, Suit.diamond),
        PlayingCard(Rank.three, Suit.club),
      ];
      final rank = HandEvaluator.evaluate5Wild(cards);
      expect(rank.category, Hand5Category.threeOfAKind);
      expect(rank.isWild, true);
      expect(rank.tiebreakers.first, 10);
    });

    test('One Pair with joker (joker as ace)', () {
      final cards = [
        PlayingCard(Rank.king, Suit.spade),
        const PlayingCard.joker(),
        PlayingCard(Rank.queen, Suit.heart),
        PlayingCard(Rank.jack, Suit.diamond),
        PlayingCard(Rank.nine, Suit.club),
      ];
      final rank = HandEvaluator.evaluate5Wild(cards);
      expect(rank.category, Hand5Category.onePair);
      expect(rank.isWild, true);
      expect(rank.tiebreakers.first, 13); // Pairs with King
    });

    test('Natural beats Wild in same category', () {
      final naturalSF = HandEvaluator.evaluate5Wild([
        PlayingCard(Rank.five, Suit.heart),
        PlayingCard(Rank.six, Suit.heart),
        PlayingCard(Rank.seven, Suit.heart),
        PlayingCard(Rank.eight, Suit.heart),
        PlayingCard(Rank.nine, Suit.heart),
      ]);

      final wildSF = HandEvaluator.evaluate5Wild([
        PlayingCard(Rank.five, Suit.spade),
        PlayingCard(Rank.six, Suit.spade),
        PlayingCard(Rank.seven, Suit.spade),
        PlayingCard(Rank.eight, Suit.spade),
        const PlayingCard.joker(),
      ]);

      expect(naturalSF.category, Hand5Category.straightFlush);
      expect(wildSF.category, Hand5Category.straightFlush);
      expect(naturalSF.compareTo(wildSF) > 0, true); // Natural wins
    });
  });

  group('HandEvaluator.evaluate3Wild', () {
    test('Three of a Kind with joker', () {
      final cards = [
        PlayingCard(Rank.ace, Suit.spade),
        PlayingCard(Rank.ace, Suit.heart),
        const PlayingCard.joker(),
      ];
      final rank = HandEvaluator.evaluate3Wild(cards);
      expect(rank.category, Hand3Category.threeOfAKind);
      expect(rank.isWild, true);
      expect(rank.tiebreakers.first, 14); // Aces
    });

    test('Pair with joker', () {
      final cards = [
        PlayingCard(Rank.king, Suit.spade),
        const PlayingCard.joker(),
        PlayingCard(Rank.five, Suit.diamond),
      ];
      final rank = HandEvaluator.evaluate3Wild(cards);
      expect(rank.category, Hand3Category.pair);
      expect(rank.isWild, true);
      expect(rank.tiebreakers.first, 13); // King pair
    });

    test('High card with joker becomes Ace', () {
      final cards = [
        const PlayingCard.joker(),
        PlayingCard(Rank.queen, Suit.heart),
        PlayingCard(Rank.jack, Suit.diamond),
      ];
      final rank = HandEvaluator.evaluate3Wild(cards);
      expect(rank.category, Hand3Category.pair);
      expect(rank.isWild, true);
      expect(rank.tiebreakers.first, 12); // Queen pair with Joker
    });

    test('Natural Three of a Kind beats Wild', () {
      final natural = HandEvaluator.evaluate3Wild([
        PlayingCard(Rank.king, Suit.spade),
        PlayingCard(Rank.king, Suit.heart),
        PlayingCard(Rank.king, Suit.diamond),
      ]);

      final wild = HandEvaluator.evaluate3Wild([
        PlayingCard(Rank.king, Suit.spade),
        PlayingCard(Rank.king, Suit.heart),
        const PlayingCard.joker(),
      ]);

      expect(natural.category, Hand3Category.threeOfAKind);
      expect(wild.category, Hand3Category.threeOfAKind);
      expect(natural.compareTo(wild) > 0, true); // Natural wins
    });
  });

  group('Joker parsing', () {
    test('Parse "JK" as joker', () {
      final joker = PlayingCard.parse('JK');
      expect(joker.isJoker, true);
      expect(joker.rank, null);
      expect(joker.suit, null);
    });

    test('Parse "jk" as joker (case insensitive)', () {
      final joker = PlayingCard.parse('jk');
      expect(joker.isJoker, true);
    });
  });
}
