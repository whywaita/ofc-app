import 'package:material_ui/material_ui.dart';
import 'package:ofc_app_core/ofc_core.dart';

import '../presentation/labels.dart';

/// The face of one card.
class CardWidget extends StatelessWidget {
  const CardWidget({
    super.key,
    required this.card,
    this.large = false,
    this.borderColor,
    this.compact = false,
  });

  final PlayingCard card;

  /// Drawn bigger, for the drag feedback.
  final bool large;
  final Color? borderColor;

  /// Tighter padding and smaller type for phone-width layouts.
  final bool compact;

  static Color textColor(PlayingCard card) =>
      card is StandardCard && card.suit.isRed ? Colors.red : Colors.black87;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 4 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
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
        Labels.cardFace(card),
        style: TextStyle(
          fontSize: large ? (compact ? 18 : 22) : (compact ? 14 : 18),
          color: textColor(card),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Cards in a centred, wrapping line.
class CardLine extends StatelessWidget {
  const CardLine(this.cards, {super.key, this.compact = false});

  final List<PlayingCard> cards;
  final bool compact;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          for (final c in cards) CardWidget(card: c, compact: compact)
        ],
      );
}
