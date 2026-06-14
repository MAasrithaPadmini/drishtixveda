import 'package:flutter/material.dart';

class StockDetailScreen extends StatelessWidget {
  final String symbol;

  const StockDetailScreen({super.key, required this.symbol});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(symbol)),
      body: Center(
        child: Text(
          "Showing details for $symbol 📊",
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}