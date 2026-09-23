import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ofc_app/game_screen.dart';
import 'package:ofc_app/result_screen.dart';
import 'package:ofc_app_core/core/models/playing_card.dart';
import 'package:ofc_app_core/features/game/domain/board.dart';
import 'package:ofc_app_core/features/game/domain/foul_checker.dart';
import 'package:ofc_app_core/features/game/domain/game_options.dart';
import 'package:ofc_app_core/features/game/domain/ruleset.dart';

/// Plays complete hands through the real screens.
///
/// The deterministic verification layer (vlmkit) cannot drag, so nothing outside this file ever
/// reaches the result screen. Here a seeded deal is placed by dragging cards out of the tray onto
/// the row drop targets, the hand is drawn to the end, and the result screen is read back and
/// compared against the domain engine. Seeds are fixed, so every case is reproducible.
///
/// What is checked on the result screen:
///   * the FOUL / OK verdict equals `FoulChecker.isFoul` for the board the screen itself holds
///   * the royalty cells and the total match `Ruleset` for that board, and read '-' / '0' on a foul
///   * every row shows a category name from the vocabulary, with ' (Wild)' when a wild was used
void main() {
  for (final mode in _modes.entries) {
    testWidgets('${mode.key} wild: played hands reach the result screen', (tester) async {
      final verdicts = <String, String>{};
      final categories = <String>[];
      for (final policy in {'strongest': _strongestFirst, 'weakest': _weakestFirst}.entries) {
        for (final seed in const [7, 11, 23, 31]) {
          final r = await playHand(tester, seed: seed, options: mode.value, policy: policy.value);
          final label = '${policy.key}/$seed';
          verdicts[label] = r.verdict;
          categories.addAll(r.rows);
          debugPrint('OBSERVE ${mode.key} $label verdict=${r.verdict} '
              'top=${r.top} middle=${r.middle} bottom=${r.bottom} total=${r.total}');
          for (final c in r.rows) {
            expect(c, _matchesCategory, reason: 'row category "$c" is not in the vocabulary');
          }
        }
      }
      // Both outcomes are reachable, and the screen tells them apart.
      expect(verdicts.values.toSet(), {'OK', 'FOUL'}, reason: 'verdicts seen: $verdicts');
      // At least one hand got past high cards.
      expect(categories.any(_isMadeHand), isTrue, reason: 'categories seen: $categories');
    });
  }
}

/// 'Pair' / 'Trips' / 'One Pair' and above: a hand that actually made something.
bool _isMadeHand(String category) => const {
      'Pair', 'Trips', 'One Pair', 'Two Pair', 'Three of a Kind', 'Straight', 'Flush',
      'Full House', 'Four of a Kind', 'Straight Flush', 'Royal Flush',
    }.contains(category.replaceAll(' (Wild)', ''));

const _modes = {
  'standard': GameOptions.standard,
  'deuces': GameOptions.deucesWild,
  'joker': GameOptions.jokerWild,
};

/// Categories the result screen may print, per row length. A wild adds ' (Wild)'.
const _vocabulary = {
  'High', 'Pair', 'Trips', // three-card row
  'High Card', 'One Pair', 'Two Pair', 'Three of a Kind', 'Straight', 'Flush',
  'Full House', 'Four of a Kind', 'Straight Flush', 'Royal Flush', // five-card row
};

final _matchesCategory = predicate<String>((s) => _vocabulary.contains(s.replaceAll(' (Wild)', '')));

class Result {
  final String verdict;
  final String top;
  final String middle;
  final String bottom;
  final String total;
  final List<String> rows;
  Result(this.verdict, this.top, this.middle, this.bottom, this.total, this.rows);
}

typedef Policy = PlayingCard Function(List<PlayingCard> tray, List<PlayingCard> row);

/// Plays one hand to the result screen and reads it back.
Future<Result> playHand(
  WidgetTester tester, {
  required int seed,
  required GameOptions options,
  required Policy policy,
}) async {
  tester.view.physicalSize = const Size(1080, 2400); // the default 800x600 view clips the board
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  // A unique key on the MaterialApp: without it the previous hand's Navigator (which still has the
  // result screen pushed on it) is reused, and the new hand never appears.
  await tester.pumpWidget(
      MaterialApp(key: UniqueKey(), home: GameScreen(seed: seed, options: options)));
  await tester.pumpAndSettle();
  expect(find.textContaining('Tray (5)'), findsOneWidget, reason: 'the deal did not appear');

  final board = <String, List<PlayingCard>>{'Bottom': [], 'Middle': [], 'Top': []};
  const capacity = {'Top': 3, 'Middle': 5, 'Bottom': 5};

  for (var cycle = 0; cycle < 8 && !_onResultScreen(); cycle++) {
    // A deal of five is placed whole; each later draw of three places two and discards the third,
    // which is the rule the drop target itself enforces.
    final limit = _trayCards(tester).length >= 5 ? 5 : 2;
    for (var i = 0; i < limit; i++) {
      final row = ['Bottom', 'Middle', 'Top'].firstWhere((r) => board[r]!.length < capacity[r]!);
      final tray = _trayCards(tester);
      if (tray.isEmpty) break;
      final card = policy(tray, board[row]!);
      await _dragTrayCardTo(tester, row, card);
      board[row]!.add(card);
    }
    if (_onResultScreen()) break;
    final advance =
        find.text('Next 3').evaluate().isNotEmpty ? find.text('Next 3') : find.text('Commit');
    expect(advance, findsWidgets, reason: 'no way to advance the hand');
    await tester.tap(advance.first);
    await tester.pumpAndSettle();
  }

  expect(_onResultScreen(), isTrue, reason: 'the hand never reached the result screen');
  expect(board['Top']!.length, 3);
  expect(board['Middle']!.length, 5);
  expect(board['Bottom']!.length, 5, reason: 'a hand is 13 cards');

  final screen = tester.widget<ResultScreen>(find.byType(ResultScreen));
  final eval = BoardEval.from(screen.board, wildMode: screen.wildMode);
  final fouled = FoulChecker.isFoul(eval);
  final texts = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .whereType<String>()
      .toList(growable: false);

  // The verdict the reader sees must be the engine's verdict for the board the screen holds.
  expect(texts.where((t) => t == 'FOUL' || t == 'OK').toList(), [fouled ? 'FOUL' : 'OK']);

  final rows = [
    texts[texts.indexOf('Top') + 1],
    texts[texts.indexOf('Middle') + 1],
    texts[texts.indexOf('Bottom') + 1],
  ];

  // The royalty cells and the total come from the ruleset, and are blanked on a foul.
  final ruleset = Ruleset.defaultRules;
  final royalties = [
    ruleset.royaltyTop(eval.top),
    ruleset.royaltyMiddle(eval.middle),
    ruleset.royaltyBottom(eval.bottom),
  ];
  for (final r in royalties) {
    expect(texts.contains(fouled ? '-' : '+$r'), isTrue,
        reason: 'royalty $r not rendered (fouled=$fouled)');
  }
  final total = fouled ? '0' : '+${royalties.reduce((a, b) => a + b)}';
  expect(texts.contains(total), isTrue, reason: 'total $total not rendered');

  return Result(
    fouled ? 'FOUL' : 'OK',
    rows[0],
    rows[1],
    rows[2],
    total,
    rows,
  );
}

/// Fills the rows with the cards that group best, so the bottom ends up as a real made hand.
PlayingCard _strongestFirst(List<PlayingCard> tray, List<PlayingCard> row) =>
    _bestBy(tray, row, strongest: true);

/// The opposite: the best cards go to the top, which is how a foul is produced on purpose.
PlayingCard _weakestFirst(List<PlayingCard> tray, List<PlayingCard> row) =>
    _bestBy(tray, row, strongest: false);

PlayingCard _bestBy(List<PlayingCard> tray, List<PlayingCard> row, {required bool strongest}) {
  int groupScore(PlayingCard c) {
    final all = [...row, c];
    final ranks = all.where((x) => !x.isJoker).map((x) => x.rank!.value).toList();
    final suits = all.where((x) => !x.isJoker).map((x) => x.suit!.name).toList();
    int peak(List<Object> xs) =>
        xs.isEmpty ? 0 : xs.map((x) => xs.where((y) => y == x).length).reduce((a, b) => a > b ? a : b);
    final wild = all.where((x) => x.isJoker).length;
    return peak(ranks) * 100 + peak(suits) * 10 + wild * 5 + (c.isJoker ? 0 : c.rank!.value);
  }

  final ranked = [...tray]..sort((a, b) => groupScore(b).compareTo(groupScore(a)));
  return strongest ? ranked.first : ranked.last;
}

bool _onResultScreen() => find.textContaining('Action Log').evaluate().isNotEmpty;

List<PlayingCard> _trayCards(WidgetTester tester) => tester
    .widgetList<Draggable<PlayingCard>>(
        find.descendant(of: _trayTarget(), matching: find.byType(Draggable<PlayingCard>)))
    .map((d) => d.data)
    .whereType<PlayingCard>()
    .toList(growable: false);

Finder _trayTarget() => find.ancestor(
      of: find.textContaining('Tray ('),
      matching: find.byType(DragTarget<PlayingCard>),
    );

Finder _rowTarget(String row) =>
    find.ancestor(of: find.textContaining('$row ('), matching: find.byType(DragTarget<PlayingCard>));

Future<void> _dragTrayCardTo(WidgetTester tester, String row, PlayingCard card) async {
  final draggables =
      find.descendant(of: _trayTarget(), matching: find.byType(Draggable<PlayingCard>));
  final index = tester
      .widgetList<Draggable<PlayingCard>>(draggables)
      .toList()
      .indexWhere((d) => identical(d.data, card));
  expect(index, isNonNegative, reason: 'the chosen card $card is not in the tray');

  final from = tester.getCenter(draggables.at(index));
  final to = tester.getCenter(_rowTarget(row));
  final gesture = await tester.startGesture(from);
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.moveTo(to);
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.up();
  await tester.pumpAndSettle();
}
