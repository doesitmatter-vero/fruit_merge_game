import 'package:flutter/material.dart';
import 'game_screen.dart';

void main() {
  runApp(const FruitMergeGame());
}

class FruitMergeGame extends StatelessWidget {
  const FruitMergeGame({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meyve Birleştirme',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: const GameScreen(),
    );
  }
} 