import 'package:flutter/material.dart';
import 'package:ofc_app_core/ofc_core.dart';

import '../presentation/labels.dart';
import 'card_widget.dart';

/// FOUL / OK in the verdict colour.
class FoulBadge extends StatelessWidget {
  const FoulBadge({super.key, required this.foul, this.style});

  final bool foul;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text(
        foul ? 'FOUL' : 'OK',
        textAlign: TextAlign.center,
        style: (style ?? Theme.of(context).textTheme.headlineMedium)
            ?.copyWith(color: foul ? Colors.red : Colors.green),
      );
}

/// A committed board, row by row: hand name, royalty and cards.
class ResultBoard extends StatelessWidget {
  const ResultBoard({super.key, required this.result});

  final HandResult result;

  @override
  Widget build(BuildContext context) {
    final foul = result.evaluation.isFoul;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in BoardRow.values) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(Labels.row(row))),
              Expanded(
                flex: 2,
                child: Text(Labels.handOf(result.evaluation, row),
                    textAlign: TextAlign.center),
              ),
              Text(foul ? '-' : '+${result.royalties.of(row)}'),
            ],
          ),
          const SizedBox(height: 6),
          CardLine(result.board.row(row)),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
