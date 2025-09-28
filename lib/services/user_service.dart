import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> ensureUserDocumentExists(
    String uid,
    String displayName,
    String photoUrl,
  ) async {
    final userRef = _db.collection("users").doc(uid);
    final userSnap = await userRef.get();

    if (!userSnap.exists) {
      await userRef.set({
        "uid": uid,
        "displayName": displayName,
        "photoUrl": photoUrl,
        "following": [],
        "followers": [],
        "createdAt": FieldValue.serverTimestamp(),
      });
    }
  }
}
