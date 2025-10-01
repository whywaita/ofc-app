import 'package:flutter/material.dart';
import 'package:ofc_app_core/core/models/deck.dart';
import 'package:ofc_app_core/core/models/playing_card.dart';
import 'package:ofc_app_core/features/game/domain/board.dart';
import 'package:ofc_app_core/features/game/domain/fantasy_engine.dart';
import 'package:ofc_app_core/features/game/domain/ruleset.dart';
import 'result_screen.dart';
import 'package:ofc_app_core/features/game/domain/cycle_logic.dart';
import 'package:ofc_app_core/features/game/domain/pineapple_engine.dart';

class GameScreen extends StatefulWidget {
  final int seed;
  const GameScreen({super.key, required this.seed});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  PineappleEngine? _eng;
  String _status = 'Ready';
  FantasyState _fantasy = const FantasyState.inactive();
  final Ruleset _ruleset = Ruleset.defaultRules;
  Set<String> _movableIds = const {};

  @override
  void initState() {
    super.initState();
    // 画面表示と同時に自動で配る
    WidgetsBinding.instance.addPostFrameCallback((_) => _deal());
  }

  void _deal() {
    setState(() {
      _eng = PineappleEngine(Deck.standard(seed: widget.seed))
        ..startHand(fantasyInitialCount: _fantasy.active ? _fantasy.initialCount : 0);
      _status = 'Dealt ${_fantasy.active ? _fantasy.initialCount : 5}';
    });
  }

  String _rankSymbol(PlayingCard c) {
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

  String _suitEmoji(PlayingCard c) {
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

  Widget _cardWidget(PlayingCard c, {bool large = false, Color? borderColor, bool isSmallScreen = false}) {
    final txt = '${_rankSymbol(c)}${_suitEmoji(c)}';
    final color = _isRed(c) ? Colors.red : Colors.black87;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 6 : 10,
        vertical: isSmallScreen ? 4 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isSmallScreen ? 6 : 8),
        border: Border.all(color: borderColor ?? Colors.grey.shade400),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 2, offset: const Offset(0, 1)),
        ],
      ),
      child: Text(
        txt,
        style: TextStyle(
          fontSize: large ? (isSmallScreen ? 18 : 22) : (isSmallScreen ? 14 : 18),
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
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
      eng.tray.sort((a, b) {
        final rv = b.rank.value.compareTo(a.rank.value); // 高いランク優先
        if (rv != 0) return rv;
        int suitOrder(String s) => switch (s) {
              'spades' => 3,
              'hearts' => 2,
              'diamonds' => 1,
              _ => 0, // clubs
            };
        return suitOrder(b.suit.name) - suitOrder(a.suit.name);
      });
      _status = 'Sorted';
    });
  }

  int _lastDrawCount() => CycleLogic.lastDrawCount(_eng!.history);
  int _placedCountForCycle(Set<String> ids) => CycleLogic.placedCountForCycle(_eng!.builder, ids);
  // kept for clarity but unused after unifying auto-discard via CycleLogic
  // List<PlayingCard> _trayCardsForCycle(Set<String> ids) => CycleLogic.trayCardsForCycle(_eng!.tray, ids);

  Widget _dropZone({required String title, required List<PlayingCard> current, required int max, required Slot slot}) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return DragTarget<PlayingCard>(
      onWillAcceptWithDetails: (details) {
        final eng = _eng;
        if (eng == null || eng.phase != Phase.placing) return false;
        if (current.length >= max) return false;
        final lastCount = _lastDrawCount();
        if (lastCount == 3 && eng.tray.contains(details.data)) {
          final ids = _currentCycleIds();
          final placed = _placedCountForCycle(ids);
          if (placed >= 2) return false;
        }
        return true;
      },
      onAcceptWithDetails: (details) => setState(() {
        final eng = _eng!;
        final c = details.data;
        if (eng.tray.contains(c)) {
          eng.place(slot, c);
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
        _status = 'Placed';
      }),
      builder: (context, candidate, rejected) {
        final highlight = candidate.isNotEmpty;
        return Container(
          padding: EdgeInsets.all(isSmallScreen ? 6 : 10),
          decoration: BoxDecoration(
            border: Border.all(color: highlight ? Colors.teal : Colors.grey.shade400),
            borderRadius: BorderRadius.circular(isSmallScreen ? 6 : 10),
            color: highlight ? Colors.teal.withValues(alpha: 0.06) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$title ($max max)',
                style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                alignment: WrapAlignment.start,
                spacing: isSmallScreen ? 4 : 6,
                runSpacing: isSmallScreen ? 4 : 6,
                children: [
                  for (final c in current)
                    if (_movableIds.contains(c.toString()))
                      Draggable<PlayingCard>(
                        data: c,
                        feedback: Material(color: Colors.transparent, child: _cardWidget(c, large: true, borderColor: Colors.teal, isSmallScreen: isSmallScreen)),
                        childWhenDragging: Opacity(opacity: 0.3, child: _cardWidget(c, borderColor: Colors.teal, isSmallScreen: isSmallScreen)),
                        child: _cardWidget(c, borderColor: Colors.teal, isSmallScreen: isSmallScreen),
                      )
                    else
                      _cardWidget(c, borderColor: Colors.grey.shade500, isSmallScreen: isSmallScreen),
                ],
              ),
            ],
          ),
        );
      },
    );
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
    // Commit判定は下部の主ボタンで直接確認するため未使用
    _movableIds = _currentCycleIds();

    // スマートフォン対応
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Practice'),
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
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText('Seed: ${widget.seed}', style: const TextStyle(color: Colors.grey)),
            ),
            const SizedBox(height: 8),
            const Divider(),
            _dropZone(title: 'Top', current: top, max: 3, slot: Slot.top),
            SizedBox(height: isSmallScreen ? 4 : 8),
            _dropZone(title: 'Middle', current: middle, max: 5, slot: Slot.middle),
            SizedBox(height: isSmallScreen ? 4 : 8),
            _dropZone(title: 'Bottom', current: bottom, max: 5, slot: Slot.bottom),
            const Divider(),
            DragTarget<PlayingCard>(
              onWillAcceptWithDetails: (details) {
                final eng2 = _eng;
                if (eng2 == null) return false;
                if (eng2.tray.contains(details.data)) return false; // 既にTray
                if (eng2.phase != Phase.placing) return false;
                // 今サイクルのカードのみTrayに戻せる
                final ids = _currentCycleIds();
                return ids.contains(details.data.toString());
              },
              onAcceptWithDetails: (details) => setState(() {
                final eng2 = _eng!;
                // 配置済み から外して Tray へ戻す
                eng2.builder.top.remove(details.data);
                eng2.builder.middle.remove(details.data);
                eng2.builder.bottom.remove(details.data);
                eng2.tray.add(details.data);
                _status = 'Back to Tray';
              }),
              builder: (context, cand, rej) => Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: cand.isNotEmpty ? Colors.blue : Colors.transparent),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
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
                            feedback: Material(color: Colors.transparent, child: _cardWidget(c, large: true, isSmallScreen: isSmallScreen)),
                            childWhenDragging: Opacity(opacity: 0.3, child: _cardWidget(c, isSmallScreen: isSmallScreen)),
                            child: _cardWidget(c, isSmallScreen: isSmallScreen),
                          ),
                      ],
                    ),
                  ],
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
                    final enabled = eng != null && (isFinal ? true : canNext);
                    return ElevatedButton(
                      onPressed: !enabled
                          ? null
                          : () async {
                              if (isFinal) {
                                final b = _eng!.finalize();
                                final e = BoardEval.from(b);
                                final next = FantasyEngine.nextState(_fantasy, e);
                              final nextInit = await Navigator.of(context).push<int>(
                                MaterialPageRoute(
                                  builder: (_) => ResultScreen(board: b, nextFantasy: next, ruleset: _ruleset, seed: widget.seed, history: List.of(_eng!.history)),
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
              Text('Discarded (${eng.discards.length})', textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [for (final c in eng.discards) _cardWidget(c, isSmallScreen: isSmallScreen)],
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }
}
