import 'package:flutter/material.dart';

import 'parkpal_shell.dart';

class ParkPalApp extends StatelessWidget {
  const ParkPalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ParkPal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF145A32)),
        useMaterial3: true,
      ),
      home: const ParkPalShell(),
    );
  }
}
