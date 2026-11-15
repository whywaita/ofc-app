import 'package:flutter/material.dart';
import 'package:ofc_app_core/ofc_core.dart';

import '../presentation/labels.dart';
import '../widgets/result_board.dart';

/// Both boards side by side with the points each player won. Pops `true` for the next hand and
/// `false` (or null, by system back) to leave.
class PassPlayResultScreen extends StatelessWidget {
  const PassPlayResultScreen({super.key, required this.result});

  final MatchResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    Widget column(Player p) {
      final hand = result.of(p);
      final s = p == Player.a ? result.score.a : result.score.b;
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(Labels.player(p),
                textAlign: TextAlign.center, style: theme.titleMedium),
            FoulBadge(foul: hand.evaluation.isFoul, style: theme.bodyMedium),
            const SizedBox(height: 8),
            Text(
                'Rows: T ${s.rows.top} / M ${s.rows.middle} / B ${s.rows.bottom}',
                textAlign: TextAlign.center),
            Text(
                'Royalties (net): ${Labels.signed(s.royalties)}, '
                'Sweep: ${Labels.signed(s.sweep)}',
                textAlign: TextAlign.center),
            if (s.foul != 0)
              Text('Foul: ${s.foul}', textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text('Total: ${Labels.signed(s.total)}',
                textAlign: TextAlign.center, style: theme.titleLarge),
            const SizedBox(height: 8),
            ResultBoard(result: hand),
            if (hand.nextFantasy.isActive)
              Text('Next Hand: Fantasy ${hand.nextFantasy.initialCount} cards',
                  textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  column(Player.a),
                  const SizedBox(width: 12),
                  column(Player.b),
                ],
              ),
              const SizedBox(height: 16),
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
      ),
    );
  }
}
