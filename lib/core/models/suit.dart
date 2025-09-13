enum Suit {
  spades('s'),
  hearts('h'),
  diamonds('d'),
  clubs('c');

  const Suit(this.symbol);
  final String symbol;

  static Suit fromSymbol(String s) {
    switch (s.toLowerCase()) {
      case 's':
        return Suit.spades;
      case 'h':
        return Suit.hearts;
      case 'd':
        return Suit.diamonds;
      case 'c':
        return Suit.clubs;
    }
    throw ArgumentError('Invalid suit symbol: $s');
  }
}
