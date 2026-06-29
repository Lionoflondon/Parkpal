import 'package:flutter/material.dart';

import 'parkpal_shell.dart';
import 'parkpal_theme.dart';

class ParkPalApp extends StatelessWidget {
  const ParkPalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ParkPal',
      debugShowCheckedModeBanner: false,
      theme: buildParkPalTheme(),
      home: const ParkPalShell(),
    );
  }
}
