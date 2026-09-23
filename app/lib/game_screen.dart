import 'package:flutter/material.dart';
import 'package:ofc_app_core/core/models/deck.dart';
import 'package:ofc_app_core/core/models/playing_card.dart';
import 'package:ofc_app_core/features/game/domain/board.dart';
import 'package:ofc_app_core/features/game/domain/cycle_logic.dart';
import 'package:ofc_app_core/features/game/domain/fantasy_engine.dart';
import 'package:ofc_app_core/features/game/domain/game_options.dart';
import 'package:ofc_app_core/features/game/domain/pineapple_engine.dart';
import 'package:ofc_app_core/features/game/domain/ruleset.dart';
import 'result_screen.dart';
import 'utils/navigation_utils.dart';
import 'widgets/card_widget.dart';

class GameScreen extends StatefulWidget {
  final int seed;
  final GameOptions options;
  const GameScreen({
    super.key,
    required this.seed,
    this.options = const GameOptions(),
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  PineappleEngine? _eng;
  String _status = 'Ready';
  FantasyState _fantasy = const FantasyState.inactive();
  final Ruleset _ruleset = Ruleset.defaultRules;
  Set<String> _movableIds = const {};

  /// A card picked up by tapping, waiting for a row to be tapped. The drag path does not use it.
  PlayingCard? _selected;

  /// Why the last attempt was refused, shown to the reader. Cleared by any successful action.
  String? _hint;

  @override
  void initState() {
    super.initState();
    // Automatically deal cards when the screen is displayed
    WidgetsBinding.instance.addPostFrameCallback((_) => _deal());
  }

  void _deal() {
    setState(() {
      final deck = widget.options.isJokerWild
          ? Deck.withJokers(seed: widget.seed, jokerCount: 2)
          : Deck.standard(seed: widget.seed);
      _eng = PineappleEngine(deck)
        ..startHand(
            fantasyInitialCount: _fantasy.active ? _fantasy.initialCount : 0);
      _status = 'Dealt ${_fantasy.active ? _fantasy.initialCount : 5}';
      _selected = null;
      _hint = null;
    });
  }

  Widget _cardWidget(PlayingCard c,
      {bool large = false, Color? borderColor, bool isSmallScreen = false}) {
    return CardWidget(
      card: c,
      large: large,
      borderColor: borderColor,
      isSmallScreen: isSmallScreen,
    );
  }

  Set<String> _currentCycleIds() {
    final eng = _eng;
    if (eng == null) return const {};
    for (var i = eng.history.length - 1; i >= 0; i--) {
      final e = eng.history[i];
      if (e.type == 'draw') {
        final list = (e.data['cards'] as List).cast<String>();
        return list.toSet();
      }
    }
    return const {};
  }

  void _sortTray() {
    final eng = _eng;
    if (eng == null) return;
    setState(() {
      eng.sortTray((a, b) {
        // Handle jokers: put them at the end
        if (a.isJoker && b.isJoker) return 0;
        if (a.isJoker) return 1; // a goes after b
        if (b.isJoker) return -1; // b goes after a

        final rv = b.rank!.value.compareTo(a.rank!.value); // 高いランク優先
        if (rv != 0) return rv;
        int suitOrder(String s) => switch (s) {
              'spades' => 3,
              'hearts' => 2,
              'diamonds' => 1,
              _ => 0, // clubs
            };
        return suitOrder(b.suit!.name) - suitOrder(a.suit!.name);
      });
      _status = 'Sorted';
    });
  }

  int _lastDrawCount() => CycleLogic.lastDrawCount(_eng!.history);
  int _placedCountForCycle(Set<String> ids) =>
      CycleLogic.placedCountForCycle(_eng!.builder, ids);
  // kept for clarity but unused after unifying auto-discard via CycleLogic
  // List<PlayingCard> _trayCardsForCycle(Set<String> ids) => CycleLogic.trayCardsForCycle(_eng!.tray, ids);

  /// Why a card cannot go into a row right now, or null when it can. Shared by the drag path and
  /// the tap path so both enforce the same rules.
  String? _placementBlock(PlayingCard card,
      {required List<PlayingCard> current, required int max}) {
    final eng = _eng;
    if (eng == null || eng.phase != Phase.placing) {
      return 'Nothing to place now';
    }
    if (current.length >= max) return 'Row is full ($max max)';
    final ids = _currentCycleIds();
    final fromTray = eng.tray.contains(card);
    if (fromTray && _lastDrawCount() == 3 && _placedCountForCycle(ids) >= 2) {
      return 'Two cards per draw';
    }
    if (!fromTray && !ids.contains(card.toString())) {
      return 'That card is locked in';
    }
    return null;
  }

  /// Puts a card from the tray on the board, or moves one from a row to another row.
  void _acceptPlacement(Slot slot, PlayingCard card) {
    final eng = _eng!;
    if (eng.tray.contains(card)) {
      eng.place(slot, card);
    } else {
      if (!eng.builder.remove(card)) {
        throw StateError('Card not found on board: $card');
      }
      switch (slot) {
        case Slot.top:
          eng.builder.placeTop(card);
          break;
        case Slot.middle:
          eng.builder.placeMiddle(card);
          break;
        case Slot.bottom:
          eng.builder.placeBottom(card);
          break;
      }
    }
    _status = 'Placed';
    _selected = null;
    _hint = null;
  }

  void _tapRow(Slot slot, List<PlayingCard> current, int max) {
    final card = _selected;
    if (card == null) return;
    setState(() {
      final block = _placementBlock(card, current: current, max: max);
      if (block != null) {
        _hint = block;
        return;
      }
      _acceptPlacement(slot, card);
    });
  }

  bool _canReturnToTray(PlayingCard c) {
    final eng = _eng;
    if (eng == null || eng.phase != Phase.placing) return false;
    return !eng.tray.contains(c) && _currentCycleIds().contains(c.toString());
  }

  void _tapTray() {
    final card = _selected;
    if (card == null) return;
    setState(() {
      if (!_canReturnToTray(card)) {
        _hint = 'That card cannot come back';
        return;
      }
      _eng!.returnToTray(card);
      _status = 'Back to Tray';
      _selected = null;
      _hint = null;
    });
  }

  void _select(PlayingCard c) => setState(() {
        _selected = _selected == c ? null : c;
        _hint = null;
      });

  String _placeLabel(String title, int max) => 'Place in $title ($max max)';

  String _cardLabel(PlayingCard c) =>
      c.isJoker ? 'Joker' : '${CardRenderer.rankSymbol(c)} of ${c.suit!.name}';

  /// A card on the board: draggable when it belongs to the current draw, and always tappable, so a
  /// card can be picked up without dragging. The tap path is what a click-only driver can use.
  Widget _boardCard(PlayingCard c, {required bool isSmallScreen}) {
    final movable = _movableIds.contains(c.toString());
    final selected = _selected == c;
    final border = selected
        ? Colors.orange.shade800
        : movable
            ? Colors.teal
            : Colors.grey.shade500;
    final card =
        _cardWidget(c, borderColor: border, isSmallScreen: isSmallScreen);
    // Semantics outside the GestureDetector, with the glyph excluded: the label survives and the
    // tap action lands on the same node, which is what a screen reader and a click-only driver each
    // need. A label on a node whose child also carries text is otherwise discarded.
    final tappable = Semantics(
      container: true,
      button: true,
      selected: selected,
      label: _cardLabel(c),
      child: GestureDetector(
        onTap: () => _select(c),
        child: ExcludeSemantics(child: card),
      ),
    );
    if (!movable) return tappable;
    return Draggable<PlayingCard>(
      data: c,
      feedback: Material(
          color: Colors.transparent,
          child: _cardWidget(c,
              large: true, borderColor: border, isSmallScreen: isSmallScreen)),
      childWhenDragging: Opacity(opacity: 0.3, child: card),
      child: tappable,
    );
  }

  Widget _trayCard(PlayingCard c, {required bool isSmallScreen}) {
    final selected = _selected == c;
    return Draggable<PlayingCard>(
      data: c,
      feedback: Material(
          color: Colors.transparent,
          child: _cardWidget(c, large: true, isSmallScreen: isSmallScreen)),
      childWhenDragging: Opacity(
          opacity: 0.3, child: _cardWidget(c, isSmallScreen: isSmallScreen)),
      child: Semantics(
        container: true,
        button: true,
        selected: selected,
        label: _cardLabel(c),
        child: GestureDetector(
          onTap: () => _select(c),
          child: ExcludeSemantics(
            child: _cardWidget(c,
                borderColor: selected ? Colors.orange.shade800 : null,
                isSmallScreen: isSmallScreen),
          ),
        ),
      ),
    );
  }

  Widget _dropZone(
      {required String title,
      required List<PlayingCard> current,
      required int max,
      required Slot slot}) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return DragTarget<PlayingCard>(
      onWillAcceptWithDetails: (details) =>
          _placementBlock(details.data, current: current, max: max) == null,
      onAcceptWithDetails: (details) =>
          setState(() => _acceptPlacement(slot, details.data)),
      builder: (context, candidate, rejected) {
        // A refused drag is shown, not swallowed: previously the drop simply did nothing at all.
        final accepted = candidate.isNotEmpty;
        final refused = rejected.isNotEmpty;
        PlayingCard? refusedCard;
        for (final r in rejected) {
          if (r is PlayingCard) {
            refusedCard = r;
            break;
          }
        }
        final refuseReason = refusedCard == null
            ? null
            : _placementBlock(refusedCard, current: current, max: max);
        return GestureDetector(
          onTap: () => _tapRow(slot, current, max),
          child: Container(
            padding: EdgeInsets.all(isSmallScreen ? 6 : 10),
            decoration: BoxDecoration(
              border: Border.all(
                  color: accepted
                      ? Colors.teal
                      : refused
                          ? Colors.red.shade900
                          : Colors.grey.shade400),
              borderRadius: BorderRadius.circular(isSmallScreen ? 6 : 10),
              color: accepted
                  ? Colors.teal.withValues(alpha: 0.06)
                  : refused
                      ? Colors.red.withValues(alpha: 0.06)
                      : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The row label doubles as the explicit place action. Tapping a row works, but
                // once a row holds cards a tap can land on one of them instead (which picks that
                // card up), and a full row leaves nowhere else to tap; this names the action and
                // keeps it in the label, away from the cards.
                Semantics(
                  container: true,
                  button: true,
                  label: _placeLabel(title, max),
                  child: GestureDetector(
                    onTap: () => _tapRow(slot, current, max),
                    child: ExcludeSemantics(
                      child: Text(
                        '$title ($max max)',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  alignment: WrapAlignment.start,
                  spacing: isSmallScreen ? 4 : 6,
                  runSpacing: isSmallScreen ? 4 : 6,
                  children: [
                    for (final c in current)
                      _boardCard(c, isSmallScreen: isSmallScreen),
                  ],
                ),
                if (refuseReason != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      refuseReason,
                      style: TextStyle(
                          fontSize: isSmallScreen ? 11 : 12,
                          color: Colors.red.shade900),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _modeTitle() {
    if (widget.options.isDeucesWild) return 'Practice (Deuces Wild)';
    if (widget.options.isJokerWild) return 'Practice (Joker Wild)';
    return 'Practice';
  }

  Future<void> _handleBackPress() async {
    final navigator = Navigator.of(context);
    final shouldPop = await showDiscardConfirmationDialog(context);
    if (shouldPop && context.mounted) {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final eng = _eng;
    final tray = eng?.tray ?? const <PlayingCard>[];
    final top = eng?.builder.top ?? const <PlayingCard>[];
    final middle = eng?.builder.middle ?? const <PlayingCard>[];
    final bottom = eng?.builder.bottom ?? const <PlayingCard>[];
    // Next 3 可否: 初手5は5枚配置、以降は2枚配置
    final canNext = eng != null && CycleLogic.canNext(eng);
    // Commit check is not used here as it is directly checked by the main button below
    _movableIds = _currentCycleIds();

    // Responsive design for mobile devices
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return PopScope(
      canPop: !(_eng != null && _eng!.phase == Phase.placing),
      onPopInvokedWithResult: (bool didPop, _) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_modeTitle()),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 8 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Text('Status: $_status'),
                if (_hint != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _hint!,
                      style: TextStyle(color: Colors.red.shade900),
                    ),
                  ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  // Plain Text: a web SelectableText is a disabled <textarea> with an empty
                  // value, which hides the seed from assistive technology.
                  child: Text('Seed: ${widget.seed}',
                      style: TextStyle(color: Colors.grey.shade700)),
                ),
                const SizedBox(height: 8),
                const Divider(),
                _dropZone(title: 'Top', current: top, max: 3, slot: Slot.top),
                SizedBox(height: isSmallScreen ? 4 : 8),
                _dropZone(
                    title: 'Middle',
                    current: middle,
                    max: 5,
                    slot: Slot.middle),
                SizedBox(height: isSmallScreen ? 4 : 8),
                _dropZone(
                    title: 'Bottom',
                    current: bottom,
                    max: 5,
                    slot: Slot.bottom),
                const Divider(),
                DragTarget<PlayingCard>(
                  onWillAcceptWithDetails: (details) =>
                      _canReturnToTray(details.data),
                  onAcceptWithDetails: (details) => setState(() {
                    _eng!.returnToTray(details.data);
                    _status = 'Back to Tray';
                    _selected = null;
                    _hint = null;
                  }),
                  builder: (context, cand, rej) => GestureDetector(
                    onTap: _tapTray,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: cand.isNotEmpty
                                ? Colors.blue
                                : rej.isNotEmpty
                                    ? Colors.red.shade900
                                    : Colors.transparent),
                        color: rej.isNotEmpty
                            ? Colors.red.withValues(alpha: 0.06)
                            : null,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Tray (${tray.length})',
                              textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final c in tray)
                                _trayCard(c, isSmallScreen: isSmallScreen),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (eng != null && eng.initialDrawCount > 5)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: tray.length >= 2 ? _sortTray : null,
                          child: const Text('Sort'),
                        ),
                      ),
                    if (eng != null && eng.initialDrawCount > 5)
                      const SizedBox(width: 0),
                    Expanded(
                      child: Builder(builder: (context) {
                        final isFinal = eng?.builder.isComplete == true;
                        final label = isFinal ? 'Commit' : 'Next 3';
                        final enabled =
                            eng != null && (isFinal ? true : canNext);
                        return ElevatedButton(
                          onPressed: !enabled
                              ? null
                              : () async {
                                  if (isFinal) {
                                    final b = _eng!.finalize();
                                    final wildMode = widget.options.wildMode;
                                    final e =
                                        BoardEval.from(b, wildMode: wildMode);
                                    final next =
                                        FantasyEngine.nextState(_fantasy, e);
                                    final nextInit =
                                        await Navigator.of(context).push<int>(
                                      adaptiveRoute(
                                        (_) => ResultScreen(
                                          board: b,
                                          nextFantasy: next,
                                          ruleset: _ruleset,
                                          seed: widget.seed,
                                          wildMode: wildMode,
                                          history: List.of(_eng!.history),
                                        ),
                                      ),
                                    );
                                    setState(() {
                                      _fantasy = next;
                                      _eng = null;
                                      _status = 'Ready';
                                    });
                                    if (nextInit != null) {
                                      _deal();
                                    }
                                  } else {
                                    setState(() {
                                      final eng2 = _eng!;
                                      CycleLogic.autoDiscardForNext(eng2);
                                      eng2.nextCycle();
                                      _status = 'Drew 3';
                                      _selected = null;
                                      _hint = null;
                                    });
                                  }
                                },
                          child: Text(label),
                        );
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (eng != null && eng.discards.isNotEmpty) ...[
                  Text('Discarded (${eng.discards.length})',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in eng.discards)
                        _cardWidget(c, isSmallScreen: isSmallScreen)
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
