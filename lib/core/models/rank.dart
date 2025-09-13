enum Rank {
  two(2),
  three(3),
  four(4),
  five(5),
  six(6),
  seven(7),
  eight(8),
  nine(9),
  ten(10),
  jack(11),
  queen(12),
  king(13),
  ace(14);

  const Rank(this.value);
  final int value;

  static Rank fromSymbol(String s) {
    switch (s.toUpperCase()) {
      case 'A':
        return Rank.ace;
      case 'K':
        return Rank.king;
      case 'Q':
        return Rank.queen;
      case 'J':
        return Rank.jack;
      case 'T':
        return Rank.ten;
      case '9':
        return Rank.nine;
      case '8':
        return Rank.eight;
      case '7':
        return Rank.seven;
      case '6':
        return Rank.six;
      case '5':
        return Rank.five;
      case '4':
        return Rank.four;
      case '3':
        return Rank.three;
      case '2':
        return Rank.two;
    }
    throw ArgumentError('Invalid rank symbol: $s');
  }
}
