import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_magma/OnboardingPage.dart';
import 'package:flutter_magma/user_state.dart';

/// Provides app wide access to change the theme dynamically from any screen
/// This key connects to the app's root state, letting other widgets trigger theme changes
final GlobalKey<_MyAppState> myAppKey = GlobalKey<_MyAppState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: "assets/.env");
    debugPrint("✅ .env loaded successfully");
    debugPrint("MarketStack API Key: ${dotenv.env['MARKETSTACK_API_KEY']}");
  } catch (e) {
    debugPrint("❌ Error loading .env: $e");
    debugPrint("MarketStack API Key: ${dotenv.env['MARKETSTACK_API_KEY']}");
  }

  // Sets dark mode as default for first time app users
  // The user can change this later in settings
  if (UserState.themePreference.isEmpty) {
    UserState.themePreference = "dark";
  }

  runApp(MyApp(key: myAppKey));
}

/// Root application widget that controls the global theme system
/// Must be stateful to allow dynamic theme switching during runtime
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Tracks current theme state based on user preference
  // This flag controls which theme (light/dark) is active
  bool isDarkMode = UserState.themePreference == "dark";

  /// Changes app theme instantly when called from anywhere
  /// Updates both local state and persisted user preference
  /// Other screens call this via myAppKey.currentState?.updateTheme(value)
  void updateTheme(bool darkMode) {
    setState(() {
      isDarkMode = darkMode;
      UserState.themePreference = darkMode ? "dark" : "light";
      debugPrint("Global theme updated: isDarkMode = $isDarkMode");
    });
  }

  @override
  Widget build(BuildContext context) {
    // Dark theme definition that matches MAGMA's signature dark look
    // Uses dark grays with red accent colors
    final ThemeData darkTheme = ThemeData(
      brightness: Brightness.dark,
      primaryColor: const Color(0xFFE31B23),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFE31B23),       // Your primary red color
        secondary: Color(0xFFFF3B30),     // Accent red
        background: Color(0xFF121212),    // Dark grey
        surface: Color(0xFF1A1A1A),       // Darker grey
        onPrimary: Color(0xFFEAEAEA),
        onSecondary: Color(0xFFEAEAEA),
        onBackground: Color(0xFFEAEAEA),
        onSurface: Color(0xFFEAEAEA),
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      // Explicitly set canvasColor for dark mode so it's not a lighter default
      canvasColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF121212),
        foregroundColor: Color(0xFFEAEAEA),
      ),
      cardColor: const Color(0xFF1A1A1A),
      dividerColor: const Color(0xFFB0B0B0),
      useMaterial3: true,
    );

    // Light theme alternative that uses white backgrounds with same red accents
    // Provides better readability in bright environments
    final ThemeData lightTheme = ThemeData(
      brightness: Brightness.light,
      primaryColor: const Color(0xFFE31B23),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFFE31B23),
        secondary: Color(0xFFFF3B30),
        background: Colors.white,
        surface: Colors.white,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onBackground: Colors.black,
        onSurface: Colors.black,
      ),
      scaffoldBackgroundColor: Colors.white,
      // Explicitly set canvasColor for light mode too
      canvasColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      useMaterial3: true,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MAGMA',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const OnboardingPage(),
    );
  }
}
