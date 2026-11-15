/// Made hands of a five-card row, weakest first. The index is the strength.
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

/// Made hands of the three-card top row, weakest first.
enum Hand3Category { highCard, pair, threeOfAKind }

/// Compares two tiebreaker lists element by element; only the common prefix counts.
int _compareTiebreakers(List<int> a, List<int> b) {
  for (var i = 0; i < a.length && i < b.length; i++) {
    final d = a[i].compareTo(b[i]);
    if (d != 0) return d.sign;
  }
  return 0;
}

bool _listEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// The strength of a five-card hand.
///
/// [tiebreakers] are rank values, most significant first:
/// straight (flush): `[high]` (5 for the wheel); four of a kind: `[quad, kicker]`;
/// full house: `[trips, pair]`; three of a kind: `[trips, k1, k2]`; two pair: `[hi, lo, kicker]`;
/// one pair: `[pair, k1, k2, k3]`; flush / high card: all five ranks.
///
/// [isWild] records that wild cards were used. It is shown to the player but does not change the
/// strength.
class Hand5Rank implements Comparable<Hand5Rank> {
  const Hand5Rank(this.category, this.tiebreakers, {this.isWild = false});

  final Hand5Category category;
  final List<int> tiebreakers;
  final bool isWild;

  bool get isRoyalFlush =>
      category == Hand5Category.straightFlush && tiebreakers.first == 14;

  @override
  int compareTo(Hand5Rank other) {
    final c = category.index.compareTo(other.category.index);
    if (c != 0) return c.sign;
    return _compareTiebreakers(tiebreakers, other.tiebreakers);
  }

  @override
  bool operator ==(Object other) =>
      other is Hand5Rank &&
      other.category == category &&
      other.isWild == isWild &&
      _listEquals(other.tiebreakers, tiebreakers);

  @override
  int get hashCode =>
      Object.hash(category, isWild, Object.hashAll(tiebreakers));

  @override
  String toString() =>
      'Hand5Rank(${category.name}, $tiebreakers${isWild ? ', wild' : ''})';
}

/// The strength of a three-card top hand.
///
/// [tiebreakers]: three of a kind `[trips]`; pair `[pair, kicker]`; high card all three ranks.
class Hand3Rank implements Comparable<Hand3Rank> {
  const Hand3Rank(this.category, this.tiebreakers, {this.isWild = false});

  final Hand3Category category;
  final List<int> tiebreakers;
  final bool isWild;

  @override
  int compareTo(Hand3Rank other) {
    final c = category.index.compareTo(other.category.index);
    if (c != 0) return c.sign;
    return _compareTiebreakers(tiebreakers, other.tiebreakers);
  }

  /// Compares this top hand with a five-card hand, as the foul rule does: trips against three of a
  /// kind, a pair against one pair, high cards against high card, using the cards this hand has.
  int compareToFive(Hand5Rank five) {
    final asFive = switch (category) {
      Hand3Category.threeOfAKind => Hand5Category.threeOfAKind,
      Hand3Category.pair => Hand5Category.onePair,
      Hand3Category.highCard => Hand5Category.highCard,
    };
    final c = asFive.index.compareTo(five.category.index);
    if (c != 0) return c.sign;
    return _compareTiebreakers(tiebreakers, five.tiebreakers);
  }

  @override
  bool operator ==(Object other) =>
      other is Hand3Rank &&
      other.category == category &&
      other.isWild == isWild &&
      _listEquals(other.tiebreakers, tiebreakers);

  @override
  int get hashCode =>
      Object.hash(category, isWild, Object.hashAll(tiebreakers));

  @override
  String toString() =>
      'Hand3Rank(${category.name}, $tiebreakers${isWild ? ', wild' : ''})';
}
