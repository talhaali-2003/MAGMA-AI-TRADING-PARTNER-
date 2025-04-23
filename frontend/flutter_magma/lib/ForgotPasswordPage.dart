import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'LoginPage.dart';

/// Walks users through the password reset flow in 3 easy steps:
/// 1. Type in email and request a reset code
/// 2. Enter the 6-digit code they received
/// 3. Create a new secure password with live feedback
/// Shows helpful messages at each step so users don't get stuck
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({Key? key}) : super(key: key);

  // Color constants for UI elements
  static const Color darkGrey = Color(0xFF121212);
  static const Color textPrimary = Color(0xFFEAEAEA);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color accentRed = Color(0xFFFF3B30);

  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  // Tracks which screen we're showing (0=email entry, 1=OTP entry, 2=new password)
  int _currentStep = 0;

  // Text input controllers for all the fields we need
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // Controls the eye icon to show/hide passwords
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  // Feedback messages for the user
  String? _errorMessage;
  String? _successMessage;
  bool isLoading = false;

  // Keeps track of remaining time for the OTP (10 minutes total)
  int _secondsRemaining = 600;
  Timer? _timer;

  // Password strength indicators so that all must be true for a valid password
  bool hasUpper = false;
  bool hasLower = false;
  bool hasNumber = false;
  bool hasSpecial = false;
  bool isLongEnough = false;

  /// Kicks off the 10 minute countdown for the reset code
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

  /// Checks password strength in real-time as user types each character
  void _validatePassword(String password) {
    setState(() {
      hasUpper = password.contains(RegExp(r'[A-Z]'));
      hasLower = password.contains(RegExp(r'[a-z]'));
      hasNumber = password.contains(RegExp(r'[0-9]'));
      hasSpecial = password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));
      isLongEnough = password.length >= 8;
    });
  }

  /// Requests a password reset code be sent to user's email
  Future<void> _sendOtp() async {
    setState(() {
      isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final url = Uri.parse('http://10.0.2.2:5000/auth/forgot_password');
    final body = json.encode({"email": _emailController.text.trim()});

    try {
      final response = await http.post(url,
          headers: {"Content-Type": "application/json"}, body: body);
      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        setState(() {
          _currentStep = 1;
          _successMessage = data["message"] ?? "OTP sent successfully to your email.";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_successMessage!), backgroundColor: Colors.green),
        );
        _startTimer();
      } else {
        final errorMsg = data["error"] ?? "Error sending OTP.";
        setState(() {
          _errorMessage = errorMsg;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      final errorMsg = "Network error: $e";
      setState(() {
        _errorMessage = errorMsg;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Generates a fresh reset code if the first one expired or got lost
  Future<void> _resendOtp() async {
    _timer?.cancel();
    await _sendOtp();
  }

  /// Makes sure the code matches before letting them set a new password
  Future<void> _verifyOtp() async {
    setState(() {
      isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    if (_otpController.text.trim().length == 6 && _secondsRemaining > 0) {
      setState(() {
        _currentStep = 2;
      });
    } else {
      final errorMsg = "Invalid or expired OTP. Please try again or resend.";
      setState(() {
        _errorMessage = errorMsg;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
      );
    }
    setState(() {
      isLoading = false;
    });
  }

  /// Finalizes the password reset with the new password and verification code
  Future<void> _resetPassword() async {
    setState(() {
      isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = "Passwords do not match!";
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match!"), backgroundColor: Colors.red),
      );
      return;
    }

    if (!hasUpper || !hasLower || !hasNumber || !hasSpecial || !isLongEnough) {
      setState(() {
        _errorMessage = "Password does not meet complexity requirements.";
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password does not meet complexity requirements."), backgroundColor: Colors.red),
      );
      return;
    }

    final url = Uri.parse('http://10.0.2.2:5000/auth/reset_password');
    final body = json.encode({
      "email": _emailController.text.trim(),
      "otp": _otpController.text.trim(),
      "new_password": _newPasswordController.text,
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
          _successMessage = data["message"] ?? "Password reset successful! Redirecting to login...";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_successMessage!), backgroundColor: Colors.green),
        );
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        });
      } else {
        final errorMsg = data["error"] ?? "Error resetting password.";
        setState(() {
          _errorMessage = errorMsg;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      final errorMsg = "Network error: $e";
      setState(() {
        _errorMessage = errorMsg;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Shows the right screen based on which step of the reset process we're on
  Widget _buildStepContent() {
    if (_currentStep == 0) {
      return _buildEmailStep();
    } else if (_currentStep == 1) {
      return _buildOtpStep();
    } else {
      return _buildNewPasswordStep();
    }
  }

  /// First screen asks for user's email to send the reset code
  Widget _buildEmailStep() {
    return Column(
      children: [
        const SizedBox(height: 20),
        TextField(
          controller: _emailController,
          style: const TextStyle(color: ForgotPasswordPage.textPrimary),
          decoration: InputDecoration(
            labelText: 'Email',
            labelStyle: const TextStyle(color: ForgotPasswordPage.textSecondary),
            prefixIcon: const Icon(Icons.email, color: ForgotPasswordPage.textSecondary),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: ForgotPasswordPage.textSecondary, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: ForgotPasswordPage.textPrimary, width: 2),
            ),
            filled: true,
            fillColor: ForgotPasswordPage.darkGrey.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 20),
        if (_errorMessage != null)
          Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
        if (_successMessage != null)
          Text(_successMessage!, style: const TextStyle(color: Colors.green)),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: isLoading ? null : _sendOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: ForgotPasswordPage.accentRed,
              foregroundColor: ForgotPasswordPage.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 2,
            ),
            child: isLoading
                ? const CircularProgressIndicator(color: ForgotPasswordPage.textPrimary)
                : const Text(
                    'Send OTP',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  /// Second screen lets user enter the 6 digit code from their email
  Widget _buildOtpStep() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Text(
          'Time remaining: $_secondsRemaining seconds',
          style: const TextStyle(color: ForgotPasswordPage.textSecondary),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: ForgotPasswordPage.textPrimary),
          decoration: InputDecoration(
            labelText: '6-Digit OTP',
            labelStyle: const TextStyle(color: ForgotPasswordPage.textSecondary),
            prefixIcon: const Icon(Icons.lock, color: ForgotPasswordPage.textSecondary),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: ForgotPasswordPage.textSecondary, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: ForgotPasswordPage.textPrimary, width: 2),
            ),
            filled: true,
            fillColor: ForgotPasswordPage.darkGrey.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 20),
        if (_errorMessage != null)
          Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
        if (_successMessage != null)
          Text(_successMessage!, style: const TextStyle(color: Colors.green)),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: isLoading ? null : _verifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: ForgotPasswordPage.accentRed,
              foregroundColor: ForgotPasswordPage.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 2,
            ),
            child: isLoading
                ? const CircularProgressIndicator(color: ForgotPasswordPage.textPrimary)
                : const Text(
                    'Verify OTP',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: isLoading ? null : _resendOtp,
          child: const Text(
            'Resend Code',
            style: TextStyle(
              color: ForgotPasswordPage.accentRed,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  /// Password creation with live strength indicators
  Widget _buildNewPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        TextField(
          controller: _newPasswordController,
          obscureText: _obscureNewPassword,
          style: const TextStyle(color: ForgotPasswordPage.textPrimary),
          onChanged: _validatePassword,
          decoration: InputDecoration(
            labelText: 'New Password',
            labelStyle: const TextStyle(color: ForgotPasswordPage.textSecondary),
            prefixIcon: const Icon(Icons.lock, color: ForgotPasswordPage.textSecondary),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureNewPassword ? Icons.visibility : Icons.visibility_off,
                color: ForgotPasswordPage.textSecondary,
              ),
              onPressed: () {
                setState(() {
                  _obscureNewPassword = !_obscureNewPassword;
                });
              },
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: ForgotPasswordPage.textSecondary, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: ForgotPasswordPage.textPrimary, width: 2),
            ),
            filled: true,
            fillColor: ForgotPasswordPage.darkGrey.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 10),
        _buildPasswordRequirement("At least one uppercase letter", hasUpper),
        _buildPasswordRequirement("At least one lowercase letter", hasLower),
        _buildPasswordRequirement("At least one number", hasNumber),
        _buildPasswordRequirement("At least one special character", hasSpecial),
        _buildPasswordRequirement("At least 8 characters", isLongEnough),
        const SizedBox(height: 20),
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          style: const TextStyle(color: ForgotPasswordPage.textPrimary),
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            labelStyle: const TextStyle(color: ForgotPasswordPage.textSecondary),
            prefixIcon: const Icon(Icons.lock, color: ForgotPasswordPage.textSecondary),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                color: ForgotPasswordPage.textSecondary,
              ),
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: ForgotPasswordPage.textSecondary, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: ForgotPasswordPage.textPrimary, width: 2),
            ),
            filled: true,
            fillColor: ForgotPasswordPage.darkGrey.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 20),
        if (_errorMessage != null)
          Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
        if (_successMessage != null)
          Text(_successMessage!, style: const TextStyle(color: Colors.green)),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: isLoading ? null : _resetPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: ForgotPasswordPage.accentRed,
              foregroundColor: ForgotPasswordPage.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 2,
            ),
            child: isLoading
                ? const CircularProgressIndicator(color: ForgotPasswordPage.textPrimary)
                : const Text(
                    'Change Password',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  /// Creates those red/green checkmark items for each password requirement
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
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ForgotPasswordPage.darkGrey,
      appBar: AppBar(
        backgroundColor: ForgotPasswordPage.darkGrey,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ForgotPasswordPage.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Forgot Password',
          style: TextStyle(color: ForgotPasswordPage.textPrimary),
        ),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [ForgotPasswordPage.darkGrey, const Color(0xFF1A1A1A)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: _buildStepContent(),
            ),
          ),
        ),
      ),
    );
  }
}
