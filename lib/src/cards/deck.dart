import 'dart:math';

import 'playing_card.dart';
import 'rank.dart';
import 'suit.dart';

/// An ordered pile of cards dealt from the front.
class Deck {
  Deck._(this._cards);

  /// 52 cards shuffled with [seed]. The shuffle is pinned: the same seed always deals the same
  /// order, and recorded seeds (UI flows, bug reports) rely on it.
  factory Deck.standard({int? seed}) =>
      Deck._(_standardCards())..shuffle(seed: seed);

  /// 52 cards plus [jokerCount] jokers numbered from 1, shuffled with [seed].
  factory Deck.withJokers({int? seed, int jokerCount = 2}) => Deck._([
        ..._standardCards(),
        for (var i = 1; i <= jokerCount; i++) Joker(i),
      ])
        ..shuffle(seed: seed);

  /// Cards in exactly the given order, unshuffled. For tests and reproductions.
  factory Deck.fromCodes(List<String> codes) =>
      Deck._(codes.map(PlayingCard.parse).toList());

  final List<PlayingCard> _cards;
  int _index = 0;

  static List<PlayingCard> _standardCards() => [
        for (final s in Suit.values)
          for (final r in Rank.values) StandardCard(r, s),
      ];

  /// Fisher-Yates over the whole deck; resets the deal position.
  void shuffle({int? seed}) {
    final rnd = seed == null ? Random() : Random(seed);
    for (var i = _cards.length - 1; i > 0; i--) {
      final j = rnd.nextInt(i + 1);
      final tmp = _cards[i];
      _cards[i] = _cards[j];
      _cards[j] = tmp;
    }
    _index = 0;
  }

  int get remaining => _cards.length - _index;
  bool get isEmpty => remaining == 0;

  List<PlayingCard> draw(int n) {
    if (remaining < n) {
      throw StateError(
          'Not enough cards to draw: need $n, remaining $remaining');
    }
    final res = _cards.sublist(_index, _index + n);
    _index += n;
    return res;
  }
}
