import 'package:flutter/material.dart';
import 'core/database/database_service.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/home_screen.dart';

void main() async {
  // Ensure that plugin services are initialized before running the app
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive CE and open local shopping lists database box
  await DatabaseService.init();

  runApp(const MyApp());
}

/// The root of the application. It dynamically responds to the [themeNotifier]
/// to switch between the Light and Dark Material 3 theme modes.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentThemeMode, _) {
        return MaterialApp(
          title: 'Maranoo Shopping Tracker',
          debugShowCheckedModeBanner: false,

          // Theme configurations
          themeMode: currentThemeMode,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,

          // The Home Screen displaying the dynamic shopping lists
          home: const HomeScreen(),
        );
      },
    );
  }
}
