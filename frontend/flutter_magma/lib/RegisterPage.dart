import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:http/http.dart' as http;
import 'LoginPage.dart';
import 'RegisterVerificationPage.dart';

/// Creates a new user account with proper security requirements.
/// Watches input fields in real-time to validate email format and
/// password strength, giving immediate visual feedback on requirements.
/// Shows toast messages for both errors and successful registration.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _passwordError;

  // Password strength checklist which updates in real time
  bool hasUpper = false;
  bool hasLower = false;
  bool hasNumber = false;
  bool hasSpecial = false;
  bool isLongEnough = false;

  // Dark theme colors updates to use theme system
  static const darkGrey = Color(0xFF121212);
  static const textPrimary = Color(0xFFEAEAEA);
  static const textSecondary = Color(0xFFB0B0B0);
  static const accentRed = Color(0xFFFF3B30);

  /// Ensures email addresses follow standard format before submission
  final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Checks each password requirement as the user types each character
  void _validatePassword(String password) {
    setState(() {
      hasUpper = password.contains(RegExp(r'[A-Z]'));
      hasLower = password.contains(RegExp(r'[a-z]'));
      hasNumber = password.contains(RegExp(r'[0-9]'));
      hasSpecial = password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));
      isLongEnough = password.length >= 8;
    });
  }

  /// Creates the user account and starts email verification flow:
  /// - Verifies email format looks legitimate
  /// - Confirms password meets all security standards
  /// - Makes sure password and confirmation match exactly
  /// - Shows clear error messages when something's wrong
  /// - Takes user to verification page when successful
  Future<void> _registerUser() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPass = _confirmPasswordController.text;

    // Check if email is valid
    if (email.isEmpty || !_emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a valid email."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if passwords match
    if (password != confirmPass) {
      setState(() {
        _passwordError = "Passwords do not match!";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Passwords do not match!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check password complexity
    if (!hasUpper || !hasLower || !hasNumber || !hasSpecial || !isLongEnough) {
      setState(() {
        _passwordError = "Password does not meet complexity requirements.";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password does not meet complexity requirements."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:5000/auth/register'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "password": password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        // Success code and message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data["message"] ?? "Registration successful"),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate to verification
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RegisterVerificationPage(email: email),
          ),
        );
      } else {
        // Error from backend
        final errorMsg = data["error"] ?? "Registration failed. Please try again.";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      // Network error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Network error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  /// Creates those green checkmarks or red X icons for each password rule
  Widget _buildPasswordRequirement(String text, bool condition) {
    return Row(
      children: [
        Icon(
          condition ? Icons.check_circle : Icons.cancel,
          color: condition ? Colors.green : Colors.red,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(color: condition ? Colors.green : Colors.red),
        ),
      ],
    );
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 80),
                  const Center(
                    child: Text(
                      'Registration',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Email Field
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

                  // Password Field
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: textPrimary),
                    onChanged: _validatePassword,
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
                  const SizedBox(height: 10),

                  // Password Requirements
                  Column(
                    children: [
                      _buildPasswordRequirement("At least one uppercase letter", hasUpper),
                      _buildPasswordRequirement("At least one lowercase letter", hasLower),
                      _buildPasswordRequirement("At least one number", hasNumber),
                      _buildPasswordRequirement("At least one special character", hasSpecial),
                      _buildPasswordRequirement("At least 8 characters", isLongEnough),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Confirm Password Field
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    style: const TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      labelStyle: const TextStyle(color: textSecondary),
                      prefixIcon: const Icon(Icons.lock, color: textSecondary),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                          color: textSecondary,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
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
                  if (_passwordError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _passwordError!,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Terms and Privacy Policy Text
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(color: textSecondary, fontSize: 14),
                        children: [
                          const TextSpan(text: 'By registering, you agree to our '),
                          TextSpan(
                            text: 'Terms of Use',
                            style: const TextStyle(
                              color: accentRed,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      backgroundColor: darkGrey,
                                      title: const Text('Terms of Use',
                                          style: TextStyle(color: textPrimary)),
                                      content: SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Text(
                                              '''Welcome to MAGMA! By using our app, you agree to:

1. Use the app responsibly and legally
2. Not manipulate or abuse the service
3. Respect data usage guidelines
4. Keep your account credentials secure
5. Accept that stock data is for informational purposes only
6. Acknowledge that we are not financial advisors''',
                                              style: TextStyle(color: textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                          child: const Text('Close',
                                              style: TextStyle(color: accentRed)),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: const TextStyle(
                              color: accentRed,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      backgroundColor: darkGrey,
                                      title: const Text('Privacy Policy',
                                          style: TextStyle(color: textPrimary)),
                                      content: SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Text(
                                              '''Your privacy is important to us. Here's how we handle your data:

1. We collect only necessary information
2. Your email is used for authentication only
3. We do not share your data with third parties
4. Your favorites and preferences are stored securely
5. You can request data deletion at any time
6. We use industry-standard security measures''',
                                              style: TextStyle(color: textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                          child: const Text('Close',
                                              style: TextStyle(color: accentRed)),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Register Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _registerUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentRed,
                        foregroundColor: textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Register',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Incase user already has an account
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginPage()),
                        );
                      },
                      child: const Text(
                        "Already have an account? Login",
                        style: TextStyle(color: textSecondary, fontSize: 16),
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
}
