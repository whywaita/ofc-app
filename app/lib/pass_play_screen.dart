import 'package:flutter/material.dart';
import 'package:ofc_app_core/core/models/playing_card.dart';
import 'package:ofc_app_core/features/game/domain/cycle_logic.dart';
import 'package:ofc_app_core/features/game/domain/game_state.dart';
import 'package:ofc_app_core/features/game/domain/pineapple_engine.dart';
import 'pass_play_result.dart';
import 'package:ofc_app_core/features/game/domain/score_engine.dart';

class PassPlayScreen extends StatefulWidget {
  const PassPlayScreen({super.key});

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
    gs = GameState();
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

  String _rank(PlayingCard c) {
    switch (c.rank.name) {
      case 'ace':
        return 'A';
      case 'king':
        return 'K';
      case 'queen':
        return 'Q';
      case 'jack':
        return 'J';
      case 'ten':
        return 'T';
      default:
        return c.rank.value.toString();
    }
  }

  String _suit(PlayingCard c) {
    switch (c.suit.name) {
      case 'hearts':
        return '♥️';
      case 'diamonds':
        return '♦️';
      case 'spades':
        return '♠️';
      default:
        return '♣️';
    }
  }

  bool _isRed(PlayingCard c) => c.suit.name == 'hearts' || c.suit.name == 'diamonds';

  Widget _card(PlayingCard c, {bool large = false, Color? border}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border ?? Colors.grey.shade400),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 2, offset: const Offset(0, 1))],
        ),
        child: Text('${_rank(c)}${_suit(c)}',
            style: TextStyle(fontSize: large ? 22 : 18, color: _isRed(c) ? Colors.red : Colors.black87, fontWeight: FontWeight.w600)),
      );

  Set<String> _ids() => CycleLogic.currentCycleIds(eng.history);
  int _last() => CycleLogic.lastDrawCount(eng.history);
  int _placed(Set<String> ids) => CycleLogic.placedCountForCycle(eng.builder, ids);
  List<PlayingCard> _leftovers(Set<String> ids) => CycleLogic.trayCardsForCycle(eng.tray, ids);

  Widget _drop(String title, List<PlayingCard> currentCards, int max, Slot slot) {
    return DragTarget<PlayingCard>(
      onWillAcceptWithDetails: (d) {
        if (eng.phase != Phase.placing || currentCards.length >= max) return false;
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
          eng.builder.top.remove(c);
          eng.builder.middle.remove(c);
          eng.builder.bottom.remove(c);
          switch (slot) {
            case Slot.top:
              eng.builder.top.add(c);
              break;
            case Slot.middle:
              eng.builder.middle.add(c);
              break;
            case Slot.bottom:
              eng.builder.bottom.add(c);
              break;
          }
        }
        status = 'Placed';
      }),
      builder: (context, cand, _) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: cand.isNotEmpty ? Colors.teal : Colors.grey.shade400),
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
                  feedback: Material(color: Colors.transparent, child: _card(c, large: true, border: Colors.teal)),
                  childWhenDragging: Opacity(opacity: 0.3, child: _card(c, border: Colors.teal)),
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
        setState(() => status = 'Waiting opponent');
        return;
      }
      // Both committed → show result
      final nextFantasyA = gs.fantasyA.active ? gs.fantasyA.initialCount : 0;
      final nextFantasyB = gs.fantasyB.active ? gs.fantasyB.initialCount : 0;
      final vs = gs.lastScore ?? ScoreEngine.compare(gs.boardA!, gs.boardB!);
      final _ = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PassPlayResult(score: vs, boardA: gs.boardA!, boardB: gs.boardB!, nextFantasyA: nextFantasyA, nextFantasyB: nextFantasyB),
        ),
      );
      // Next hand: 個別Dealし、Fantasyのない側から開始
      setState(() {
        final prevFA = gs.fantasyA;
        final prevFB = gs.fantasyB;
        gs = GameState(fantasyA: prevFA, fantasyB: prevFB);
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
      final ids = _ids();
      final leftovers = _leftovers(ids);
      for (final c in leftovers) {
        eng.tray.remove(c);
        eng.history.add(ActionLogEntry('discard', {'card': c.toString()}));
      }
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

  @override
  Widget build(BuildContext context) {
    final tray = eng.tray;
    final top = eng.builder.top;
    final middle = eng.builder.middle;
    final bottom = eng.builder.bottom;
    final ids = _ids();

    final isFinal = eng.builder.isComplete;
    final canNext = CycleLogic.canNext(eng);
    final label = isFinal ? 'Commit ${current == Player.a ? '(A)' : '(B)'}' : 'Next 3';

    return Scaffold(
      appBar: AppBar(title: const Text('Pass & Play')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Turn: ${current == Player.a ? 'Player A' : 'Player B'}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
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
                eng.builder.top.remove(d.data);
                eng.builder.middle.remove(d.data);
                eng.builder.bottom.remove(d.data);
                eng.tray.add(d.data);
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
                          feedback: Material(color: Colors.transparent, child: _card(c, large: true)),
                          childWhenDragging: Opacity(opacity: 0.3, child: _card(c)),
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
                                tray.sort((a, b) {
                                  final rv = b.rank.value.compareTo(a.rank.value);
                                  if (rv != 0) return rv;
                                  int suitOrder(String s) => switch (s) {
                                        'spades' => 3,
                                        'hearts' => 2,
                                        'diamonds' => 1,
                                        _ => 0,
                                      };
                                  return suitOrder(b.suit.name) - suitOrder(a.suit.name);
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
                    onPressed: isFinal ? _onPrimaryButton : (canNext ? _onPrimaryButton : null),
                    child: Text(label),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
