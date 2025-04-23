import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'LoginPage.dart';

/// Completes the account setup by validating the verification code.
/// Provides a simple 4 digit input field with countdown timer and
/// helpful feedback messages based on verification success or failure.
class RegisterVerificationPage extends StatefulWidget {
  final String email;
  const RegisterVerificationPage({Key? key, required this.email}) : super(key: key);

  // UI color scheme will be replaced by theme system
  static const darkGrey = Color(0xFF121212);
  static const textPrimary = Color(0xFFEAEAEA);
  static const textSecondary = Color(0xFFB0B0B0);
  static const accentRed = Color(0xFFFF3B30);

  @override
  State<RegisterVerificationPage> createState() => _RegisterVerificationPageState();
}

class _RegisterVerificationPageState extends State<RegisterVerificationPage> {
  final TextEditingController _codeController = TextEditingController();
  bool isLoading = false;
  String? errorMessage;
  String? successMessage;

  // Tracks the remaining time before code expires (10 minutes)
  int _secondsRemaining = 600;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  /// Begins the 10 minute countdown for code validity
  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _secondsRemaining = 600;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        timer.cancel();
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  /// Validates the entered code against user's email record
  Future<void> _verifyCode() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      successMessage = null;
    });
    final url = Uri.parse('http://10.0.2.2:5000/auth/verify_account');
    final body = json.encode({
      "email": widget.email.trim(),
      "code": _codeController.text.trim()
    });
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        setState(() {
          successMessage = data["message"] ?? "Account verified successfully! Redirecting...";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage!), backgroundColor: Colors.green),
        );
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        });
      } else {
        final err = data["error"] ?? "Invalid code. Please try again.";
        setState(() {
          errorMessage = err;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      final err = "Network error: $e";
      setState(() {
        errorMessage = err;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Gets a fresh verification code if the original expired
  Future<void> _resendCode() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      successMessage = null;
    });
    final url = Uri.parse('http://10.0.2.2:5000/auth/resend_verification');
    final body = json.encode({"email": widget.email.trim()});
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        setState(() {
          successMessage = data["message"] ?? "A new 4-digit code has been sent to your email.";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage!), backgroundColor: Colors.green),
        );
        _startTimer();
      } else {
        final err = data["error"] ?? "Error resending code.";
        setState(() {
          errorMessage = err;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      final err = "Network error: $e";
      setState(() {
        errorMessage = err;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RegisterVerificationPage.darkGrey,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [RegisterVerificationPage.darkGrey, Color(0xFF1A1A1A)],
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
                    'Verify Account',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: RegisterVerificationPage.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'A 4-digit code has been sent to your email.\nTime remaining: $_secondsRemaining seconds',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: RegisterVerificationPage.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: RegisterVerificationPage.textPrimary),
                    decoration: InputDecoration(
                      labelText: '4-Digit Code',
                      labelStyle: const TextStyle(color: RegisterVerificationPage.textSecondary),
                      prefixIcon: const Icon(Icons.lock, color: RegisterVerificationPage.textSecondary),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: RegisterVerificationPage.textSecondary, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: RegisterVerificationPage.textPrimary, width: 2),
                      ),
                      filled: true,
                      fillColor: RegisterVerificationPage.darkGrey.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (errorMessage != null)
                    Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                  if (successMessage != null)
                    Text(successMessage!, style: const TextStyle(color: Colors.green)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _verifyCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RegisterVerificationPage.accentRed,
                        foregroundColor: RegisterVerificationPage.textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 2,
                      ),
                      child: isLoading
                          ? const CircularProgressIndicator(color: RegisterVerificationPage.textPrimary)
                          : const Text(
                              'Verify',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: isLoading ? null : _resendCode,
                    child: const Text(
                      'Resend Code',
                      style: TextStyle(
                        color: RegisterVerificationPage.accentRed,
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
}
