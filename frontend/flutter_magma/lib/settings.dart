import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_magma/LoginPage.dart';
import 'package:flutter_magma/main.dart'; // For myAppKey
import 'widgets/appbar.dart';
import 'user_state.dart';

/// Centralizes all user preferences and account management options in one place.
/// Lets users view their profile, update credentials, switch themes,
/// and access help resources through a clean interface.
/// Provides immediate visual feedback for all actions taken.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late String currentEmail;
  // Controls the theme toggle switch position
  // Must stay in sync with the global theme preference
  bool isDark = true; // Initialized from UserState in initState

  @override
  void initState() {
    super.initState();
    currentEmail = UserState.userEmail;
    // Syncs the toggle switch with the currently active theme
    // This ensures the UI matches the actual app appearance
    isDark = UserState.themePreference == "dark";
  }

  /// Persists theme choice to user's account in the database
  /// Updates both local app appearance and backend user record
  /// Called whenever the theme toggle switch is flipped
  Future<void> _updateThemePreference(String newPreference) async {
    try {
      // Uses the '/auth' prefix as per backend routes.
      final response = await http.post(
        Uri.parse("http://10.0.2.2:5000/auth/change_theme"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": currentEmail,
          "theme_preference": newPreference,
        }),
      );
      if (response.statusCode == 200) {
        debugPrint("Theme preference updated successfully in backend.");
      } else {
        debugPrint("Error updating theme preference: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error updating theme preference: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Retrieve dynamic theme values.
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accentColor = colorScheme.secondary;
    final dividerColor = theme.dividerColor;
    final cardColor = theme.cardColor.withOpacity(0.5);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Settings",
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.scaffoldBackgroundColor,
              theme.canvasColor,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Profile section with logo and email.
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        color: theme.canvasColor,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.asset(
                          'assets/images/Magma.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      currentEmail,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              // Account settings section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 12),
                      child: Text(
                        "Account Settings",
                        style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    _buildSettingsOption(
                      context,
                      title: "Change Email",
                      icon: Icons.email,
                      onTap: () => _showChangeEmailDialog(context),
                    ),
                    Divider(color: dividerColor, height: 1, thickness: 0.5),
                    _buildSettingsOption(
                      context,
                      title: "Change Password",
                      icon: Icons.lock,
                      onTap: () => _showChangePasswordDialog(context),
                    ),
                    Divider(color: dividerColor, height: 1, thickness: 0.5),
                    _buildSettingsOption(
                      context,
                      title: "Delete Account",
                      icon: Icons.delete_forever,
                      onTap: () => _showDeleteAccountDialog(context),
                    ),
                    // Theme toggle option through sliding button
                    Divider(color: dividerColor, height: 1, thickness: 0.5),
                    ListTile(
                      leading: Icon(Icons.brightness_6, color: accentColor),
                      title: Text(
                        "Theme",
                        style: theme.textTheme.bodyMedium,
                      ),
                      trailing: Switch(
                        value: isDark,
                        onChanged: (bool value) async {
                          setState(() {
                            isDark = value;
                          });
                          // Updates the global theme
                          myAppKey.currentState?.updateTheme(value);
                          // Updates backend preference
                          await _updateThemePreference(value ? "dark" : "light");
                          // Shows a confirmation message based on the new value
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Theme changed to ${value ? "Dark" : "Light"} mode."),
                              backgroundColor: accentColor,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // About section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 12),
                      child: Text(
                        "Information",
                        style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    _buildSettingsOption(
                      context,
                      title: "About MAGMA",
                      icon: Icons.info,
                      onTap: () => _showAboutDialog(context),
                    ),
                    _buildSettingsOption(
                      context,
                      title: "Send Feedback",
                      icon: Icons.feedback_outlined,
                      onTap: () => _showFeedbackDialog(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              // Logout button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: dividerColor),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.logout),
                        label: const Text(
                          "Logout",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginPage()),
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: theme.scaffoldBackgroundColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Theme(
        data: theme.copyWith(canvasColor: theme.canvasColor),
        child: const AppBarWidget(selectedIndex: 3),
      ),
    );
  }

  // Reusable settings option widget
  Widget _buildSettingsOption(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.secondary),
      title: Text(title, style: theme.textTheme.bodyMedium),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: theme.dividerColor),
      onTap: onTap,
    );
  }

  // For password complexity checks
  Widget _buildPasswordRequirement(String text, bool condition) {
    return Row(
      children: [
        Icon(condition ? Icons.check_circle : Icons.cancel, color: condition ? Colors.green : Colors.red, size: 16),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: condition ? Colors.green : Colors.red, fontSize: 12)),
      ],
    );
  }

  /// Presents email change form with verification process
  void _showChangeEmailDialog(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final newEmailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.canvasColor,
        title: Text("Change Email", style: theme.textTheme.titleMedium),
        content: TextField(
          controller: newEmailController,
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            labelText: "New Email",
            labelStyle: theme.textTheme.bodySmall,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: theme.dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: colorScheme.secondary),
            ),
            filled: true,
            fillColor: theme.scaffoldBackgroundColor,
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: theme.textTheme.bodyMedium),
          ),
          ElevatedButton(
            onPressed: () async {
              final newEmail = newEmailController.text.trim();
              if (newEmail.isEmpty) return;
              final url = Uri.parse('http://10.0.2.2:5000/auth/change_email_request');
              final response = await http.post(
                url,
                headers: {"Content-Type": "application/json"},
                body: json.encode({
                  "current_email": currentEmail,
                  "new_email": newEmail,
                }),
              );
              final data = json.decode(response.body);
              if (response.statusCode == 200) {
                Navigator.pop(context);
                _showEmailVerificationDialog(context, newEmail);
              } else {
                final errorMsg = data["error"] ?? "Error sending verification code";
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: colorScheme.secondary),
            child: Text("Save", style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  /// Confirms email ownership with a secure verification code
  void _showEmailVerificationDialog(BuildContext context, String newEmail) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.canvasColor,
        title: Text("Verify New Email", style: theme.textTheme.titleMedium),
        content: TextField(
          controller: codeController,
          keyboardType: TextInputType.number,
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            labelText: "4-Digit Code",
            labelStyle: theme.textTheme.bodySmall,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: theme.dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: colorScheme.secondary),
            ),
            filled: true,
            fillColor: theme.scaffoldBackgroundColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: theme.textTheme.bodyMedium),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.isEmpty) return;
              final url = Uri.parse('http://10.0.2.2:5000/auth/change_email_verify');
              final response = await http.post(
                url,
                headers: {"Content-Type": "application/json"},
                body: json.encode({
                  "current_email": currentEmail,
                  "code": code,
                }),
              );
              final data = json.decode(response.body);
              if (response.statusCode == 200) {
                // Updates local email state on success
                UserState.userEmail = newEmail;
                setState(() {
                  currentEmail = newEmail;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Email changed successfully."), backgroundColor: Colors.green),
                );
              } else {
                final errorMsg = data["error"] ?? "Invalid code. Please try again.";
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: colorScheme.secondary),
            child: Text("Verify", style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  /// Guides users through secure password update with validation
  void _showChangePasswordDialog(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        bool obscureOld = true;
        bool obscureNew = true;
        bool obscureConfirm = true;

        bool hasUpper = false;
        bool hasLower = false;
        bool hasNumber = false;
        bool hasSpecial = false;
        bool isLongEnough = false;

        String? errorText;

        void validateNewPassword(String password) {
          hasUpper = password.contains(RegExp(r'[A-Z]'));
          hasLower = password.contains(RegExp(r'[a-z]'));
          hasNumber = password.contains(RegExp(r'[0-9]'));
          hasSpecial = password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));
          isLongEnough = password.length >= 8;
        }

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: theme.canvasColor,
              title: Text("Change Password", style: theme.textTheme.titleMedium),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Old password
                    TextField(
                      controller: oldPasswordController,
                      obscureText: obscureOld,
                      style: theme.textTheme.bodyMedium,
                      decoration: InputDecoration(
                        labelText: "Old Password",
                        labelStyle: theme.textTheme.bodySmall,
                        prefixIcon: Icon(Icons.lock, color: colorScheme.secondary),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureOld ? Icons.visibility : Icons.visibility_off,
                            color: theme.iconTheme.color,
                          ),
                          onPressed: () => setState(() => obscureOld = !obscureOld),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: theme.dividerColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: colorScheme.secondary),
                        ),
                        filled: true,
                        fillColor: theme.scaffoldBackgroundColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // New password
                    TextField(
                      controller: newPasswordController,
                      obscureText: obscureNew,
                      style: theme.textTheme.bodyMedium,
                      onChanged: (password) {
                        setState(() {
                          validateNewPassword(password);
                        });
                      },
                      decoration: InputDecoration(
                        labelText: "New Password",
                        labelStyle: theme.textTheme.bodySmall,
                        prefixIcon: Icon(Icons.lock, color: colorScheme.secondary),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNew ? Icons.visibility : Icons.visibility_off,
                            color: theme.iconTheme.color,
                          ),
                          onPressed: () => setState(() => obscureNew = !obscureNew),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: theme.dividerColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: colorScheme.secondary),
                        ),
                        filled: true,
                        fillColor: theme.scaffoldBackgroundColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Password requirements
                    Column(
                      children: [
                        _buildPasswordRequirement("At least one uppercase letter", hasUpper),
                        _buildPasswordRequirement("At least one lowercase letter", hasLower),
                        _buildPasswordRequirement("At least one number", hasNumber),
                        _buildPasswordRequirement("At least one special character", hasSpecial),
                        _buildPasswordRequirement("At least 8 characters", isLongEnough),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Confirming new password
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirm,
                      style: theme.textTheme.bodyMedium,
                      decoration: InputDecoration(
                        labelText: "Confirm New Password",
                        labelStyle: theme.textTheme.bodySmall,
                        prefixIcon: Icon(Icons.lock, color: colorScheme.secondary),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirm ? Icons.visibility : Icons.visibility_off,
                            color: theme.iconTheme.color,
                          ),
                          onPressed: () => setState(() => obscureConfirm = !obscureConfirm),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: theme.dividerColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: colorScheme.secondary),
                        ),
                        filled: true,
                        fillColor: theme.scaffoldBackgroundColor,
                      ),
                    ),
                    if (errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          errorText!,
                          style: const TextStyle(color: Colors.red, fontSize: 14),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel", style: theme.textTheme.bodyMedium),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final newPass = newPasswordController.text.trim();
                    final confirmPass = confirmPasswordController.text.trim();
                    if (newPass != confirmPass) {
                      setState(() => errorText = "Passwords do not match!");
                      return;
                    }
                    if (!hasUpper || !hasLower || !hasNumber || !hasSpecial || !isLongEnough) {
                      setState(() => errorText = "Password does not meet complexity requirements.");
                      return;
                    }
                    final url = Uri.parse('http://10.0.2.2:5000/auth/change_password');
                    final response = await http.post(
                      url,
                      headers: {"Content-Type": "application/json"},
                      body: json.encode({
                        "email": currentEmail,
                        "old_password": oldPasswordController.text.trim(),
                        "new_password": newPass,
                      }),
                    );
                    final data = json.decode(response.body);
                    if (response.statusCode == 200) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Password changed successfully."),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      setState(() => errorText = data["error"] ?? "Error changing password.");
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: colorScheme.secondary),
                  child: Text("Save", style: theme.textTheme.bodyMedium),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Protects against accidental account removal with password confirmation
  void _showDeleteAccountDialog(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.canvasColor,
        title: Text("Delete Account", style: theme.textTheme.titleMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Are you sure you want to delete your account? This action cannot be undone.",
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                labelText: "Enter your password",
                labelStyle: theme.textTheme.bodySmall,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: colorScheme.secondary),
                ),
                filled: true,
                fillColor: theme.scaffoldBackgroundColor,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: theme.textTheme.bodyMedium),
          ),
          ElevatedButton(
            onPressed: () async {
              final password = passwordController.text.trim();
              if (password.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter your password."), backgroundColor: Colors.red),
                );
                return;
              }
              final url = Uri.parse('http://10.0.2.2:5000/auth/delete_account');
              final response = await http.post(
                url,
                headers: {"Content-Type": "application/json"},
                body: json.encode({
                  "email": currentEmail,
                  "password": password,
                }),
              );
              final data = json.decode(response.body);
              if (response.statusCode == 200) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(data["message"] ?? "Account deleted successfully."),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              } else {
                final errorMsg = data["error"] ?? "Error deleting account.";
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: colorScheme.secondary),
            child: Text("Delete", style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  /// Collects user suggestions and bug reports via simple form
  void _showFeedbackDialog(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final TextEditingController messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.canvasColor,
        title: Text("Send Feedback", style: theme.textTheme.titleMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Your feedback helps us improve MAGMA. Please share your thoughts, suggestions, or report any issues.",
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: "Type your message here...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: theme.cardColor,
              ),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.secondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (messageController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a message")),
                );
                return;
              }

              try {
                final response = await http.post(
                  Uri.parse("http://10.0.2.2:5000/auth/send_feedback"),
                  headers: {"Content-Type": "application/json"},
                  body: json.encode({
                    "email": currentEmail,
                    "message": messageController.text.trim(),
                  }),
                );

                if (response.statusCode == 200) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Thank you for your feedback!"),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  throw Exception("Failed to send feedback");
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Error sending feedback: ${e.toString()}"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.secondary,
            ),
            child: Text(
              "Send",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Shares app information, mission statement, and contact details
  void _showAboutDialog(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.canvasColor,
        title: Text("About MAGMA", style: theme.textTheme.titleMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "MAGMA is an advanced stock analysis platform designed to empower investors with AI-driven market insights and visualization tools.",
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text("Our Mission", style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              "To democratize financial analysis through accessible, intelligent technology that helps investors make more informed decisions.",
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text("Key Features", style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              "• Advanced AI market forecasting algorithms\n• Interactive data visualization of market trends\n• End-of-Day (EOD) stock performance analysis\n• Intuitive interface designed for investors of all experience levels",
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text("Security & Privacy", style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              "MAGMA employs industry-standard encryption to ensure your data remains secure and private.",
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text("Developed by Team MAGMA", style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text("Contact: teammagma242@gmail.com", style: theme.textTheme.bodyMedium),
            Text("Version 1.0.0", style: theme.textTheme.bodySmall),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close", style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.secondary)),
          ),
        ],
      ),
    );
  }
}
