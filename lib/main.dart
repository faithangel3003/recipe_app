import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:final_proj/firebase_options.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'onboarding.dart';
import 'auth/login.dart';
import 'main_page.dart';
import 'views/upload_page.dart';
import 'views/notification_page.dart';
import 'views/profile_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true, // or false, depending on your need
    sslEnabled: true,
  );
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
        '/home': (context) => const MainPage(),
        '/upload': (context) => const UploadPage(),
        '/notification': (context) => const NotificationPage(),
        '/profile': (context) => ProfilePage(),
      },
    );
  }
}
