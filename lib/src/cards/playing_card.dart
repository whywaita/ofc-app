import 'rank.dart';
import 'suit.dart';

/// A card in play: either a [StandardCard] or a [Joker].
sealed class PlayingCard {
  const PlayingCard();

  /// Parses a code such as `As`, `Td`, `JK` or `JK2` (case-insensitive).
  factory PlayingCard.parse(String code) {
    final upper = code.toUpperCase();
    if (upper.startsWith('JK')) {
      final rest = upper.substring(2);
      if (rest.isEmpty) return const Joker();
      final index = int.tryParse(rest);
      if (index == null) {
        throw ArgumentError.value(code, 'code', 'Invalid joker code');
      }
      return Joker(index);
    }
    if (code.length != 2) {
      throw ArgumentError.value(
          code, 'code', 'Card code must be 2 chars like As, Td');
    }
    return StandardCard(Rank.fromSymbol(code[0]), Suit.fromSymbol(code[1]));
  }

  /// The code [PlayingCard.parse] reads back.
  String get code;

  @override
  String toString() => code;
}

final class StandardCard extends PlayingCard {
  const StandardCard(this.rank, this.suit);

  final Rank rank;
  final Suit suit;

  @override
  String get code => '${rank.symbol}${suit.symbol}';

  @override
  bool operator ==(Object other) =>
      other is StandardCard && other.rank == rank && other.suit == suit;

  @override
  int get hashCode => Object.hash(rank, suit);
}

/// A joker. [index] tells apart the jokers of one deck; `null` for an unnumbered joker.
final class Joker extends PlayingCard {
  const Joker([this.index]);

  final int? index;

  @override
  String get code => index == null ? 'JK' : 'JK$index';

  @override
  bool operator ==(Object other) => other is Joker && other.index == index;

  @override
  int get hashCode => Object.hash(Joker, index);
}
