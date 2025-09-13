import '../../../core/models/deck.dart';
import '../../../core/models/playing_card.dart';
import 'board.dart';
import 'fantasy_engine.dart';
import 'pineapple_engine.dart';
import 'score_engine.dart';

enum Player { a, b }

enum GamePhase { drawing, placing, committed }

class GameState {
  final Deck deck;
  late PineappleEngine aEngine;
  late PineappleEngine bEngine;
  FantasyState fantasyA;
  FantasyState fantasyB;

  GamePhase phase = GamePhase.drawing;
  Player turn = Player.a; // ここでは強制しない（API利用側で制御）
  final List<String> history = [];

  Board? boardA;
  Board? boardB;
  VersusScore? lastScore;

  GameState({Deck? deck, FantasyState? fantasyA, FantasyState? fantasyB})
      : deck = deck ?? Deck.standard(),
        fantasyA = fantasyA ?? const FantasyState.inactive(),
        fantasyB = fantasyB ?? const FantasyState.inactive() {
    aEngine = PineappleEngine(this.deck);
    bEngine = PineappleEngine(this.deck);
  }

  void startHand() {
    if (phase != GamePhase.drawing) {
      throw StateError('Hand already started');
    }
    aEngine.startWithFantasy(
        initialFantasyCount: fantasyA.active ? fantasyA.initialCount : 0);
    bEngine.startWithFantasy(
        initialFantasyCount: fantasyB.active ? fantasyB.initialCount : 0);
    phase = GamePhase.placing;
    history
        .add('startHand A:${fantasyA.initialCount} B:${fantasyB.initialCount}');
  }

  PineappleEngine engineOf(Player p) => p == Player.a ? aEngine : bEngine;

  void place(Player p, Slot slot, PlayingCard card) {
    engineOf(p).place(slot, card);
    history.add('place ${p.name} ${slot.name} $card');
  }

  void discard(Player p, PlayingCard card) {
    engineOf(p).discard(card);
    history.add('discard ${p.name} $card');
  }

  bool needsCycle(Player p) => engineOf(p).needsCycle;

  void nextCycle(Player p) {
    engineOf(p).nextCycle();
    history.add('draw3 ${p.name}');
  }

  Board finalize(Player p) {
    final b = engineOf(p).finalize();
    if (p == Player.a) {
      boardA = b;
    } else {
      boardB = b;
    }
    if (boardA != null && boardB != null) {
      _commitResult(boardA!, boardB!);
    }
    return b;
  }

  // テスト/ツール用: 直接ボードを渡して結果確定
  void commitWithBoards(Board a, Board b) {
    boardA = a;
    boardB = b;
    _commitResult(a, b);
  }

  void _commitResult(Board a, Board b) {
    final res = ScoreEngine.compare(a, b);
    lastScore = res;
    final ea = BoardEval.from(a);
    final eb = BoardEval.from(b);
    fantasyA = FantasyEngine.nextState(fantasyA, ea);
    fantasyB = FantasyEngine.nextState(fantasyB, eb);
    phase = GamePhase.committed;
    history.add('commit result a:${res.a.total} b:${res.b.total}');
  }
}
