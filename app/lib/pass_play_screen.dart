import 'package:flutter/material.dart';
import 'package:ofc_app_core/core/models/playing_card.dart';
import 'package:ofc_app_core/features/game/domain/cycle_logic.dart';
import 'package:ofc_app_core/features/game/domain/game_options.dart';
import 'package:ofc_app_core/features/game/domain/game_state.dart';
import 'package:ofc_app_core/features/game/domain/pineapple_engine.dart';
import 'package:ofc_app_core/features/game/domain/score_engine.dart';
import 'pass_play_result.dart';
import 'utils/navigation_utils.dart';
import 'widgets/card_widget.dart';

class PassPlayScreen extends StatefulWidget {
  final GameOptions options;
  const PassPlayScreen({super.key, this.options = const GameOptions()});

  @override
  State<PassPlayScreen> createState() => _PassPlayScreenState();
}

class _PassPlayScreenState extends State<PassPlayScreen> {
  late GameState gs;
  Player current = Player.a;
  String status = 'Ready';

  @override
  void initState() {
    super.initState();
    gs = GameState(options: widget.options);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        gs.deal(Player.a); // A 5枚
        current = Player.b;
        gs.deal(Player.b); // B 5枚
        current = Player.a;
        status = 'Dealt A/B';
      });
    });
  }

  PineappleEngine get eng => gs.engineOf(current);

  Widget _card(PlayingCard c, {bool large = false, Color? border}) =>
      CardWidget(card: c, large: large, borderColor: border);

  Set<String> _ids() => CycleLogic.currentCycleIds(eng.history);
  int _last() => CycleLogic.lastDrawCount(eng.history);
  int _placed(Set<String> ids) =>
      CycleLogic.placedCountForCycle(eng.builder, ids);
  // List<PlayingCard> _leftovers(Set<String> ids) => CycleLogic.trayCardsForCycle(eng.tray, ids);

  Widget _drop(
      String title, List<PlayingCard> currentCards, int max, Slot slot) {
    return DragTarget<PlayingCard>(
      onWillAcceptWithDetails: (d) {
        if (eng.phase != Phase.placing || currentCards.length >= max) {
          return false;
        }
        final last = _last();
        if (last == 3 && eng.tray.contains(d.data)) {
          final placed = _placed(_ids());
          if (placed >= 2) return false;
        }
        return true;
      },
      onAcceptWithDetails: (d) => setState(() {
        final c = d.data;
        if (eng.tray.contains(c)) {
          gs.place(current, slot, c);
        } else {
          // Move card from one board position to another
          if (!eng.builder.remove(c)) {
            throw StateError('Card not found on board: $c');
          }
          switch (slot) {
            case Slot.top:
              eng.builder.placeTop(c);
              break;
            case Slot.middle:
              eng.builder.placeMiddle(c);
              break;
            case Slot.bottom:
              eng.builder.placeBottom(c);
              break;
          }
        }
        status = 'Placed';
      }),
      builder: (context, cand, _) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(
              color: cand.isNotEmpty ? Colors.teal : Colors.grey.shade400),
          borderRadius: BorderRadius.circular(10),
          color: cand.isNotEmpty ? Colors.teal.withValues(alpha: 0.06) : null,
        ),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in currentCards)
              if (_ids().contains(c.toString()))
                Draggable<PlayingCard>(
                  data: c,
                  feedback: Material(
                      color: Colors.transparent,
                      child: _card(c, large: true, border: Colors.teal)),
                  childWhenDragging: Opacity(
                      opacity: 0.3, child: _card(c, border: Colors.teal)),
                  child: _card(c, border: Colors.teal),
                )
              else
                _card(c, border: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }

  Future<void> _onPrimaryButton() async {
    final isFinal = eng.builder.isComplete;
    if (isFinal) {
      // commit current player
      gs.finalize(current);
      setState(() => status = 'Committed');
      if (current == Player.a) {
        // switch to B
        setState(() => current = Player.b);
        return;
      }
      // 両者が確定済みかチェック
      if (gs.boardA == null || gs.boardB == null) {
        // 相手が未確定なら、その相手へ手番を戻す
        setState(() {
          current = Player.a;
          status = 'Waiting opponent';
        });
        return;
      }
      // Both committed → show result
      final nextFantasyA = gs.fantasyA.active ? gs.fantasyA.initialCount : 0;
      final nextFantasyB = gs.fantasyB.active ? gs.fantasyB.initialCount : 0;
      final wildMode = widget.options.wildMode;
      final vs = gs.lastScore ??
          ScoreEngine.compare(gs.boardA!, gs.boardB!, wildMode: wildMode);
      final _ = await Navigator.of(context).push<bool>(
        adaptiveRoute(
          (_) => PassPlayResult(
            score: vs,
            boardA: gs.boardA!,
            boardB: gs.boardB!,
            nextFantasyA: nextFantasyA,
            nextFantasyB: nextFantasyB,
            wildMode: wildMode,
          ),
        ),
      );
      // Next hand: 個別Dealし、Fantasyのない側から開始
      setState(() {
        final prevFA = gs.fantasyA;
        final prevFB = gs.fantasyB;
        gs = GameState(
            options: widget.options, fantasyA: prevFA, fantasyB: prevFB);
        gs.deal(Player.a);
        gs.deal(Player.b);
        final aIsFantasy = gs.aEngine.initialDrawCount > 5;
        final bIsFantasy = gs.bEngine.initialDrawCount > 5;
        current = (aIsFantasy && !bIsFantasy) ? Player.b : Player.a;
        status = 'Dealt A/B';
      });
      return;
    }

    // Next 3: auto-discard leftovers then draw
    if (_last() == 3) {
      CycleLogic.autoDiscardForNext(eng);
    }
    setState(() {
      // 自動Discard後に readiness を再評価し、安全に nextCycle する
      final curEng = gs.engineOf(current);
      if (curEng.needsCycle) {
        gs.nextCycle(current);
        status = 'Drew 3';
        final other = current == Player.a ? Player.b : Player.a;
        final otherEng = gs.engineOf(other);
        // Fantasy中のプレイヤーには3枚を配らない → スキップ
        current = (otherEng.initialDrawCount > 5) ? current : other;
      } else {
        status = 'Cycle not ready';
      }
    });
  }

  String _modeTitle() {
    if (widget.options.isDeucesWild) return 'Pass & Play (Deuces Wild)';
    if (widget.options.isJokerWild) return 'Pass & Play (Joker Wild)';
    return 'Pass & Play';
  }

  Future<void> _handleBackPress() async {
    final navigator = Navigator.of(context);
    final shouldPop = await showDiscardConfirmationDialog(
      context,
      content:
          "Both players' game progress will be lost. Are you sure you want to go back?",
    );
    if (shouldPop && context.mounted) {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tray = eng.tray;
    final top = eng.builder.top;
    final middle = eng.builder.middle;
    final bottom = eng.builder.bottom;
    final ids = _ids();

    final isFinal = eng.builder.isComplete;
    final canNext = CycleLogic.canNext(eng);
    final label =
        isFinal ? 'Commit ${current == Player.a ? '(A)' : '(B)'}' : 'Next 3';

    return PopScope(
      canPop: eng.phase != Phase.placing,
      onPopInvokedWithResult: (bool didPop, _) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_modeTitle())),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Turn: ${current == Player.a ? 'Player A' : 'Player B'}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('Status: $status', textAlign: TextAlign.center),
              const Divider(),
              _drop('Top', top, 3, Slot.top),
              const SizedBox(height: 8),
              _drop('Middle', middle, 5, Slot.middle),
              const SizedBox(height: 8),
              _drop('Bottom', bottom, 5, Slot.bottom),
              const Divider(),
              // Tray (DragTarget to allow back)
              DragTarget<PlayingCard>(
                onWillAcceptWithDetails: (d) {
                  if (eng.phase != Phase.placing) return false;
                  if (eng.tray.contains(d.data)) return false;
                  return ids.contains(d.data.toString());
                },
                onAcceptWithDetails: (d) => setState(() {
                  eng.returnToTray(d.data);
                  status = 'Back to Tray';
                }),
                builder: (context, cand, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Tray (${tray.length})', textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final c in tray)
                          Draggable<PlayingCard>(
                            data: c,
                            feedback: Material(
                                color: Colors.transparent,
                                child: _card(c, large: true)),
                            childWhenDragging:
                                Opacity(opacity: 0.3, child: _card(c)),
                            child: _card(c),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (eng.initialDrawCount > 5)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: tray.length >= 2
                            ? () => setState(() {
                                  eng.sortTray((a, b) {
                                    // Handle jokers: put them at the end
                                    if (a.isJoker && b.isJoker) return 0;
                                    if (a.isJoker) return 1;
                                    if (b.isJoker) return -1;

                                    final rv =
                                        b.rank!.value.compareTo(a.rank!.value);
                                    if (rv != 0) return rv;
                                    int suitOrder(String s) => switch (s) {
                                          'spades' => 3,
                                          'hearts' => 2,
                                          'diamonds' => 1,
                                          _ => 0,
                                        };
                                    return suitOrder(b.suit!.name) -
                                        suitOrder(a.suit!.name);
                                  });
                                  status = 'Sorted';
                                })
                            : null,
                        child: const Text('Sort'),
                      ),
                    ),
                  if (eng.initialDrawCount > 5) const SizedBox(width: 0),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isFinal
                          ? _onPrimaryButton
                          : (canNext ? _onPrimaryButton : null),
                      child: Text(label),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (eng.discards.isNotEmpty) ...[
                Text('Your Discards (${eng.discards.length})',
                    textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final c in eng.discards) _card(c)],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
