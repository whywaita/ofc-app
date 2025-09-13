import 'rank.dart';
import 'suit.dart';

class PlayingCard {
  final Rank rank;
  final Suit suit;
  const PlayingCard(this.rank, this.suit);

  factory PlayingCard.parse(String code) {
    if (code.length != 2) {
      throw ArgumentError('Card code must be 2 chars like As, Td');
    }
    final r = Rank.fromSymbol(code[0]);
    final s = Suit.fromSymbol(code[1]);
    return PlayingCard(r, s);
  }

  @override
  bool operator ==(Object other) =>
      other is PlayingCard && other.rank == rank && other.suit == suit;

  @override
  int get hashCode => Object.hash(rank, suit);

  @override
  String toString() => '${rank.name}-${suit.name}';
}
