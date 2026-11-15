import 'package:ofc_app_core/ofc_core.dart';
import 'package:test/test.dart';

/// Plays out [hand] with a simple policy: fill bottom, then middle, then top.
void autoPlay(PlayerHand hand) {
  BoardRow free() => [BoardRow.bottom, BoardRow.middle, BoardRow.top]
      .firstWhere((r) => hand.row(r).length < r.capacity);
  while (!hand.isComplete) {
    final limit = hand.isFantasy
        ? 13
        : (hand.history.whereType<DrawAction>().length == 1 ? 5 : 2);
    for (var i = 0; i < limit && !hand.isComplete; i++) {
      hand.place(hand.tray.first, free());
    }
    if (!hand.isComplete) hand.drawNext();
  }
}

void main() {
  group('PracticeSession', () {
    test('first hand deals from the chosen seed', () {
      final s = PracticeSession(seed: 7);
      expect(s.handNumber, 1);
      expect(s.hand.tray, Deck.standard(seed: 7).draw(5));
    });

    test('commit returns the evaluated result and the next Fantasy state', () {
      final s = PracticeSession(seed: 7);
      autoPlay(s.hand);
      final r = s.commit();
      expect(r.board.isComplete, isTrue);
      expect(r.evaluation.isFoul, BoardEvaluation.of(r.board).isFoul);
      expect(r.royalties.total, Ruleset.standard.royalties(r.evaluation).total);
      expect(r.history.last, isA<CommitAction>());
      expect(s.lastResult, same(r));
    });

    test('the next hand deals new cards and carries Fantasy over', () {
      final s =
          PracticeSession(seed: 7, fantasy: const FantasyState.active(14));
      expect(s.hand.tray, hasLength(14));
      autoPlay(s.hand);
      final r = s.commit();
      final first = s.hand.currentDraw.toSet();
      s.nextHand();
      expect(s.handNumber, 2);
      expect(s.fantasy, r.nextFantasy);
      expect(s.hand.tray.length, r.nextFantasy.dealCount);
      expect(s.hand.tray.toSet().containsAll(first), isFalse);
    });

    test('nextHand before commit is refused', () {
      expect(PracticeSession(seed: 1).nextHand, throwsStateError);
    });

    test('joker wild deals from a 54-card deck', () {
      final s = PracticeSession(seed: 3, options: GameOptions.jokerWild);
      expect(s.hand.tray, Deck.withJokers(seed: 3).draw(5));
    });
  });

  group('HeadsUpMatch (pass & play)', () {
    test('both players are dealt; A starts', () {
      final m = HeadsUpMatch(seed: 5);
      expect(m.current, Player.a);
      expect(m.hand(Player.a).tray, hasLength(5));
      expect(m.hand(Player.b).tray, hasLength(5));
    });

    test('turns alternate after each draw', () {
      final m = HeadsUpMatch(seed: 5);
      final a = m.hand(Player.a);
      for (final card in List.of(a.tray)) {
        a.place(
            card,
            a.row(BoardRow.bottom).length < 5
                ? BoardRow.bottom
                : BoardRow.middle);
      }
      expect(m.canAdvance, isTrue);
      m.advance();
      expect(m.current, Player.b);
      expect(a.tray, hasLength(3));
    });

    test('a full match produces a score and next Fantasy states', () {
      final m = HeadsUpMatch(seed: 5);
      while (!m.isOver) {
        final h = m.currentHand;
        final limit = h.history.whereType<DrawAction>().length == 1 ? 5 : 2;
        final free = [BoardRow.bottom, BoardRow.middle, BoardRow.top];
        for (var i = 0; i < limit && !h.isComplete; i++) {
          h.place(h.tray.first,
              free.firstWhere((r) => h.row(r).length < r.capacity));
        }
        m.advance();
      }
      final r = m.result!;
      expect(r.score.a.total + r.score.b.total,
          r.score.a.royalties + r.score.b.royalties);
      expect(r.a.board.isComplete && r.b.board.isComplete, isTrue);
    });

    test('a Fantasy player waits while the other plays out', () {
      final m = HeadsUpMatch(seed: 5, fantasyA: const FantasyState.active(14));
      expect(m.current, Player.b);
      expect(m.hand(Player.a).tray, hasLength(14));
      autoPlayTurns(m, Player.b);
      expect(m.hand(Player.b).isCommitted, isTrue);
      expect(m.current, Player.a);
    });

    test('nextMatch carries both Fantasy states', () {
      final m = HeadsUpMatch(seed: 5);
      while (!m.isOver) {
        autoPlay(m.currentHand);
        m.advance();
      }
      final next = m.nextMatch();
      expect(next.fantasy(Player.a), m.result!.a.nextFantasy);
      expect(next.fantasy(Player.b), m.result!.b.nextFantasy);
    });
  });
}

/// Advances [m] while [p] is to act, playing bottom-up.
void autoPlayTurns(HeadsUpMatch m, Player p) {
  while (m.current == p && !m.isOver && !m.hand(p).isCommitted) {
    final h = m.currentHand;
    final limit = h.history.whereType<DrawAction>().length == 1 ? 5 : 2;
    final free = [BoardRow.bottom, BoardRow.middle, BoardRow.top];
    for (var i = 0; i < limit && !h.isComplete; i++) {
      h.place(
          h.tray.first, free.firstWhere((r) => h.row(r).length < r.capacity));
    }
    m.advance();
  }
}
