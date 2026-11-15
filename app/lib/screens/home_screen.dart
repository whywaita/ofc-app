import 'package:flutter/material.dart';
import 'package:ofc_app_core/ofc_core.dart';

import '../utils/navigation_utils.dart';
import '../widgets/seed_dialog.dart';
import 'pass_play_screen.dart';
import 'practice_screen.dart';

class OfcApp extends StatelessWidget {
  const OfcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OFCP',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Mode selection: the wild-card variant, then Practice or Pass & Play.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  WildMode _wildMode = WildMode.none;

  GameOptions get _options => GameOptions(wildMode: _wildMode);

  Future<void> _startPractice() async {
    final navigator = Navigator.of(context);
    final seed = await showSeedDialog(context);
    if (seed == null) return;
    navigator.push(
        adaptiveRoute((_) => PracticeScreen(seed: seed, options: _options)));
  }

  void _startPassPlay() {
    Navigator.of(context)
        .push(adaptiveRoute((_) => PassPlayScreen(options: _options)));
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final buttonStyle = ElevatedButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
    final buttonText = TextStyle(fontSize: compact ? 16 : 18);

    return Scaffold(
      appBar: AppBar(title: const Text('OFCP'), centerTitle: true),
      body: Center(
        child: Container(
          constraints:
              BoxConstraints(maxWidth: compact ? double.infinity : 600),
          padding:
              EdgeInsets.symmetric(horizontal: compact ? 16 : 32, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.casino,
                  size: compact ? 80 : 100,
                  color: Theme.of(context).primaryColor),
              const SizedBox(height: 24),
              Text(
                'Open Face Chinese Poker',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontSize: compact ? 20 : 24),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'Game Mode',
                  style: TextStyle(
                    fontSize: compact ? 12 : 14,
                    // shade600 measured 4.39:1 on this background, just under WCAG AA (4.5:1).
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SegmentedButton<WildMode>(
                segments: const [
                  ButtonSegment(value: WildMode.none, label: Text('Standard')),
                  ButtonSegment(value: WildMode.deuces, label: Text('Deuces')),
                  ButtonSegment(value: WildMode.joker, label: Text('Joker')),
                ],
                selected: {_wildMode},
                onSelectionChanged: (s) => setState(() => _wildMode = s.first),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: compact ? 50 : 56,
                child: ElevatedButton(
                  onPressed: _startPractice,
                  style: buttonStyle,
                  child: Text('Practice', style: buttonText),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: compact ? 50 : 56,
                child: ElevatedButton(
                  onPressed: _startPassPlay,
                  style: buttonStyle,
                  child: Text('Pass & Play (A/B)', style: buttonText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
