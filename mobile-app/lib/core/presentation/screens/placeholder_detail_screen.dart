import 'package:flutter/material.dart';

class PlaceholderDetailScreen extends StatelessWidget {
  final String title;

  const PlaceholderDetailScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.build, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('$title Detail Screen', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('This screen is under construction.'),
          ],
        ),
      ),
    );
  }
}
