import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
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

/// Creates a platform-adaptive route for better PopScope support
/// iOS uses CupertinoPageRoute for proper swipe-back gesture handling
Route<T> _adaptiveRoute<T>(WidgetBuilder builder) {
  if (!kIsWeb && Platform.isIOS) {
    return CupertinoPageRoute<T>(builder: builder);
  }
  return MaterialPageRoute<T>(builder: builder);
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  WildMode _wildMode = WildMode.none;

  GameOptions get _options => GameOptions(wildMode: _wildMode);

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
              // Wild mode selector
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'Game Mode',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<WildMode>(
                      segments: const [
                        ButtonSegment<WildMode>(
                          value: WildMode.none,
                          label: Text('Standard'),
                        ),
                        ButtonSegment<WildMode>(
                          value: WildMode.deuces,
                          label: Text('Deuces'),
                        ),
                        ButtonSegment<WildMode>(
                          value: WildMode.joker,
                          label: Text('Joker'),
                        ),
                      ],
                      selected: {_wildMode},
                      onSelectionChanged: (s) =>
                          setState(() => _wildMode = s.first),
                    ),
                  ),
                ],
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
                      _adaptiveRoute(
                          (_) => GameScreen(seed: seed, options: _options)),
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
                      _adaptiveRoute(
                          (_) => PassPlayScreen(options: _options)),
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
