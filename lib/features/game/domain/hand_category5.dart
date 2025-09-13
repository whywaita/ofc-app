enum Hand5Category {
  highCard,
  onePair,
  twoPair,
  threeOfAKind,
  straight,
  flush,
  fullHouse,
  fourOfAKind,
  straightFlush,
}

class Hand5Rank implements Comparable<Hand5Rank> {
  final Hand5Category category;
  final List<int> tiebreakers; // high to low
  const Hand5Rank(this.category, this.tiebreakers);

  @override
  int compareTo(Hand5Rank other) {
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
