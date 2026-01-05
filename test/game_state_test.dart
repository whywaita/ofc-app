import 'package:test/test.dart';
import 'package:ofc_app_core/core/models/deck.dart';
import 'package:ofc_app_core/features/game/domain/game_state.dart';
import 'package:ofc_app_core/features/game/domain/fantasy_engine.dart';
import 'package:ofc_app_core/features/game/domain/board.dart';
import 'package:ofc_app_core/features/game/domain/pineapple_engine.dart';
import 'helpers.dart';

void main() {
  test('startHand respects FantasyState initial counts', () {
    // A: Fantasy14、B: 通常5
    final deck = Deck.fromCodes([
      // A 初手14
      'As', 'Ks', 'Qs', 'Js', 'Ts', '9s', '8s', '7s', '6s', '5s', '4s', '3s',
      '2s', 'Ah',
      // B 初手5
      'Kh', 'Qh', 'Jh', 'Th', '9h',
    ]);
    final gs = GameState(
        deck: deck,
        fantasyA: const FantasyState.active(14),
        fantasyB: const FantasyState.inactive());
    gs.startHand();
    expect(gs.aEngine.tray.length, 14);
    expect(gs.bEngine.tray.length, 5);
  });

  test(
      'commitWithBoards updates FantasyState and preserves initialCount on continue',
      () {
    final gs = GameState(fantasyA: const FantasyState.active(15));
    // A は継続条件（下段Four）を満たす → initialCount=15を維持
    final a = Board(
      top: [c('2h'), c('3h'), c('4h')], // High
      middle: [c('2d'), c('6d'), c('8d'), c('9d'), c('Td')], // Flush
      bottom: [c('9s'), c('9d'), c('9c'), c('9h'), c('2s')], // Four of a kind
    );
    // B は継続/突入なし
    final b = Board(
      top: [c('Ah'), c('Kd'), c('2c')],
      middle: [c('3d'), c('4s'), c('5c'), c('7d'), c('9h')],
      bottom: [c('2d'), c('3c'), c('4d'), c('6s'), c('9c')],
    );
    gs.commitWithBoards(a, b);
    expect(gs.fantasyA.active, isTrue);
    expect(gs.fantasyA.initialCount, 15);
    expect(gs.fantasyB.active, isFalse);
  });

  group('deal', () {
    test('deals cards to player A', () {
      final deck = Deck.fromCodes([
        'As', 'Ks', 'Qs', 'Js', 'Ts', // A's cards
        '2h', '3h', '4h', '5h', '6h', // B's cards (not dealt yet)
      ]);
      final gs = GameState(deck: deck);
      gs.deal(Player.a);

      expect(gs.aEngine.tray.length, 5);
      expect(gs.aEngine.phase, Phase.placing);
      expect(gs.bEngine.phase, Phase.drawing); // B hasn't been dealt yet
    });

    test('deals cards to player B', () {
      final deck = Deck.fromCodes([
        'As', 'Ks', 'Qs', 'Js', 'Ts', // A's cards
        '2h', '3h', '4h', '5h', '6h', // B's cards
      ]);
      final gs = GameState(deck: deck);
      gs.deal(Player.a);
      gs.deal(Player.b);

      expect(gs.bEngine.tray.length, 5);
      expect(gs.bEngine.phase, Phase.placing);
    });

    test('respects fantasy initial count for player A', () {
      final deck = Deck.fromCodes([
        'As', 'Ks', 'Qs', 'Js', 'Ts', '9s', '8s', '7s', '6s', '5s', '4s', '3s',
        '2s', 'Ah', // 14 cards for fantasy
      ]);
      final gs = GameState(deck: deck, fantasyA: const FantasyState.active(14));
      gs.deal(Player.a);

      expect(gs.aEngine.tray.length, 14);
      expect(gs.aEngine.initialDrawCount, 14);
    });
  });

  group('place and nextCycle', () {
    test('place adds card to board through engine', () {
      final deck = Deck.fromCodes([
        'As',
        'Ks',
        'Qs',
        'Js',
        'Ts',
      ]);
      final gs = GameState(deck: deck);
      gs.deal(Player.a);

      gs.place(Player.a, Slot.top, c('As'));
      expect(gs.aEngine.builder.top.length, 1);
      expect(gs.aEngine.tray.length, 4);
    });

    test('nextCycle draws 3 more cards', () {
      final deck = Deck.fromCodes([
        'As', 'Ks', 'Qs', 'Js', 'Ts', // Initial 5
        '2h', '3h', '4h', // Next 3
      ]);
      final gs = GameState(deck: deck);
      gs.deal(Player.a);

      // Place all 5 cards
      gs.place(Player.a, Slot.top, c('As'));
      gs.place(Player.a, Slot.top, c('Ks'));
      gs.place(Player.a, Slot.top, c('Qs'));
      gs.place(Player.a, Slot.middle, c('Js'));
      gs.place(Player.a, Slot.middle, c('Ts'));

      expect(gs.aEngine.needsCycle, isTrue);
      gs.nextCycle(Player.a);

      expect(gs.aEngine.tray.length, 3);
    });
  });

  group('finalize', () {
    test('finalizes player board and stores it', () {
      final deck = Deck.fromCodes([
        // 15 cards total for complete board (3 top + 5 middle + 5 bottom + 2 discarded)
        'As', 'Ks', 'Qs', 'Js', 'Ts', // Initial 5
        '9s', '8s', '7s', // Cycle 1
        '6s', '5s', '4s', // Cycle 2
        '3s', '2s', 'Ah', // Cycle 3
        'Kh', 'Qh', 'Jh', // Cycle 4
      ]);
      final gs = GameState(deck: deck);
      gs.deal(Player.a);

      // Place initial 5
      gs.place(Player.a, Slot.top, c('As'));
      gs.place(Player.a, Slot.top, c('Ks'));
      gs.place(Player.a, Slot.top, c('Qs'));
      gs.place(Player.a, Slot.middle, c('Js'));
      gs.place(Player.a, Slot.middle, c('Ts'));

      // Cycle 1
      gs.nextCycle(Player.a);
      gs.place(Player.a, Slot.middle, c('9s'));
      gs.place(Player.a, Slot.middle, c('8s'));
      gs.aEngine.discard(c('7s'));

      // Cycle 2
      gs.nextCycle(Player.a);
      gs.place(Player.a, Slot.middle, c('6s'));
      gs.place(Player.a, Slot.bottom, c('5s'));
      gs.aEngine.discard(c('4s'));

      // Cycle 3
      gs.nextCycle(Player.a);
      gs.place(Player.a, Slot.bottom, c('3s'));
      gs.place(Player.a, Slot.bottom, c('2s'));
      gs.aEngine.discard(c('Ah'));

      // Cycle 4
      gs.nextCycle(Player.a);
      gs.place(Player.a, Slot.bottom, c('Kh'));
      gs.place(Player.a, Slot.bottom, c('Qh'));
      gs.aEngine.discard(c('Jh'));

      // Now board should be complete
      expect(gs.aEngine.builder.isComplete, isTrue);
      gs.finalize(Player.a);

      expect(gs.boardA, isNotNull);
      expect(gs.boardA!.top.length, 3);
      expect(gs.boardA!.middle.length, 5);
      expect(gs.boardA!.bottom.length, 5);
    });

    test('throws if board not complete', () {
      final deck = Deck.fromCodes(['As', 'Ks', 'Qs', 'Js', 'Ts']);
      final gs = GameState(deck: deck);
      gs.deal(Player.a);

      gs.place(Player.a, Slot.top, c('As'));
      // Board is not complete
      expect(() => gs.finalize(Player.a), throwsStateError);
    });
  });

  group('startHand', () {
    test('starts new hand for both players', () {
      final deck = Deck.fromCodes([
        'As', 'Ks', 'Qs', 'Js', 'Ts', // A's cards
        '2h', '3h', '4h', '5h', '6h', // B's cards
      ]);
      final gs = GameState(deck: deck);
      gs.startHand();

      expect(gs.aEngine.tray.length, 5);
      expect(gs.bEngine.tray.length, 5);
      expect(gs.aEngine.phase, Phase.placing);
      expect(gs.bEngine.phase, Phase.placing);
    });

    test('respects fantasy states when starting hand', () {
      final deck = Deck.fromCodes([
        // A gets 14 cards (fantasy)
        'As', 'Ks', 'Qs', 'Js', 'Ts', '9s', '8s', '7s', '6s', '5s', '4s', '3s',
        '2s', 'Ah',
        // B gets 5 cards (normal)
        '2h', '3h', '4h', '5h', '6h',
      ]);
      final gs = GameState(
          deck: deck,
          fantasyA: const FantasyState.active(14),
          fantasyB: const FantasyState.inactive());
      gs.startHand();

      expect(gs.aEngine.tray.length, 14);
      expect(gs.bEngine.tray.length, 5);
    });
  });
}
