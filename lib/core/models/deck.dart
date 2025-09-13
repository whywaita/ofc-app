import 'dart:math';

import 'playing_card.dart';
import 'rank.dart';
import 'suit.dart';

class Deck {
  final List<PlayingCard> _cards;
  int _index = 0;

  Deck._(this._cards);

  factory Deck.standard({int? seed}) {
    final cards = <PlayingCard>[];
    for (final s in Suit.values) {
      for (final r in Rank.values) {
        cards.add(PlayingCard(r, s));
      }
    }
    final deck = Deck._(cards);
    deck.shuffle(seed: seed);
    return deck;
  }

  factory Deck.fromCodes(List<String> codes) {
    return Deck._(codes.map(PlayingCard.parse).toList());
  }

  void shuffle({int? seed}) {
    final rnd = seed == null ? Random() : Random(seed);
    for (int i = _cards.length - 1; i > 0; i--) {
      final j = rnd.nextInt(i + 1);
      final tmp = _cards[i];
      _cards[i] = _cards[j];
      _cards[j] = tmp;
    }
    _index = 0;
  }

  bool get isEmpty => _index >= _cards.length;
  int get remaining => _cards.length - _index;

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
