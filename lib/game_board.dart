import 'package:flutter/material.dart';

class GameBoard extends StatefulWidget {
  const GameBoard({super.key});

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> {
  static const int boardSize = 4;
  List<List<FruitTile?>> board = List.generate(
    boardSize,
    (_) => List.generate(boardSize, (_) => null),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      child: GridView.builder(
        shrinkWrap: true,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: boardSize,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: boardSize * boardSize,
        itemBuilder: (context, index) {
          final row = index ~/ boardSize;
          final col = index % boardSize;
          return Container(
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: board[row][col],
          );
        },
      ),
    );
  }
}

class FruitTile extends StatelessWidget {
  final String fruitType;
  final int level;

  const FruitTile({
    super.key,
    required this.fruitType,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          fruitType,
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }
} 