import 'package:flutter/material.dart';
import 'onboarding.dart';
import 'login.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Cooking App",
      theme: ThemeData(primarySwatch: Colors.deepOrange),
      home: const OnboardingScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
      },
    );
  }
}
