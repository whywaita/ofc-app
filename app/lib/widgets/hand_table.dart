import 'package:material_ui/material_ui.dart';
import 'package:ofc_app_core/ofc_core.dart';

import '../controllers/hand_table_controller.dart';
import '../presentation/labels.dart';
import 'card_widget.dart';

/// The playing surface for one hand: three rows, the tray, the primary button and the discards.
///
/// Every card can be dragged or tapped. Tapping picks a card up and tapping a row (or its label,
/// which is also the row's named "Place in …" action) puts it down; this is the path a screen
/// reader or a click-only driver uses. Both paths ask [HandTableController] for the same rules.
class HandTable extends StatelessWidget {
  const HandTable({
    super.key,
    required this.controller,
    required this.onAdvance,
    this.header = const [],
  });

  final HandTableController controller;

  /// Called by the primary button (Next 3 / Commit) when it is enabled.
  final VoidCallback onAdvance;

  /// Lines shown under the status, such as the seed or whose turn it is.
  final List<Widget> header;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final hand = controller.hand;
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(compact ? 8 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Text('Status: ${controller.status}'),
                if (controller.hint != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(controller.hint!,
                        style: TextStyle(color: Colors.red.shade900)),
                  ),
                const SizedBox(height: 4),
                ...header,
                const SizedBox(height: 8),
                const Divider(),
                for (final row in BoardRow.values) ...[
                  _RowZone(controller: controller, row: row, compact: compact),
                  SizedBox(height: compact ? 4 : 8),
                ],
                const Divider(),
                _TrayZone(controller: controller, compact: compact),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (hand.isFantasy)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: hand.tray.length >= 2
                              ? controller.sortTray
                              : null,
                          child: const Text('Sort'),
                        ),
                      ),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: controller.canAdvance ? onAdvance : null,
                        child: Text(controller.advanceLabel),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (hand.discards.isNotEmpty) ...[
                  Text('Discarded (${hand.discards.length})',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  CardLine(hand.discards, compact: compact),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A card that can be tapped (to pick it up) and, when [draggable], dragged.
class _TableCard extends StatelessWidget {
  const _TableCard({
    required this.controller,
    required this.card,
    required this.draggable,
    required this.compact,
    this.border,
  });

  final HandTableController controller;
  final PlayingCard card;
  final bool draggable;
  final bool compact;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final selected = controller.selected == card;
    final borderColor = selected ? Colors.orange.shade800 : border;
    final face =
        CardWidget(card: card, borderColor: borderColor, compact: compact);
    // Semantics outside the GestureDetector, with the glyph excluded: the label survives and the
    // tap action lands on the same node, which is what a screen reader and a click-only driver
    // each need. A label on a node whose child also carries text is otherwise discarded.
    final tappable = Semantics(
      container: true,
      button: true,
      selected: selected,
      label: Labels.cardName(card),
      child: GestureDetector(
        onTap: () => controller.select(card),
        child: ExcludeSemantics(child: face),
      ),
    );
    if (!draggable) return tappable;
    return Draggable<PlayingCard>(
      data: card,
      feedback: Material(
        color: Colors.transparent,
        child: CardWidget(
            card: card,
            large: true,
            borderColor: borderColor,
            compact: compact),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: face),
      child: tappable,
    );
  }
}

class _RowZone extends StatelessWidget {
  const _RowZone(
      {required this.controller, required this.row, required this.compact});

  final HandTableController controller;
  final BoardRow row;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final hand = controller.hand;
    final title = '${Labels.row(row)} (${row.capacity} max)';
    return DragTarget<PlayingCard>(
      onWillAcceptWithDetails: (d) =>
          controller.placementBlock(d.data, row) == null,
      onAcceptWithDetails: (d) => controller.place(d.data, row),
      builder: (context, candidate, rejected) {
        // A refused drag is shown, not swallowed.
        final accepted = candidate.isNotEmpty;
        final refusedCard = rejected.whereType<PlayingCard>().firstOrNull;
        final refuseReason = refusedCard == null
            ? null
            : controller.placementBlock(refusedCard, row);
        return GestureDetector(
          onTap: () => controller.tapRow(row),
          child: Container(
            padding: EdgeInsets.all(compact ? 6 : 10),
            decoration: BoxDecoration(
              border: Border.all(
                  color: accepted
                      ? Colors.teal
                      : refusedCard != null
                          ? Colors.red.shade900
                          : Colors.grey.shade400),
              borderRadius: BorderRadius.circular(compact ? 6 : 10),
              color: accepted
                  ? Colors.teal.withValues(alpha: 0.06)
                  : refusedCard != null
                      ? Colors.red.withValues(alpha: 0.06)
                      : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The row label doubles as the explicit place action: once a row holds cards a
                // tap can land on one of them (which picks it up), and a full row leaves nowhere
                // else to tap.
                Semantics(
                  container: true,
                  button: true,
                  label: 'Place in $title',
                  child: GestureDetector(
                    onTap: () => controller.tapRow(row),
                    child: ExcludeSemantics(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: compact ? 12 : 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: compact ? 4 : 6,
                  runSpacing: compact ? 4 : 6,
                  children: [
                    for (final c in hand.row(row))
                      _TableCard(
                        controller: controller,
                        card: c,
                        draggable: hand.isMovable(c),
                        compact: compact,
                        border: hand.isMovable(c)
                            ? Colors.teal
                            : Colors.grey.shade500,
                      ),
                  ],
                ),
                if (refuseReason != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      refuseReason,
                      style: TextStyle(
                          fontSize: compact ? 11 : 12,
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
}

class _TrayZone extends StatelessWidget {
  const _TrayZone({required this.controller, required this.compact});

  final HandTableController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tray = controller.hand.tray;
    return DragTarget<PlayingCard>(
      onWillAcceptWithDetails: (d) => controller.canReturnToTray(d.data),
      onAcceptWithDetails: (d) => controller.returnToTray(d.data),
      builder: (context, candidate, rejected) => GestureDetector(
        onTap: controller.tapTray,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(
                color: candidate.isNotEmpty
                    ? Colors.blue
                    : rejected.isNotEmpty
                        ? Colors.red.shade900
                        : Colors.transparent),
            color:
                rejected.isNotEmpty ? Colors.red.withValues(alpha: 0.06) : null,
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
                    _TableCard(
                      controller: controller,
                      card: c,
                      draggable: true,
                      compact: compact,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
