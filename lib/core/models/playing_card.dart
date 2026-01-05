import 'rank.dart';
import 'suit.dart';

class PlayingCard {
  final Rank? rank;
  final Suit? suit;
  final bool isJoker;
  final int? jokerIndex; // To distinguish multiple jokers

  const PlayingCard(this.rank, this.suit)
      : isJoker = false,
        jokerIndex = null;
  const PlayingCard.joker({this.jokerIndex})
      : rank = null,
        suit = null,
        isJoker = true;

  factory PlayingCard.parse(String code) {
    if (code.toUpperCase() == 'JK') {
      return const PlayingCard.joker();
    }
    if (code.length != 2) {
      throw ArgumentError('Card code must be 2 chars like As, Td');
    }
    final r = Rank.fromSymbol(code[0]);
    final s = Suit.fromSymbol(code[1]);
    return PlayingCard(r, s);
  }

  @override
  bool operator ==(Object other) =>
      other is PlayingCard &&
      other.rank == rank &&
      other.suit == suit &&
      other.isJoker == isJoker &&
      other.jokerIndex == jokerIndex;

  @override
  int get hashCode => Object.hash(rank, suit, isJoker, jokerIndex);

  @override
  String toString() {
    if (isJoker) {
      return jokerIndex != null ? 'Joker$jokerIndex' : 'Joker';
    }
    return '${rank!.name}-${suit!.name}';
  }
}
