import 'package:material_ui/material_ui.dart';

enum _SeedMode { random, custom }

/// A fresh random seed in the positive 31-bit range.
int randomSeed() => DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF;

/// Asks for the Practice seed: random, or an integer the player enters to replay a deal.
/// Returns null when cancelled.
Future<int?> showSeedDialog(BuildContext context) {
  return showDialog<int>(
    context: context,
    builder: (_) => const _SeedDialog(),
  );
}

class _SeedDialog extends StatefulWidget {
  const _SeedDialog();

  @override
  State<_SeedDialog> createState() => _SeedDialogState();
}

class _SeedDialogState extends State<_SeedDialog> {
  _SeedMode _mode = _SeedMode.random;
  final _text = TextEditingController();

  int? get _parsed => int.tryParse(_text.text.trim());

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final custom = _mode == _SeedMode.custom;
    final valid = _parsed != null;
    return AlertDialog(
      insetPadding:
          EdgeInsets.symmetric(horizontal: compact ? 20 : 40, vertical: 24),
      contentPadding:
          EdgeInsets.fromLTRB(compact ? 20 : 24, 20, compact ? 20 : 24, 0),
      title: const Text('Choose Practice Seed'),
      content: SizedBox(
        width: compact ? double.maxFinite : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<_SeedMode>(
              segments: const [
                ButtonSegment(
                    value: _SeedMode.random,
                    label: Text('Random'),
                    icon: Icon(Icons.shuffle)),
                ButtonSegment(
                    value: _SeedMode.custom,
                    label: Text('Specify'),
                    icon: Icon(Icons.edit)),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              enabled: custom,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Seed (integer)'),
              onChanged: (_) => setState(() {}),
            ),
            if (custom && _text.text.isNotEmpty && !valid)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Enter a valid integer',
                      style: TextStyle(color: Colors.red)),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: custom && !valid
              ? null
              : () =>
                  Navigator.of(context).pop(custom ? _parsed : randomSeed()),
          child: const Text('Start'),
        ),
      ],
    );
  }
}
