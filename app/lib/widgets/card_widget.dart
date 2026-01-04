import 'package:flutter/material.dart';
import 'package:ofc_app_core/core/models/playing_card.dart';

/// Utility class for card rendering operations
class CardRenderer {
  /// Converts a card's rank to its symbol representation
  /// (A, K, Q, J, T for face cards, number for others)
  static String rankSymbol(PlayingCard card) {
    if (card.isJoker) return '🃏';

    switch (card.rank!.name) {
      case 'ace':
        return 'A';
      case 'king':
        return 'K';
      case 'queen':
        return 'Q';
      case 'jack':
        return 'J';
      case 'ten':
        return 'T';
      default:
        return card.rank!.value.toString();
    }
  }

  /// Converts a card's suit to its emoji representation
  static String suitEmoji(PlayingCard card) {
    if (card.isJoker) return '';

    switch (card.suit!.name) {
      case 'hearts':
        return '♥️';
      case 'diamonds':
        return '♦️';
      case 'spades':
        return '♠️';
      default:
        return '♣️';
    }
  }

  /// Returns true if the card is red (hearts or diamonds)
  static bool isRed(PlayingCard card) =>
      !card.isJoker && (card.suit!.name == 'hearts' || card.suit!.name == 'diamonds');

  /// Returns the color for the card text (red or black)
  static Color textColor(PlayingCard card) =>
      isRed(card) ? Colors.red : Colors.black87;
}

/// A widget that displays a playing card
class CardWidget extends StatelessWidget {
  final PlayingCard card;
  final bool large;
  final Color? borderColor;
  final bool isSmallScreen;

  const CardWidget({
    super.key,
    required this.card,
    this.large = false,
    this.borderColor,
    this.isSmallScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final text =
        '${CardRenderer.rankSymbol(card)}${CardRenderer.suitEmoji(card)}';
    final color = CardRenderer.textColor(card);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 6 : 10,
        vertical: isSmallScreen ? 4 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isSmallScreen ? 6 : 8),
        border: Border.all(color: borderColor ?? Colors.grey.shade400),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize:
              large ? (isSmallScreen ? 18 : 22) : (isSmallScreen ? 14 : 18),
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
