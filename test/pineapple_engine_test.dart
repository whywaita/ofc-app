import 'package:test/test.dart';
import 'package:ofc_app_core/core/models/deck.dart';
import 'package:ofc_app_core/features/game/domain/pineapple_engine.dart';
import 'package:ofc_app_core/features/game/domain/board.dart';
import 'package:ofc_app_core/features/game/domain/fantasy_engine.dart';
import 'helpers.dart';

void main() {
  test('initial draw 5 then cycles of 3 with 2 place + 1 discard', () {
    final deck = Deck.fromCodes([
      // 初手5
      'As', 'Ks', 'Qs', 'Js', 'Ts',
      // 次の3
      '2h', '3h', '4h',
    ]);
    final eng = PineappleEngine(deck);
    eng.startHand();
    expect(eng.tray.length, 5);
    // 初手は5枚配置可能（ここではトップ3, ミドル2に置く）
    eng.place(Slot.top, c('As'));
    eng.place(Slot.top, c('Ks'));
    eng.place(Slot.top, c('Qs'));
    eng.place(Slot.middle, c('Js'));
    eng.place(Slot.middle, c('Ts'));
    expect(eng.tray, isEmpty);
    // 次サイクルへ
    expect(eng.needsCycle, isTrue);
    eng.nextCycle();
    expect(eng.tray.length, 3);
    // 2枚配置 + 1枚捨て
    eng.place(Slot.bottom, c('2h'));
    eng.place(Slot.bottom, c('3h'));
    eng.discard(c('4h'));
    expect(eng.tray, isEmpty);
  });

  test('Fantasy entry count mapping (board eval only)', () {
    // トップQQ → 14
    final board = Board(
      top: [c('Qh'), c('Qs'), c('2c')],
      middle: [c('3d'), c('4s'), c('5c'), c('7d'), c('9h')],
      bottom: [c('Ah'), c('Kd'), c('7s'), c('6c'), c('2d')],
    );
    expect(FantasyEngine.entryCount(BoardEval.from(board)), 14);
  });

  group('sortTray', () {
    test('sorts tray cards using provided comparator', () {
      final deck = Deck.fromCodes(['2h', 'As', '5d', 'Ks', '9c']);
      final eng = PineappleEngine(deck);
      eng.startHand();

      // Sort by rank descending
      eng.sortTray((a, b) => b.rank.value.compareTo(a.rank.value));

      final trayList = eng.tray.toList();
      expect(trayList[0], c('As')); // 14
      expect(trayList[1], c('Ks')); // 13
      expect(trayList[2], c('9c')); // 9
      expect(trayList[3], c('5d')); // 5
      expect(trayList[4], c('2h')); // 2
    });

    test('sorts tray by suit', () {
      final deck = Deck.fromCodes(['2s', '2h', '2d', '2c', '3s']);
      final eng = PineappleEngine(deck);
      eng.startHand();

      // Sort by suit name alphabetically
      eng.sortTray((a, b) => a.suit.name.compareTo(b.suit.name));

      final trayList = eng.tray.toList();
      expect(trayList[0].suit.name, 'clubs');
      expect(trayList[1].suit.name, 'diamonds');
      expect(trayList[2].suit.name, 'hearts');
      // Two spades: 2s and 3s
      expect(trayList[3].suit.name, 'spades');
      expect(trayList[4].suit.name, 'spades');
    });
  });

  group('returnToTray', () {
    test('moves card from top back to tray', () {
      final deck = Deck.fromCodes(['As', 'Ks', 'Qs', 'Js', 'Ts']);
      final eng = PineappleEngine(deck);
      eng.startHand();

      eng.place(Slot.top, c('As'));
      expect(eng.builder.top.length, 1);
      expect(eng.tray.length, 4);

      eng.returnToTray(c('As'));
      expect(eng.builder.top, isEmpty);
      expect(eng.tray.length, 5);
      expect(eng.tray, contains(c('As')));
    });

    test('moves card from middle back to tray', () {
      final deck = Deck.fromCodes(['As', 'Ks', 'Qs', 'Js', 'Ts']);
      final eng = PineappleEngine(deck);
      eng.startHand();

      eng.place(Slot.middle, c('As'));
      eng.place(Slot.middle, c('Ks'));
      expect(eng.builder.middle.length, 2);
      expect(eng.tray.length, 3);

      eng.returnToTray(c('Ks'));
      expect(eng.builder.middle.length, 1);
      expect(eng.tray.length, 4);
      expect(eng.tray, contains(c('Ks')));
    });

    test('moves card from bottom back to tray', () {
      final deck = Deck.fromCodes(['As', 'Ks', 'Qs', 'Js', 'Ts']);
      final eng = PineappleEngine(deck);
      eng.startHand();

      eng.place(Slot.bottom, c('As'));
      expect(eng.builder.bottom.length, 1);
      expect(eng.tray.length, 4);

      eng.returnToTray(c('As'));
      expect(eng.builder.bottom, isEmpty);
      expect(eng.tray.length, 5);
      expect(eng.tray, contains(c('As')));
    });

    test('does nothing if card not on board', () {
      final deck = Deck.fromCodes(['As', 'Ks', 'Qs', 'Js', 'Ts']);
      final eng = PineappleEngine(deck);
      eng.startHand();

      eng.place(Slot.top, c('As'));
      expect(eng.tray.length, 4);

      // Try to return a card that's still in tray
      eng.returnToTray(c('Ks'));
      expect(eng.tray.length, 4); // No change
    });

    test('throws when not in placing phase', () {
      final deck = Deck.fromCodes(['As', 'Ks', 'Qs', 'Js', 'Ts']);
      final eng = PineappleEngine(deck);
      // Don't start hand - still in drawing phase
      expect(() => eng.returnToTray(c('As')), throwsStateError);
    });
  });

  group('immutability', () {
    test('history getter returns unmodifiable view', () {
      final deck = Deck.fromCodes(['As', 'Ks', 'Qs', 'Js', 'Ts']);
      final eng = PineappleEngine(deck);
      eng.startHand();

      final historyView = eng.history;
      expect(() => historyView.add(ActionLogEntry('test', {})),
          throwsUnsupportedError);
    });

    test('tray getter returns unmodifiable view', () {
      final deck = Deck.fromCodes(['As', 'Ks', 'Qs', 'Js', 'Ts']);
      final eng = PineappleEngine(deck);
      eng.startHand();

      final trayView = eng.tray;
      expect(() => trayView.add(c('2h')), throwsUnsupportedError);
    });

    test('discards getter returns unmodifiable view', () {
      final deck = Deck.fromCodes(['As', 'Ks', 'Qs', 'Js', 'Ts', '2h', '3h', '4h']);
      final eng = PineappleEngine(deck);
      eng.startHand();

      eng.place(Slot.top, c('As'));
      eng.place(Slot.top, c('Ks'));
      eng.place(Slot.top, c('Qs'));
      eng.place(Slot.middle, c('Js'));
      eng.place(Slot.middle, c('Ts'));
      eng.nextCycle();
      eng.discard(c('2h'));

      final discardsView = eng.discards;
      expect(() => discardsView.add(c('3h')), throwsUnsupportedError);
    });
  });
}
