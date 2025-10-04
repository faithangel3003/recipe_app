import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ResetPasswordPage extends StatefulWidget {
  final String? link;
  const ResetPasswordPage({super.key, this.link});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.link != null) {
      _linkController.text = widget.link!;
    }
  }

  Future<void> _resetPassword() async {
    final rawLink = _linkController.text.trim();
    final newPassword = _passwordController.text.trim();
    final confirmPassword = _confirmController.text.trim();

    if (rawLink.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      setState(() => _error = "Please fill all fields");
      return;
    }
    if (newPassword != confirmPassword) {
      setState(() => _error = "Passwords do not match");
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      Uri uri = Uri.parse(rawLink);

      // 🔍 Step 1: Detect if it's a wrapped Firebase redirect link
      if (uri.queryParameters.containsKey('link')) {
        // Decode the inner "link" parameter
        uri = Uri.parse(Uri.decodeFull(uri.queryParameters['link']!));
      }

      // 🔍 Step 2: Extract oobCode
      final oobCode = uri.queryParameters['oobCode'];
      if (oobCode == null || oobCode.isEmpty) {
        setState(() => _error = "Invalid or expired link (missing oobCode)");
        return;
      }

      // 🔑 Step 3: Confirm password reset
      await FirebaseAuth.instance.confirmPasswordReset(
        code: oobCode,
        newPassword: newPassword,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Password reset successful! Please log in."),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? "Password reset failed");
    } catch (e) {
      setState(() => _error = "Invalid link format");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reset Password"),
        backgroundColor: Colors.deepOrange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Reset Your Password",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Paste the reset link and enter a new password.",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),

            TextField(
              controller: _linkController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.link),
                hintText: "Paste reset link here",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock),
                hintText: "New Password",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _confirmController,
              obscureText: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline),
                hintText: "Confirm Password",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _resetPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Reset Password",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
