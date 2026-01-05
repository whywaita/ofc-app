import 'package:ofc_app_core/core/models/deck.dart';
import 'package:ofc_app_core/core/models/playing_card.dart';
import 'package:ofc_app_core/core/models/rank.dart';
import 'package:ofc_app_core/core/models/suit.dart';
import 'package:ofc_app_core/features/game/domain/hand_category3.dart';
import 'package:ofc_app_core/features/game/domain/hand_category5.dart';
import 'package:ofc_app_core/features/game/domain/hand_evaluator.dart';
import 'package:test/test.dart';

void main() {
  group('evaluate5JokerWild', () {
    test('No jokers: returns normal evaluation', () {
      final cards = [
        PlayingCard(Rank.ace, Suit.spades),
        PlayingCard(Rank.king, Suit.spades),
        PlayingCard(Rank.queen, Suit.spades),
        PlayingCard(Rank.jack, Suit.spades),
        PlayingCard(Rank.ten, Suit.spades),
      ];
      final rank = HandEvaluator.evaluate5JokerWild(cards);
      expect(rank.category, Hand5Category.straightFlush);
      expect(rank.isWild, false);
    });

    test('One joker + pair = Three of a Kind', () {
      final cards = [
        PlayingCard(Rank.ace, Suit.spades),
        PlayingCard(Rank.ace, Suit.hearts),
        const PlayingCard.joker(),
        PlayingCard(Rank.five, Suit.clubs),
        PlayingCard(Rank.three, Suit.diamonds),
      ];
      final rank = HandEvaluator.evaluate5JokerWild(cards);
      expect(rank.category, Hand5Category.threeOfAKind);
      expect(rank.isWild, true);
    });

    test('Two jokers + pair = Four of a Kind', () {
      final cards = [
        PlayingCard(Rank.king, Suit.spades),
        PlayingCard(Rank.king, Suit.hearts),
        const PlayingCard.joker(),
        const PlayingCard.joker(),
        PlayingCard(Rank.three, Suit.diamonds),
      ];
      final rank = HandEvaluator.evaluate5JokerWild(cards);
      expect(rank.category, Hand5Category.fourOfAKind);
      expect(rank.isWild, true);
    });

    test('One joker + four to flush = Flush', () {
      final cards = [
        PlayingCard(Rank.ace, Suit.hearts),
        PlayingCard(Rank.king, Suit.hearts),
        PlayingCard(Rank.queen, Suit.hearts),
        PlayingCard(Rank.jack, Suit.hearts),
        const PlayingCard.joker(),
      ];
      final rank = HandEvaluator.evaluate5JokerWild(cards);
      // Could be straight flush (A-K-Q-J-10)
      expect(rank.category, Hand5Category.straightFlush);
      expect(rank.isWild, true);
    });

    test('One joker + four to straight = Straight', () {
      final cards = [
        PlayingCard(Rank.ten, Suit.spades),
        PlayingCard(Rank.nine, Suit.hearts),
        PlayingCard(Rank.eight, Suit.clubs),
        PlayingCard(Rank.seven, Suit.diamonds),
        const PlayingCard.joker(),
      ];
      final rank = HandEvaluator.evaluate5JokerWild(cards);
      expect(rank.category, Hand5Category.straight);
      expect(rank.isWild, true);
    });

    test('Seed 2: two jokers in hand', () {
      // Seed 2 gives: 8♥, Joker, J♠, 6♥, Joker
      final deck = Deck.withJokers(seed: 2, jokerCount: 2);
      final cards = deck.draw(5);
      final jokerCount = cards.where((c) => c.isJoker).length;
      expect(jokerCount, 2);

      final rank = HandEvaluator.evaluate5JokerWild(cards);
      expect(rank.isWild, true);
      // With 2 jokers + random cards, should be at least three of a kind
      expect(rank.category.index,
          greaterThanOrEqualTo(Hand5Category.threeOfAKind.index));
    });

    test('Seed 19: joker with pair of kings', () {
      // Seed 19 gives: K♥, A♦, Joker, K♣, 4♦
      final deck = Deck.withJokers(seed: 19, jokerCount: 2);
      final cards = deck.draw(5);
      final jokerCount = cards.where((c) => c.isJoker).length;
      expect(jokerCount, 1);

      final rank = HandEvaluator.evaluate5JokerWild(cards);
      expect(rank.isWild, true);
      // K-K + Joker = Three Kings
      expect(rank.category, Hand5Category.threeOfAKind);
      expect(rank.tiebreakers.first, 13); // King
    });
  });

  group('evaluate3JokerWild', () {
    test('No jokers: returns normal evaluation', () {
      final cards = [
        PlayingCard(Rank.ace, Suit.spades),
        PlayingCard(Rank.ace, Suit.hearts),
        PlayingCard(Rank.ace, Suit.diamonds),
      ];
      final rank = HandEvaluator.evaluate3JokerWild(cards);
      expect(rank.category, Hand3Category.threeOfAKind);
      expect(rank.isWild, false);
    });

    test('One joker + pair = Three of a Kind', () {
      final cards = [
        PlayingCard(Rank.queen, Suit.spades),
        PlayingCard(Rank.queen, Suit.hearts),
        const PlayingCard.joker(),
      ];
      final rank = HandEvaluator.evaluate3JokerWild(cards);
      expect(rank.category, Hand3Category.threeOfAKind);
      expect(rank.isWild, true);
      expect(rank.tiebreakers.first, 12); // Queen
    });

    test('Two jokers + any card = Three of a Kind', () {
      final cards = [
        PlayingCard(Rank.five, Suit.spades),
        const PlayingCard.joker(),
        const PlayingCard.joker(),
      ];
      final rank = HandEvaluator.evaluate3JokerWild(cards);
      expect(rank.category, Hand3Category.threeOfAKind);
      expect(rank.isWild, true);
    });

    test('One joker + two different cards = High card (joker as Ace)', () {
      // In OFC Joker Wild, joker does NOT create a pair
      // Instead, joker becomes Ace for high card
      final cards = [
        PlayingCard(Rank.ace, Suit.spades),
        PlayingCard(Rank.king, Suit.hearts),
        const PlayingCard.joker(),
      ];
      final rank = HandEvaluator.evaluate3JokerWild(cards);
      expect(rank.category, Hand3Category.highCard);
      expect(rank.isWild, true);
      expect(rank.tiebreakers, [14, 14, 13]); // A-A-K (joker as Ace)
    });

    test('Three jokers = Three Aces', () {
      final cards = [
        const PlayingCard.joker(),
        const PlayingCard.joker(),
        const PlayingCard.joker(),
      ];
      final rank = HandEvaluator.evaluate3JokerWild(cards);
      expect(rank.category, Hand3Category.threeOfAKind);
      expect(rank.isWild, true);
      expect(rank.tiebreakers.first, 14); // Aces
    });

    // OFC foul prevention: Joker should be used as high card when needed
    test('One joker + K + 6 should be high card (not pair) for OFC top row', () {
      // In OFC, we may need to NOT make a pair to avoid foul
      // Joker, K, 6 should be evaluated as K-high (K, Joker as A, 6)
      // NOT as pair of Kings which would cause foul if middle is weaker
      final cards = [
        const PlayingCard.joker(),
        PlayingCard(Rank.king, Suit.spades),
        PlayingCard(Rank.six, Suit.diamonds),
      ];
      final rank = HandEvaluator.evaluate3JokerWild(cards);
      // Expected: High card (Joker becomes Ace, so A-K-6)
      // This should NOT be a pair - Joker enhances the high card only
      expect(rank.category, Hand3Category.highCard);
      expect(rank.isWild, true);
      expect(rank.tiebreakers, [14, 13, 6]); // A-K-6
    });
  });
}
