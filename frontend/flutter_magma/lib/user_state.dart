import 'package:flutter/material.dart';

/// Maintains global user settings and preferences across the entire app.
/// Uses the singleton pattern to ensure consistent state everywhere.
/// Provides theme settings that control the app's appearance.
class UserState {
  // Implements the singleton pattern with private constructor
  // This ensures only one instance exists throughout the app
  UserState._privateConstructor();
  static final UserState _instance = UserState._privateConstructor();

  factory UserState() {
    return _instance;
  }

  // User identity information shared across screens
  static String userEmail = "user@example.com";
  static String userName = "";
  static int userId = 0;

  // Controls app-wide dark/light theme setting
  // Value syncs with backend user preferences
  // Used by widgets to determine colors dynamically
  static String themePreference = "dark";
  
  // Convenience getter to check dark mode status
  static bool get isDarkMode => themePreference == "dark";
  
  // Quick access to commonly used colors based on current theme
  static Color get textPrimary => isDarkMode ? const Color(0xFFEAEAEA) : const Color(0xFF121212);
  static Color get textSecondary => isDarkMode ? const Color(0xFFB0B0B0) : const Color(0xFF757575);
  static Color get background => isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
  static Color get cardBackground => isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
}
