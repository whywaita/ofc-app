/// Card suit. Declaration order is part of the deck order, so seeded deals depend on it.
enum Suit {
  spades('s'),
  hearts('h'),
  diamonds('d'),
  clubs('c');

  const Suit(this.symbol);

  /// One-character lower-case symbol used in card codes.
  final String symbol;

  bool get isRed => this == hearts || this == diamonds;

  static Suit fromSymbol(String s) {
    final lower = s.toLowerCase();
    for (final suit in values) {
      if (suit.symbol == lower) return suit;
    }
    throw ArgumentError.value(s, 's', 'Invalid suit symbol');
  }
}
