import 'package:flutter/material.dart';

import '../../app/parkpal_theme.dart';

class ScanComingSoonScreen extends StatelessWidget {
  const ScanComingSoonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ParkPalColors.midnight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  gradient: parkPalIridescentBorderGradient(),
                  borderRadius: BorderRadius.circular(34),
                ),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: ParkPalColors.navy.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: ParkPalColors.glassBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 180,
                        decoration: BoxDecoration(
                          color: ParkPalColors.glassWhite,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: ParkPalColors.glassBorder),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.document_scanner_outlined,
                            color: ParkPalColors.irisCyan,
                            size: 54,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'IRIS sign scanning is coming soon',
                        style: ParkPalText.display(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'For now, search a road or location and ParkPal will check it against verified signs, roads, zones, council intelligence, and ParkPal Connect evidence.',
                        style: ParkPalText.body(
                          color: Colors.white.withValues(alpha: 0.74),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 22),
                      for (final label in const [
                        'Image capture',
                        'Reading sign text',
                        'Matching zone & council rules',
                        'Calculating move-by time',
                      ])
                        _FutureCapability(label: label),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Search manually instead'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FutureCapability extends StatelessWidget {
  const _FutureCapability({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(
            Icons.lock_clock_outlined,
            color: ParkPalColors.irisBlue,
            size: 18,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: ParkPalText.body(
              color: Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
