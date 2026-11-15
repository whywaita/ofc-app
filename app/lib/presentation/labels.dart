import 'package:ofc_app_core/ofc_core.dart';

/// Every piece of wording the screens show for domain values, in one place.
abstract final class Labels {
  static String rankSymbol(Rank r) => r.symbol;

  static String suitEmoji(Suit s) => switch (s) {
        Suit.spades => '♠️',
        Suit.hearts => '♥️',
        Suit.diamonds => '♦️',
        Suit.clubs => '♣️',
      };

  /// What a card shows on its face: `A♠️`, `🃏`.
  static String cardFace(PlayingCard c) => switch (c) {
        StandardCard(:final rank, :final suit) =>
          '${rankSymbol(rank)}${suitEmoji(suit)}',
        Joker() => '🃏',
      };

  /// What assistive technology reads for a card: `A of spades`, `Joker`.
  static String cardName(PlayingCard c) => switch (c) {
        StandardCard(:final rank, :final suit) =>
          '${rankSymbol(rank)} of ${suit.name}',
        Joker() => 'Joker',
      };

  static String row(BoardRow r) => switch (r) {
        BoardRow.top => 'Top',
        BoardRow.middle => 'Middle',
        BoardRow.bottom => 'Bottom',
      };

  static String hand3(Hand3Rank r) {
    final base = switch (r.category) {
      Hand3Category.threeOfAKind => 'Trips',
      Hand3Category.pair => 'Pair',
      Hand3Category.highCard => 'High',
    };
    return r.isWild ? '$base (Wild)' : base;
  }

  static String hand5(Hand5Rank r) {
    final base = switch (r.category) {
      Hand5Category.straightFlush =>
        r.isRoyalFlush ? 'Royal Flush' : 'Straight Flush',
      Hand5Category.fourOfAKind => 'Four of a Kind',
      Hand5Category.fullHouse => 'Full House',
      Hand5Category.flush => 'Flush',
      Hand5Category.straight => 'Straight',
      Hand5Category.threeOfAKind => 'Three of a Kind',
      Hand5Category.twoPair => 'Two Pair',
      Hand5Category.onePair => 'One Pair',
      Hand5Category.highCard => 'High Card',
    };
    return r.isWild ? '$base (Wild)' : base;
  }

  /// The made hand of [row] in [e].
  static String handOf(BoardEvaluation e, BoardRow row) => switch (row) {
        BoardRow.top => hand3(e.top),
        BoardRow.middle => hand5(e.middle),
        BoardRow.bottom => hand5(e.bottom),
      };

  static String placementError(PlacementError e, BoardRow row) => switch (e) {
        PlacementError.handClosed => 'Nothing to place now',
        PlacementError.notInHand => 'That card is not in your hand',
        PlacementError.rowFull => 'Row is full (${row.capacity} max)',
        PlacementError.drawLimitReached => 'Two cards per draw',
        PlacementError.lockedIn => 'That card is locked in',
      };

  static String mode(String base, GameOptions options) =>
      switch (options.wildMode) {
        WildMode.none => base,
        WildMode.deuces => '$base (Deuces Wild)',
        WildMode.joker => '$base (Joker Wild)',
      };

  static String player(Player p) => p == Player.a ? 'Player A' : 'Player B';

  /// One line of the action log.
  static String action(HandAction a) => switch (a) {
        DrawAction(:final cards) => 'draw ${cards.length}: '
            '${cards.map(cardFace).join(' ')}',
        PlaceAction(:final card, :final row) =>
          'place: ${cardFace(card)} → ${Labels.row(row)}',
        MoveAction(:final card, :final from, :final to) =>
          'move: ${cardFace(card)} ${Labels.row(from)} → ${Labels.row(to)}',
        ReturnAction(:final card, :final from) =>
          'return: ${cardFace(card)} ${Labels.row(from)} → Tray',
        DiscardAction(:final card) => 'discard: ${cardFace(card)}',
        CommitAction() => 'commit',
      };

  static String signed(int n) => n > 0 ? '+$n' : '$n';
}
