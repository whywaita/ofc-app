import 'package:flutter/material.dart';
import 'game_screen.dart';

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
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GameScreen()),
            );
          },
          child: const Text('Practice'),
        ),
      ),
    );
  }
}
