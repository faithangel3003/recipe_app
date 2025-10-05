import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'reset_password_page.dart';
import 'package:uni_links/uni_links.dart';
import 'dart:async';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  String? _message;
  bool _isLoading = false;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _handleIncomingLinks();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _handleIncomingLinks() async {
    _sub = linkStream.listen((String? link) {
      if (link != null && link.contains("resetPassword")) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ResetPasswordPage(link: link)),
        );
      }
    });

    final initialLink = await getInitialLink();
    if (initialLink != null && initialLink.contains("resetPassword")) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ResetPasswordPage(link: initialLink)),
      );
    }
  }

  Future<void> _sendResetEmail() async {
    setState(() => _isLoading = true);
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() {
        _message = "Please enter your email";
        _isLoading = false;
      });
      return;
    }

    try {
      final actionCodeSettings = ActionCodeSettings(
        url: kIsWeb
            ? "https://ingrdnts-f505f.firebaseapp.com/resetPassword"
            : "ingrdnts://resetPassword",
        handleCodeInApp: true,
        androidPackageName: "com.example.ingrdnts",
        androidInstallApp: true,
        androidMinimumVersion: "21",
        iOSBundleId: "com.example.ingrdnts",
      );

      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
        actionCodeSettings: actionCodeSettings,
      );

      setState(() {
        _message =
            "Password reset email sent to $email.\nCheck your inbox for the reset link.";
      });
    } on FirebaseAuthException catch (e) {
      setState(() => _message = e.message);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Forgot Password"),
        backgroundColor: Colors.deepOrange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: "Email",
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _sendResetEmail,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Send Reset Link"),
            ),
            const SizedBox(height: 20),
            if (kIsWeb)
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ResetPasswordPage(),
                    ),
                  );
                },
                child: const Text("Go to Reset Password Page"),
              ),
            if (_message != null) ...[
              const SizedBox(height: 20),
              Text(
                _message!,
                style: const TextStyle(color: Colors.green),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
