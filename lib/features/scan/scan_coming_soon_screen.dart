import 'package:flutter/material.dart';

import '../../app/parkpal_theme.dart';
import '../sign_capture/sign_capture_screen.dart';

class ScanComingSoonScreen extends StatelessWidget {
  const ScanComingSoonScreen({this.onSearchManually, super.key});

  final VoidCallback? onSearchManually;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ParkPalColors.midnight,
      body: SafeArea(
        child: Stack(
          children: [
            const _ScanBackdrop(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: onSearchManually ??
                            () {
                              if (Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              }
                            },
                        icon: const Icon(Icons.close_rounded),
                        color: Colors.white,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: ParkPalColors.glassBorder),
                        ),
                        child: Text(
                          'IRIS INSPECTOR',
                          style: ParkPalText.mono(
                            color: ParkPalColors.irisCyan,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      gradient: parkPalIridescentBorderGradient(),
                      borderRadius: BorderRadius.circular(38),
                      boxShadow: [
                        BoxShadow(
                          color: ParkPalColors.irisBlue.withValues(alpha: 0.22),
                          blurRadius: 38,
                          offset: const Offset(0, 22),
                        ),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: ParkPalColors.navy.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(color: ParkPalColors.glassBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _ScanFrame(),
                          const SizedBox(height: 24),
                          Text(
                            'IRIS sign intelligence',
                            style: ParkPalText.display(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Report signs with measured GPS, search verified restrictions, and let Atlas combine the evidence ParkPal already holds.',
                            style: ParkPalText.body(
                              color: Colors.white.withValues(alpha: 0.74),
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 22),
                          const _ScanCapability(
                            label: 'GPS sign reports',
                            state: 'Live',
                            active: true,
                          ),
                          const _ScanCapability(
                            label: 'Manual restriction search',
                            state: 'Live',
                            active: true,
                          ),
                          const _ScanCapability(
                            label: 'Matching zone & council rules',
                            state: 'Live',
                            active: true,
                          ),
                          const _ScanCapability(
                            label: 'Automatic sign interpretation',
                            state: 'Secured',
                            active: false,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const SignCaptureScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add_a_photo_rounded),
                            label: const Text('Report a sign'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: onSearchManually ??
                                () {
                                  if (Navigator.of(context).canPop()) {
                                    Navigator.of(context).pop();
                                  }
                                },
                            icon: const Icon(Icons.search_rounded),
                            label: const Text('Search manually'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: ParkPalColors.glassBorder),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _ScanFramePainter()),
          ),
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: ParkPalColors.midnight.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: ParkPalColors.irisCyan),
              ),
              child: const Icon(
                Icons.center_focus_strong_rounded,
                color: ParkPalColors.irisCyan,
                size: 42,
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: parkPalIridescentBorderGradient(),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanCapability extends StatelessWidget {
  const _ScanCapability({
    required this.label,
    required this.state,
    required this.active,
  });

  final String label;
  final String state;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? ParkPalColors.safeGreen : ParkPalColors.irisBlue;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              active ? Icons.check_rounded : Icons.lock_rounded,
              color: color,
              size: 17,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: ParkPalText.body(
                color: Colors.white.withValues(alpha: 0.82),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            state,
            style: ParkPalText.mono(
              color: Colors.white.withValues(alpha: 0.52),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanBackdrop extends StatelessWidget {
  const _ScanBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -120,
          right: -110,
          child: _Orb(
            color: ParkPalColors.irisBlue.withValues(alpha: 0.22),
            size: 300,
          ),
        ),
        Positioned(
          bottom: -140,
          left: -120,
          child: _Orb(
            color: ParkPalColors.safeGreen.withValues(alpha: 0.2),
            size: 300,
          ),
        ),
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1;

    for (var i = 1; i < 4; i++) {
      final dx = size.width * i / 4;
      canvas.drawLine(Offset(dx, 18), Offset(dx, size.height - 18), paint);
    }
    for (var i = 1; i < 3; i++) {
      final dy = size.height * i / 3;
      canvas.drawLine(Offset(18, dy), Offset(size.width - 18, dy), paint);
    }

    final cornerPaint = Paint()
      ..color = ParkPalColors.irisCyan
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const inset = 24.0;
    const length = 30.0;
    canvas.drawLine(const Offset(inset, inset),
        const Offset(inset + length, inset), cornerPaint);
    canvas.drawLine(const Offset(inset, inset),
        const Offset(inset, inset + length), cornerPaint);
    canvas.drawLine(Offset(size.width - inset, inset),
        Offset(size.width - inset - length, inset), cornerPaint);
    canvas.drawLine(Offset(size.width - inset, inset),
        Offset(size.width - inset, inset + length), cornerPaint);
    canvas.drawLine(Offset(inset, size.height - inset),
        Offset(inset + length, size.height - inset), cornerPaint);
    canvas.drawLine(Offset(inset, size.height - inset),
        Offset(inset, size.height - inset - length), cornerPaint);
    canvas.drawLine(Offset(size.width - inset, size.height - inset),
        Offset(size.width - inset - length, size.height - inset), cornerPaint);
    canvas.drawLine(Offset(size.width - inset, size.height - inset),
        Offset(size.width - inset, size.height - inset - length), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
