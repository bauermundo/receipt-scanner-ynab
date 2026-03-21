import 'package:flutter/material.dart';
import 'presentation/screens/camera/camera_screen.dart';
import 'presentation/screens/review/review_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/screens/ynab_mapping/ynab_mapping_screen.dart';

class AppRouter {
  AppRouter._();

  static const String camera = '/';
  static const String review = '/review';
  static const String settings = '/settings';
  static const String ynabMapping = '/ynab-mapping';

  static Route<dynamic> generateRoute(RouteSettings route) {
    switch (route.name) {
      case camera:
        return MaterialPageRoute(builder: (_) => const CameraScreen());
      case review:
        return MaterialPageRoute(builder: (_) => const ReviewScreen());
      case settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case ynabMapping:
        return MaterialPageRoute(builder: (_) => const YnabMappingScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('Unknown route: ${route.name}')),
          ),
        );
    }
  }
}
