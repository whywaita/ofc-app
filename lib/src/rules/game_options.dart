import '../cards/deck.dart';
import '../cards/playing_card.dart';
import '../cards/rank.dart';

/// Which cards act as wild cards.
enum WildMode {
  /// No wild cards.
  none,

  /// The four 2s are wild (52-card deck).
  deuces,

  /// Two jokers are added to the deck and are wild.
  joker;

  bool isWild(PlayingCard card) => switch (this) {
        WildMode.none => false,
        WildMode.deuces => card is StandardCard && card.rank == Rank.two,
        WildMode.joker => card is Joker,
      };
}

/// Options fixed for a whole game.
class GameOptions {
  const GameOptions({this.wildMode = WildMode.none});

  final WildMode wildMode;

  static const standard = GameOptions();
  static const deucesWild = GameOptions(wildMode: WildMode.deuces);
  static const jokerWild = GameOptions(wildMode: WildMode.joker);

  /// A shuffled deck for this game: 54 cards when jokers are wild, 52 otherwise.
  Deck newDeck({int? seed}) => wildMode == WildMode.joker
      ? Deck.withJokers(seed: seed, jokerCount: 2)
      : Deck.standard(seed: seed);

  @override
  bool operator ==(Object other) =>
      other is GameOptions && other.wildMode == wildMode;

  @override
  int get hashCode => wildMode.hashCode;
}
