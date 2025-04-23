import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_magma/stock_selection_page.dart';
import 'package:http/http.dart' as http;
import 'RegisterPage.dart';
import 'ForgotPasswordPage.dart';
import 'user_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Imports the global key so we can update the global theme
import 'package:flutter_magma/main.dart';

/// Manages the app login screen where users enter their credentials.
/// Makes sure the email format looks right, passwords aren't empty,
/// and displays clear error messages when things go wrong.
/// After successful login, remembers the user's theme choice and takes them to stocks.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  // App color palette - should be moved to theme system eventually
  static const darkGrey = Color(0xFF121212);
  static const textPrimary = Color(0xFFEAEAEA);
  static const textSecondary = Color(0xFFB0B0B0);
  static const accentRed = Color(0xFFFF3B30);

  /// Quick pattern to verify emails have the right format like example??@domain??.com?
  final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Processes the login attempt and handles all possible outcomes:
  /// - Catches empty fields and shows a friendly reminder
  /// - Validates email format before contacting server
  /// - Stores user info when login works (including theme choice)
  /// - Updates app appearance based on user's saved theme
  /// - Shows success message and redirects to main stock screen
  Future<void> loginUser(BuildContext context) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Check if both fields are entered.
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter both email and password."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validates email format
    if (!_emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a valid email."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/auth/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "password": password,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        // Login success.
        // Extract user data from the response making sure backend returns 'theme_preference'
        final userData = data["user"];
        UserState.userEmail = userData["email"];
        // Sets the user theme preference from backend but defaults to dark if missing.
        UserState.themePreference = userData["theme_preference"] ?? "dark";

        // Saves user email locally via SharedPreferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString("userEmail", userData["email"]);

        // Updates the global theme using the global key.
        myAppKey.currentState?.updateTheme(UserState.themePreference == "dark");

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data["message"] ?? "Login successful."),
            backgroundColor: Colors.green,
          ),
        );
        // Navigates to the stock selection page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => StockSelectionPage()),
        );
      } else {
        // Handles backend error messages
        String errorMsg = data["error"] ?? "Login failed. Please try again.";
        if (errorMsg.toLowerCase().contains("invalid credentials")) {
          errorMsg = "Incorrect email or password.";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      // Handles network or other errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Network error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkGrey,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [darkGrey, Color(0xFF1A1A1A)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  const SizedBox(height: 80),
                  const Text(
                    'MAGMA',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'Login',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Email input field
                  TextField(
                    controller: _emailController,
                    style: const TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: const TextStyle(color: textSecondary),
                      prefixIcon: const Icon(Icons.email, color: textSecondary),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: textSecondary, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: textPrimary, width: 2),
                      ),
                      filled: true,
                      fillColor: darkGrey.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Password input field
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(color: textSecondary),
                      prefixIcon: const Icon(Icons.lock, color: textSecondary),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          color: textSecondary,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: textSecondary, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: textPrimary, width: 2),
                      ),
                      filled: true,
                      fillColor: darkGrey.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Login button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => loginUser(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentRed,
                        foregroundColor: textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // Forgot Password link
                  Container(
                    margin: const EdgeInsets.only(top: 16, bottom: 4),
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
                        );
                      },
                      child: const Text(
                        "Forgot Password?",
                        style: TextStyle(
                          color: Color(0xFFB0B0B0),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Navigates to Register page
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const RegisterPage()),
                      );
                    },
                    child: const Text(
                      "Don't have an account? Sign up",
                      style: TextStyle(
                        color: Color(0xFFB0B0B0),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Cleans up the text input controllers when screen closes
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
