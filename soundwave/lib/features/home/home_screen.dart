import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SoundWave')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {}, // TODO: navegar en issue #2
              child: const Text('Buscar'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {}, // TODO: navegar en issue #2
              child: const Text('Reproductor'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {}, // TODO: navegar en issue #2
              child: const Text('Descargas'),
            ),
          ],
        ),
      ),
    );
  }
}
