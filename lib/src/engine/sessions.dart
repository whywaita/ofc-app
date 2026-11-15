import '../board/board.dart';
import '../rules/fantasy.dart';
import '../rules/game_options.dart';
import '../rules/ruleset.dart';
import '../scoring/score_engine.dart';
import 'player_hand.dart';

/// The outcome of one player's committed hand.
class HandResult {
  HandResult._(this.board, this.evaluation, this.royalties, this.nextFantasy,
      this.history);

  factory HandResult._of(PlayerHand hand, Board board, FantasyState fantasy,
      GameOptions options, Ruleset ruleset) {
    final evaluation = BoardEvaluation.of(board, wildMode: options.wildMode);
    return HandResult._(
      board,
      evaluation,
      ruleset.royalties(evaluation),
      FantasyState.next(fantasy, evaluation),
      List.unmodifiable(hand.history),
    );
  }

  final Board board;
  final BoardEvaluation evaluation;
  final Royalties royalties;

  /// The Fantasy state this hand leads to.
  final FantasyState nextFantasy;

  final List<HandAction> history;
}

/// Solo practice: one hand after another from a seed the player can share.
///
/// Hand `n` deals from seed `seed + n - 1`, so the first hand of a seed is always the same and the
/// following hands are new deals that are still reproducible.
class PracticeSession {
  PracticeSession({
    required this.seed,
    this.options = GameOptions.standard,
    this.ruleset = Ruleset.standard,
    FantasyState fantasy = const FantasyState.inactive(),
  }) : _fantasy = fantasy {
    _hand = _deal();
  }

  final int seed;
  final GameOptions options;
  final Ruleset ruleset;

  int _handNumber = 1;
  FantasyState _fantasy;
  late PlayerHand _hand;
  HandResult? _lastResult;

  int get handNumber => _handNumber;

  /// The Fantasy state the current hand was dealt under.
  FantasyState get fantasy => _fantasy;

  PlayerHand get hand => _hand;

  /// The result of the current hand once committed, otherwise of the previous one (or null).
  HandResult? get lastResult => _lastResult;

  HandResult commit() {
    final board = _hand.commit();
    return _lastResult =
        HandResult._of(_hand, board, _fantasy, options, ruleset);
  }

  /// Deals the next hand, entering or leaving Fantasyland as the last hand earned.
  void nextHand() {
    if (!_hand.isCommitted) throw StateError('Commit the current hand first');
    _fantasy = _lastResult!.nextFantasy;
    _handNumber++;
    _hand = _deal();
  }

  PlayerHand _deal() => PlayerHand.deal(
        options.newDeck(seed: seed + _handNumber - 1),
        count: _fantasy.dealCount,
      );
}

enum Player {
  a,
  b;

  Player get other => this == a ? b : a;
}

class MatchResult {
  const MatchResult(this.a, this.b, this.score);

  final HandResult a;
  final HandResult b;
  final VersusScore score;

  HandResult of(Player p) => p == Player.a ? a : b;
}

/// Two players sharing one deck and one device (pass & play).
///
/// Players take turns draw by draw. A player in Fantasyland has every card from the start, so the
/// other player keeps the turn until done; the Fantasy player then sets their board.
class HeadsUpMatch {
  HeadsUpMatch({
    this.options = GameOptions.standard,
    this.ruleset = Ruleset.standard,
    int? seed,
    FantasyState fantasyA = const FantasyState.inactive(),
    FantasyState fantasyB = const FantasyState.inactive(),
  }) : _fantasy = {Player.a: fantasyA, Player.b: fantasyB} {
    final deck = options.newDeck(seed: seed);
    for (final p in Player.values) {
      _hands[p] = PlayerHand.deal(deck, count: _fantasy[p]!.dealCount);
    }
    _current = fantasyA.isActive && !fantasyB.isActive ? Player.b : Player.a;
  }

  final GameOptions options;
  final Ruleset ruleset;
  final Map<Player, FantasyState> _fantasy;
  final Map<Player, PlayerHand> _hands = {};
  final Map<Player, HandResult> _results = {};
  late Player _current;
  MatchResult? _result;

  Player get current => _current;
  PlayerHand hand(Player p) => _hands[p]!;
  PlayerHand get currentHand => hand(_current);
  FantasyState fantasy(Player p) => _fantasy[p]!;

  bool get isOver => _result != null;
  MatchResult? get result => _result;

  /// The current player can commit (board complete) or draw the next three.
  bool get canAdvance =>
      !isOver && (currentHand.isComplete || currentHand.canDrawNext);

  /// Commits the current player's board, or draws their next three; then passes the turn.
  void advance() {
    if (!canAdvance) throw StateError('Nothing to advance');
    final h = currentHand;
    final other = hand(_current.other);
    if (h.isComplete) {
      final board = h.commit();
      _results[_current] =
          HandResult._of(h, board, _fantasy[_current]!, options, ruleset);
      if (!other.isCommitted) {
        _current = _current.other;
      } else {
        final a = _results[Player.a]!;
        final b = _results[Player.b]!;
        _result = MatchResult(
            a, b, ScoreEngine(ruleset).compare(a.evaluation, b.evaluation));
      }
      return;
    }
    h.drawNext();
    if (!other.isCommitted && !other.isFantasy) _current = _current.other;
  }

  /// The next hand, with each player's Fantasy state carried over.
  HeadsUpMatch nextMatch({int? seed}) {
    final r = _result;
    if (r == null) throw StateError('Match not over');
    return HeadsUpMatch(
      options: options,
      ruleset: ruleset,
      seed: seed,
      fantasyA: r.a.nextFantasy,
      fantasyB: r.b.nextFantasy,
    );
  }
}
