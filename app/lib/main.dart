import 'package:flutter/material.dart';
import 'game_screen.dart';
import 'pass_play_screen.dart';

void main() {
  runApp(const OfcApp());
}

class OfcApp extends StatelessWidget {
  const OfcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OFCP',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OFCP')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final seed = await _chooseSeed(context);
                  if (seed == null) return; // キャンセル
                  // 選択したシードでPracticeを開始
                  // シードはGameScreenへ渡し、画面内/結果画面で表示する
                  // ignore: use_build_context_synchronously
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => GameScreen(seed: seed)),
                  );
                },
                child: const Text('Practice'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PassPlayScreen()),
                  );
                },
                child: const Text('Pass & Play (A/B)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _SeedMode { random, custom }

Future<int?> _chooseSeed(BuildContext context) async {
  _SeedMode mode = _SeedMode.random;
  final controller = TextEditingController();
  int? parsed;

  int genRandomSeed() => DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF;

  return showDialog<int>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setState) {
        final customValid = int.tryParse(controller.text.trim()) != null;
        return AlertDialog(
          title: const Text('Choose Practice Seed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<_SeedMode>(
                segments: const [
                  ButtonSegment<_SeedMode>(value: _SeedMode.random, label: Text('Random'), icon: Icon(Icons.shuffle)),
                  ButtonSegment<_SeedMode>(value: _SeedMode.custom, label: Text('Specify'), icon: Icon(Icons.edit)),
                ],
                selected: {mode},
                onSelectionChanged: (s) => setState(() => mode = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                enabled: mode == _SeedMode.custom,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Seed (integer)'),
                onChanged: (_) => setState(() {}),
              ),
              if (mode == _SeedMode.custom && controller.text.isNotEmpty && !customValid)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Enter a valid integer', style: TextStyle(color: Colors.red)),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: mode == _SeedMode.custom && !customValid
                  ? null
                  : () {
                      if (mode == _SeedMode.random) {
                        Navigator.of(ctx).pop(genRandomSeed());
                      } else {
                        parsed = int.tryParse(controller.text.trim());
                        if (parsed != null) {
                          Navigator.of(ctx).pop(parsed);
                        }
                      }
                    },
              child: const Text('Start'),
            ),
          ],
        );
      });
    },
  );
}
