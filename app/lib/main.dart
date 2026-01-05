import 'package:flutter/material.dart';
import 'package:ofc_app_core/features/game/domain/game_options.dart';
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
      // Optimize responsive design for web
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isDeucesWild = false;

  GameOptions get _options =>
      _isDeucesWild ? GameOptions.deucesWild : GameOptions.standard;

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive layout
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('OFCP'),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isSmallScreen ? double.infinity : 600,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 16 : 32,
            vertical: 16,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo area
              Icon(
                Icons.casino,
                size: isSmallScreen ? 80 : 100,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                'Open Face Chinese Poker',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: isSmallScreen ? 20 : 24,
                    ),
              ),
              const SizedBox(height: 32),
              // Deuces Wild toggle
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 16,
                  vertical: isSmallScreen ? 8 : 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.style,
                          size: isSmallScreen ? 20 : 24,
                          color: _isDeucesWild
                              ? Theme.of(context).primaryColor
                              : Colors.grey,
                        ),
                        SizedBox(width: isSmallScreen ? 8 : 12),
                        Text(
                          'Deuces Wild',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: _isDeucesWild,
                      onChanged: (v) => setState(() => _isDeucesWild = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Button area
              SizedBox(
                height: isSmallScreen ? 50 : 56,
                child: ElevatedButton(
                  onPressed: () async {
                    final seed = await _chooseSeed(context);
                    if (seed == null) return; // Canceled
                    // Start practice with the selected seed
                    // The seed is passed to GameScreen and displayed on the screen/result screen
                    // ignore: use_build_context_synchronously
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) =>
                              GameScreen(seed: seed, options: _options)),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Practice',
                    style: TextStyle(fontSize: isSmallScreen ? 16 : 18),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: isSmallScreen ? 50 : 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => PassPlayScreen(options: _options)),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Pass & Play (A/B)',
                    style: TextStyle(fontSize: isSmallScreen ? 16 : 18),
                  ),
                ),
              ),
            ],
          ),
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

  // Adjust dialog size for mobile devices
  final screenSize = MediaQuery.of(context).size;
  final isSmallScreen = screenSize.width < 600;

  return showDialog<int>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setState) {
        final customValid = int.tryParse(controller.text.trim()) != null;
        return AlertDialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 20 : 40,
            vertical: 24,
          ),
          contentPadding: EdgeInsets.fromLTRB(
            isSmallScreen ? 20 : 24,
            20,
            isSmallScreen ? 20 : 24,
            0,
          ),
          title: const Text('Choose Practice Seed'),
          content: SizedBox(
            width: isSmallScreen ? double.maxFinite : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<_SeedMode>(
                  segments: const [
                    ButtonSegment<_SeedMode>(
                        value: _SeedMode.random,
                        label: Text('Random'),
                        icon: Icon(Icons.shuffle)),
                    ButtonSegment<_SeedMode>(
                        value: _SeedMode.custom,
                        label: Text('Specify'),
                        icon: Icon(Icons.edit)),
                  ],
                  selected: {mode},
                  onSelectionChanged: (s) => setState(() => mode = s.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  enabled: mode == _SeedMode.custom,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Seed (integer)'),
                  onChanged: (_) => setState(() {}),
                ),
                if (mode == _SeedMode.custom &&
                    controller.text.isNotEmpty &&
                    !customValid)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
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
