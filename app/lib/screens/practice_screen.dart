import 'package:material_ui/material_ui.dart';
import 'package:ofc_app_core/ofc_core.dart';

import '../controllers/practice_controller.dart';
import '../presentation/labels.dart';
import '../utils/navigation_utils.dart';
import '../widgets/hand_table.dart';
import 'practice_result_screen.dart';

/// Solo practice: play a hand, see the result, play the next one.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({
    super.key,
    required this.seed,
    this.options = GameOptions.standard,
  });

  final int seed;
  final GameOptions options;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  late final PracticeController _controller =
      PracticeController(seed: widget.seed, options: widget.options);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _advance() async {
    final c = _controller;
    if (!c.hand.isComplete) {
      c.drawNext();
      return;
    }
    final seed = c.handSeed;
    final result = c.commit();
    await Navigator.of(context).push(
        adaptiveRoute((_) => PracticeResultScreen(result: result, seed: seed)));
    if (mounted) c.nextHand();
  }

  Future<void> _confirmLeave() async {
    final navigator = Navigator.of(context);
    if (await showDiscardConfirmationDialog(context) && mounted) {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(Labels.mode('Practice', widget.options)),
          centerTitle: true,
        ),
        body: HandTable(
          controller: _controller,
          onAdvance: _advance,
          header: [
            ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => Align(
                alignment: Alignment.centerLeft,
                // Plain Text: a web SelectableText is a disabled <textarea> with an empty value,
                // which hides the seed from assistive technology.
                child: Text('Seed: ${_controller.handSeed}',
                    style: TextStyle(color: Colors.grey.shade700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
