import 'package:flutter/material.dart';

class ParkPalPlatformRoutes {
  const ParkPalPlatformRoutes._();

  static const home = '/';
  static const features = '/features';
  static const atlas = '/atlas';
  static const pioneer = '/pioneer';
  static const business = '/business';
  static const support = '/support';
  static const signIn = '/sign-in';
  static const createAccount = '/create-account';

  static const dashboard = '/dashboard';
  static const map = '/map';
  static const find = '/find';
  static const iris = '/iris';
  static const trips = '/trips';
  static const vehicles = '/vehicles';
  static const savedPlaces = '/saved-places';
  static const reports = '/reports';
  static const appPioneer = '/app-pioneer';
  static const notifications = '/notifications';
  static const account = '/account';
  static const settings = '/settings';

  static const publicRoutes = {
    home,
    features,
    iris,
    atlas,
    pioneer,
    business,
    support,
    signIn,
    createAccount,
  };

  static const appRoutes = {
    dashboard,
    map,
    find,
    iris,
    trips,
    vehicles,
    savedPlaces,
    reports,
    appPioneer,
    notifications,
    account,
    settings,
  };

  static String normalise(String? routeName) {
    final route = routeName == null || routeName.isEmpty ? home : routeName;
    final withoutQuery = route.split('?').first;
    if (withoutQuery == '/iris') return iris;
    if (withoutQuery == '/pioneer') return pioneer;
    if (publicRoutes.contains(withoutQuery) ||
        appRoutes.contains(withoutQuery)) {
      return withoutQuery;
    }
    return home;
  }

  static bool isAppRoute(String? routeName) {
    return appRoutes.contains(normalise(routeName));
  }

  static bool isPublicRoute(String? routeName) {
    return publicRoutes.contains(normalise(routeName));
  }

  static PageRoute<void> routeTo(Widget child, RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => child,
    );
  }
}
