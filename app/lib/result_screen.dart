import 'package:flutter/material.dart';
import 'package:ofc_app_core/features/game/domain/board.dart';
import 'package:ofc_app_core/features/game/domain/fantasy_engine.dart';
import 'package:ofc_app_core/features/game/domain/foul_checker.dart';
import 'package:ofc_app_core/features/game/domain/ruleset.dart';
import 'package:ofc_app_core/features/game/domain/pineapple_engine.dart';
import 'package:ofc_app_core/features/game/domain/hand_category3.dart';
import 'package:ofc_app_core/features/game/domain/hand_category5.dart';

class ResultScreen extends StatelessWidget {
  final Board board;
  final FantasyState nextFantasy;
  final Ruleset ruleset;
  final List<ActionLogEntry>? history;
  const ResultScreen({super.key, required this.board, required this.nextFantasy, required this.ruleset, this.history});

  String _cat3Name(Hand3Rank r) => switch (r.category) {
        Hand3Category.threeOfAKind => 'Trips',
        Hand3Category.pair => 'Pair',
        _ => 'High',
      };
  String _cat5Name(Hand5Rank r) => switch (r.category) {
        Hand5Category.straightFlush => 'Straight Flush',
        Hand5Category.fourOfAKind => 'Four of a Kind',
        Hand5Category.fullHouse => 'Full House',
        Hand5Category.flush => 'Flush',
        Hand5Category.straight => 'Straight',
        Hand5Category.threeOfAKind => 'Trips',
        Hand5Category.twoPair => 'Two Pair',
        Hand5Category.onePair => 'One Pair',
        _ => 'High Card',
      };

  @override
  Widget build(BuildContext context) {
    final eval = BoardEval.from(board);
    final foul = FoulChecker.isFoul(eval);
    final rTop = ruleset.royaltyTop(eval.top);
    final rMid = ruleset.royaltyMiddle(eval.middle);
    final rBot = ruleset.royaltyBottom(eval.bottom);
    final rSum = foul ? 0 : (rTop + rMid + rBot);

    Widget row(String title, String body, int royalty) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(title)),
          Expanded(flex: 2, child: Text(body, textAlign: TextAlign.center)),
          Text(foul ? '-' : '+$royalty'),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(foul ? 'FOUL' : 'OK',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: foul ? Colors.red : Colors.green,
                    )),
            const SizedBox(height: 12),
            row('Top', _cat3Name(eval.top), rTop),
            row('Middle', _cat5Name(eval.middle), rMid),
            row('Bottom', _cat5Name(eval.bottom), rBot),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Royalties Total'),
                Text(foul ? '0' : '+$rSum'),
              ],
            ),
            const SizedBox(height: 16),
            if (nextFantasy.active) ...[
              Text('Next Hand: Fantasy ${nextFantasy.initialCount} cards',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(nextFantasy.initialCount),
                child: const Text('Start Next Hand'),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(0),
                child: const Text('Back'),
              ),
            ],
            const SizedBox(height: 16),
            if (history != null) ...[
              const Divider(),
              Text('Action Log (This hand)', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SizedBox(
                height: 160,
                child: ListView.builder(
                  itemCount: history!.length,
                  itemBuilder: (context, i) {
                    final e = history![i];
                    switch (e.type) {
                      case 'draw':
                        final n = e.data['count'];
                        return Text('draw: $n');
                      case 'place':
                        return Text('place: ${e.data['slot']} ${e.data['card']}');
                      case 'discard':
                        return Text('discard: ${e.data['card']}');
                      case 'commit':
                        return const Text('commit');
                      default:
                        return Text(e.type);
                    }
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
