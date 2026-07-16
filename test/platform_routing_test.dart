import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkpal/app/parkpal_platform_routes.dart';
import 'package:parkpal/app/parkpal_public_shell.dart';
import 'package:parkpal/app/parkpal_shell.dart';

void main() {
  group('ParkPal platform routing', () {
    test('keeps public and authenticated routes on canonical customer paths',
        () {
      expect(ParkPalPlatformRoutes.normalise('/'), '/');
      expect(ParkPalPlatformRoutes.normalise('/dashboard'), '/dashboard');
      expect(ParkPalPlatformRoutes.normalise('/map'), '/map');
      expect(ParkPalPlatformRoutes.normalise('/find'), '/find');
      expect(ParkPalPlatformRoutes.normalise('/iris'), '/iris');
      expect(ParkPalPlatformRoutes.normalise('/settings'), '/settings');
      expect(ParkPalPlatformRoutes.normalise('/unknown'), '/');
    });

    test('does not define forbidden customer subdomains as routes', () {
      final allRoutes = {
        ...ParkPalPlatformRoutes.publicRoutes,
        ...ParkPalPlatformRoutes.appRoutes,
      }.join(' ');

      expect(allRoutes, isNot(contains('app.myparkpal.co.uk')));
      expect(allRoutes, isNot(contains('web.myparkpal.co.uk')));
      expect(allRoutes, isNot(contains('beta.myparkpal.co.uk')));
    });

    test('supports context-aware IRIS route', () {
      expect(ParkPalPlatformRoutes.publicRoutes, contains('/iris'));
      expect(ParkPalPlatformRoutes.appRoutes, contains('/iris'));
    });
  });

  group('ParkPal platform shells', () {
    testWidgets('anonymous public shell shows marketing navigation',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: ParkPalPublicShell(routeName: ParkPalPlatformRoutes.home),
        ),
      );

      expect(find.text('Features'), findsOneWidget);
      expect(find.text('IRIS'), findsOneWidget);
      expect(find.text('Create Account'), findsWidgets);
      expect(find.text('Dashboard'), findsNothing);
    });

    testWidgets('authenticated shell removes marketing navigation',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: ParkPalShell(routeName: ParkPalPlatformRoutes.dashboard),
        ),
      );

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Live Map'), findsOneWidget);
      expect(find.text('Create Account'), findsNothing);
      expect(find.text('Features'), findsNothing);
    });

    testWidgets('mobile shell renders responsive bottom navigation',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: ParkPalShell(routeName: ParkPalPlatformRoutes.find),
        ),
      );

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Find'), findsOneWidget);
    });
  });
}
