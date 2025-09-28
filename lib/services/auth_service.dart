import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static String? get currentUserId {
    return FirebaseAuth.instance.currentUser?.uid;
  }
}
