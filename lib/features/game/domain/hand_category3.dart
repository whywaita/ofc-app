enum Hand3Category { highCard, pair, threeOfAKind }

class Hand3Rank implements Comparable<Hand3Rank> {
  final Hand3Category category;
  final List<int>
      tiebreakers; // high to low (e.g., trips rank or pair + kicker)
  const Hand3Rank(this.category, this.tiebreakers);

  @override
  int compareTo(Hand3Rank other) {
    final c = category.index.compareTo(other.category.index);
    if (c != 0) return c;
    for (var i = 0;
        i < tiebreakers.length && i < other.tiebreakers.length;
        i++) {
      final diff = tiebreakers[i].compareTo(other.tiebreakers[i]);
      if (diff != 0) return diff;
    }
    return tiebreakers.length.compareTo(other.tiebreakers.length);
  }
}
