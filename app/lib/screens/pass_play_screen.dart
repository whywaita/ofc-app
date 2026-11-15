import 'package:flutter/material.dart';
import 'package:ofc_app_core/ofc_core.dart';

import '../controllers/pass_play_controller.dart';
import '../presentation/labels.dart';
import '../utils/navigation_utils.dart';
import '../widgets/hand_table.dart';
import 'pass_play_result_screen.dart';

/// Two players on one device, passing it after every draw.
class PassPlayScreen extends StatefulWidget {
  const PassPlayScreen({super.key, this.options = GameOptions.standard});

  final GameOptions options;

  @override
  State<PassPlayScreen> createState() => _PassPlayScreenState();
}

class _PassPlayScreenState extends State<PassPlayScreen> {
  late final PassPlayController _controller =
      PassPlayController(options: widget.options);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _advance() async {
    final result = _controller.advance();
    if (result == null) return;
    final navigator = Navigator.of(context);
    final again = await navigator
        .push<bool>(adaptiveRoute((_) => PassPlayResultScreen(result: result)));
    if (!mounted) return;
    if (again == true) {
      _controller.nextHand();
    } else {
      navigator.pop();
    }
  }

  Future<void> _confirmLeave() async {
    final navigator = Navigator.of(context);
    final leave = await showDiscardConfirmationDialog(
      context,
      content:
          "Both players' game progress will be lost. Are you sure you want to go back?",
    );
    if (leave && mounted) navigator.pop();
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
          title: Text(Labels.mode('Pass & Play', widget.options)),
          centerTitle: true,
        ),
        body: HandTable(
          controller: _controller,
          onAdvance: _advance,
          header: [
            ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => Text(
                'Turn: ${Labels.player(_controller.current)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
