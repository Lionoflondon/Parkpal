import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'parkpal_auth_service.dart';
import 'parkpal_platform_routes.dart';
import 'parkpal_public_shell.dart';
import 'parkpal_shell.dart';
import 'parkpal_theme.dart';

class ParkPalApp extends StatelessWidget {
  const ParkPalApp({
    this.authService,
    super.key,
  });

  final ParkPalAuthService? authService;

  @override
  Widget build(BuildContext context) {
    final service = authService ?? ParkPalAuthService();

    return MaterialApp(
      title: 'ParkPal',
      debugShowCheckedModeBanner: false,
      theme: buildParkPalTheme(),
      initialRoute: ParkPalPlatformRoutes.normalise(Uri.base.path),
      onGenerateRoute: (settings) {
        final routeName = ParkPalPlatformRoutes.normalise(settings.name);
        return ParkPalPlatformRoutes.routeTo(
          _ParkPalPlatformGate(routeName: routeName, authService: service),
          RouteSettings(name: routeName),
        );
      },
    );
  }
}

class _ParkPalPlatformGate extends StatelessWidget {
  const _ParkPalPlatformGate({
    required this.routeName,
    required this.authService,
  });

  final String routeName;
  final ParkPalAuthService authService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authService.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _PlatformLoadingScreen();
        }

        final user = snapshot.data;
        if (user == null) {
          return ParkPalPublicShell(
            routeName: routeName,
            authService: authService,
          );
        }

        return ParkPalShell(
          routeName: ParkPalPlatformRoutes.isAppRoute(routeName)
              ? routeName
              : ParkPalPlatformRoutes.dashboard,
        );
      },
    );
  }
}

class _PlatformLoadingScreen extends StatelessWidget {
  const _PlatformLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ParkPalColors.cream,
              ParkPalColors.mint50,
              ParkPalColors.porcelain,
            ],
          ),
        ),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
