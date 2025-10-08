import 'package:cloud_firestore/cloud_firestore.dart';

class FollowService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _isProcessing = false; // Prevent multiple clicks from lagging

  Future<bool> toggleFollow(
    String currentUid,
    String targetUid,
    String username,
    String profileImageUrl,
  ) async {
    // Prevent double-click lag
    if (_isProcessing) return false;
    _isProcessing = true;

    try {
      if (currentUid == targetUid) {
        throw Exception('You cannot follow yourself');
      }

      final currentUserRef = _db.collection("users").doc(currentUid);
      final targetUserRef = _db.collection("users").doc(targetUid);

      // Fetch both users concurrently (faster)
      final snapshots = await Future.wait([
        currentUserRef.get(),
        targetUserRef.get(),
      ]);

      final currentUserSnap = snapshots[0];
      final targetUserSnap = snapshots[1];

      if (!currentUserSnap.exists || !targetUserSnap.exists) {
        throw Exception('User not found');
      }

      final currentUserData = currentUserSnap.data() ?? {};
      final following = List<String>.from(currentUserData["following"] ?? []);
      final isFollowing = following.contains(targetUid);

      final batch = _db.batch(); // Use batch for atomic update

      if (isFollowing) {
        // --- UNFOLLOW ---
        batch.update(currentUserRef, {
          "following": FieldValue.arrayRemove([targetUid]),
        });
        batch.update(targetUserRef, {
          "followers": FieldValue.arrayRemove([currentUid]),
        });
      } else {
        // --- FOLLOW ---
        batch.update(currentUserRef, {
          "following": FieldValue.arrayUnion([targetUid]),
        });
        batch.update(targetUserRef, {
          "followers": FieldValue.arrayUnion([currentUid]),
        });

        // Notification (separate write to avoid blocking batch)
        _db
            .collection("notifications")
            .doc(targetUid)
            .collection('items')
            .add({
              "type": "follow",
              "fromUserId": currentUid,
              "fromUsername": username,
              "fromUserImage": profileImageUrl,
              "createdAt": FieldValue.serverTimestamp(),
              "read": false,
            })
            .catchError((e) {
              print("Notification error: $e");
            });
      }

      await batch.commit();
      return !isFollowing;
    } on FirebaseException catch (e) {
      print('Firestore error: ${e.code} - ${e.message}');
      throw Exception('Firestore error: ${e.message}');
    } catch (e) {
      rethrow;
    } finally {
      _isProcessing = false;
    }
  }

  Stream<bool> isFollowing(String currentUid, String targetUid) {
    return _db.collection("users").doc(currentUid).snapshots().map((snapshot) {
      if (!snapshot.exists) return false;
      final data = snapshot.data() ?? {};
      final following = List<String>.from(data["following"] ?? []);
      return following.contains(targetUid);
    });
  }
}
