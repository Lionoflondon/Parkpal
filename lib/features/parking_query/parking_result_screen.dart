import 'package:flutter/material.dart';

import 'parking_home_screen.dart';
import 'parking_lookup_result.dart';

class ParkingResultScreen extends StatelessWidget {
  const ParkingResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Parking Result',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        const Text(
          'This screen will show the latest parking check result once the first real rule flow is connected.',
        ),
        const SizedBox(height: 20),
        ParkingResultCard(result: ParkingLookupResult.unknown()),
      ],
    );
  }
}
