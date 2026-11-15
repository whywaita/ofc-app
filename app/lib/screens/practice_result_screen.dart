import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ofc_app_core/ofc_core.dart';

import '../presentation/labels.dart';
import '../widgets/result_board.dart';

/// The result of one Practice hand. Popping it (either button or system back) returns to the
/// table, which deals the next hand.
class PracticeResultScreen extends StatelessWidget {
  const PracticeResultScreen({
    super.key,
    required this.result,
    required this.seed,
  });

  final HandResult result;

  /// The seed that dealt this hand.
  final int seed;

  @override
  Widget build(BuildContext context) {
    final foul = result.evaluation.isFoul;
    final next = result.nextFantasy;
    final theme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FoulBadge(foul: foul),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    // Plain Text, not SelectableText: on the web a SelectableText becomes a
                    // disabled <textarea> whose value is empty, so a screen reader never sees the
                    // seed. The copy button next to it is the copying path.
                    child: Text(
                      'Seed: $seed',
                      textAlign: TextAlign.center,
                      // grey measured 2.55:1 on this background; shade700 clears 4.5:1.
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy seed',
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: '$seed')),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ResultBoard(result: result),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Royalties Total'),
                  Text(foul ? '0' : '+${result.royalties.total}'),
                ],
              ),
              const SizedBox(height: 16),
              if (next.isActive) ...[
                Text('Next Hand: Fantasy ${next.initialCount} cards',
                    textAlign: TextAlign.center, style: theme.titleMedium),
                const SizedBox(height: 8),
              ],
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(next.isActive ? 'Start Next Hand' : 'Back'),
              ),
              const SizedBox(height: 16),
              const Divider(),
              Text('Action Log (This hand)', style: theme.titleMedium),
              const SizedBox(height: 8),
              for (final a in result.history) Text(Labels.action(a)),
            ],
          ),
        ),
      ),
    );
  }
}
