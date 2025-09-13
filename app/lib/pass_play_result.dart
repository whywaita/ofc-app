import 'package:flutter/material.dart';
import 'package:ofc_app_core/features/game/domain/score_engine.dart';
import 'package:ofc_app_core/features/game/domain/board.dart';
import 'package:ofc_app_core/core/models/playing_card.dart';
import 'package:ofc_app_core/features/game/domain/foul_checker.dart';

class PassPlayResult extends StatelessWidget {
  final VersusScore score;
  final Board boardA;
  final Board boardB;
  final int? nextFantasyA; // null/0 means normal 5
  final int? nextFantasyB;
  const PassPlayResult({super.key, required this.score, required this.boardA, required this.boardB, this.nextFantasyA, this.nextFantasyB});

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

  Widget _card(PlayingCard c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Text('${_rank(c)}${_suit(c)}',
            style: TextStyle(fontSize: 16, color: _isRed(c) ? Colors.red : Colors.black87, fontWeight: FontWeight.w600)),
      );

  @override
  Widget build(BuildContext context) {
    Widget col(String title, ScoreBreakdown s, Board b) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              Builder(builder: (_) {
                final foul = FoulChecker.isFoul(BoardEval.from(b));
                return Text(foul ? 'FOUL' : 'OK',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: foul ? Colors.red : Colors.green));
              }),
              const SizedBox(height: 8),
              Text('Rows: T ${s.rows.top} / M ${s.rows.middle} / B ${s.rows.bottom}', textAlign: TextAlign.center),
              Text('Royalties: ${s.royalties}, Sweep: ${s.sweep}', textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text('Total: ${s.total}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [for (final c in b.top) _card(c)]),
              Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [for (final c in b.middle) _card(c)]),
              Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [for (final c in b.bottom) _card(c)]),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [col('Player A', score.a, boardA), const SizedBox(width: 12), col('Player B', score.b, boardB)]),
            const SizedBox(height: 16),
            if ((nextFantasyA ?? 0) > 5 || (nextFantasyB ?? 0) > 5) ...[
              const Divider(),
              if ((nextFantasyA ?? 0) > 5)
                Text('Next Hand: A Fantasy $nextFantasyA cards', textAlign: TextAlign.center),
              if ((nextFantasyB ?? 0) > 5)
                Text('Next Hand: B Fantasy $nextFantasyB cards', textAlign: TextAlign.center),
            ],
            const Spacer(),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Next Hand'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}
