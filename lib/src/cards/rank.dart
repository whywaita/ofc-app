/// Card rank. [value] runs 2..14 with the ace high.
enum Rank {
  two(2, '2'),
  three(3, '3'),
  four(4, '4'),
  five(5, '5'),
  six(6, '6'),
  seven(7, '7'),
  eight(8, '8'),
  nine(9, '9'),
  ten(10, 'T'),
  jack(11, 'J'),
  queen(12, 'Q'),
  king(13, 'K'),
  ace(14, 'A');

  const Rank(this.value, this.symbol);

  final int value;

  /// One-character symbol used in card codes: `2`..`9`, `T`, `J`, `Q`, `K`, `A`.
  final String symbol;

  static Rank fromSymbol(String s) {
    final upper = s.toUpperCase();
    for (final r in values) {
      if (r.symbol == upper) return r;
    }
    throw ArgumentError.value(s, 's', 'Invalid rank symbol');
  }

  static Rank fromValue(int v) {
    for (final r in values) {
      if (r.value == v) return r;
    }
    throw ArgumentError.value(v, 'v', 'Invalid rank value');
  }
}
