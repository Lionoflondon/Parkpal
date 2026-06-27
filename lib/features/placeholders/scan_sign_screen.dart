import 'package:flutter/material.dart';

class ScanSignScreen extends StatelessWidget {
  const ScanSignScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Scan Sign',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Sign scanning and upload will be added here. OCR is not implemented yet.',
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: null,
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('Scan or upload sign — coming soon'),
        ),
      ],
    );
  }
}
