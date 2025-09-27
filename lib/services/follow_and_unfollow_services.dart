import 'package:cloud_firestore/cloud_firestore.dart';

class FollowService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<bool> toggleFollow(
    String currentUid,
    String targetUid,
    String username,
    String profileImageUrl,
  ) async {
    try {
      print('Toggling follow: $currentUid -> $targetUid');

      // Check if user is trying to follow themselves
      if (currentUid == targetUid) {
        throw Exception('You cannot follow yourself');
      }

      final currentUserRef = _db.collection("users").doc(currentUid);
      final targetUserRef = _db.collection("users").doc(targetUid);

      // Check if both users exist
      final currentUserSnap = await currentUserRef.get();
      final targetUserSnap = await targetUserRef.get();

      if (!currentUserSnap.exists) {
        throw Exception('Current user not found');
      }
      if (!targetUserSnap.exists) {
        throw Exception('User to follow not found');
      }

      // Check current follow status
      final currentUserData =
          currentUserSnap.data() as Map<String, dynamic>? ?? {};
      final following = List<String>.from(currentUserData["following"] ?? []);
      final isFollowing = following.contains(targetUid);

      if (isFollowing) {
        // Unfollow
        print('Unfollowing user: $targetUid');
        await currentUserRef.update({
          "following": FieldValue.arrayRemove([targetUid]),
        });
        await targetUserRef.update({
          "followers": FieldValue.arrayRemove([currentUid]),
        });
        print('Unfollow successful');
        return false;
      } else {
        // Follow
        print('Following user: $targetUid');
        await currentUserRef.update({
          "following": FieldValue.arrayUnion([targetUid]),
        });
        await targetUserRef.update({
          "followers": FieldValue.arrayUnion([currentUid]),
        });

        // Add notification
        print('Creating notification');
        await _db
            .collection("notifications")
            .doc(targetUid)
            .collection("items")
            .add({
              "type": "follow",
              "fromUserId": currentUid,
              "fromUsername": username,
              "fromUserImage": profileImageUrl,
              "createdAt": FieldValue.serverTimestamp(),
              "read": false,
            });

        print('Follow successful');
        return true;
      }
    } on FirebaseException catch (e) {
      print('Firestore error: ${e.code} - ${e.message}');
      if (e.code == 'permission-denied') {
        throw Exception(
          'Permission denied. Please check Firestore security rules.',
        );
      } else {
        throw Exception('Firestore error: ${e.message}');
      }
    } catch (e) {
      print('Follow error: $e');
      rethrow;
    }
  }

  Stream<bool> isFollowing(String currentUid, String targetUid) {
    return _db.collection("users").doc(currentUid).snapshots().map((snapshot) {
      if (!snapshot.exists) return false;
      final data = snapshot.data() as Map<String, dynamic>? ?? {};
      final following = List<String>.from(data["following"] ?? []);
      return following.contains(targetUid);
    });
  }
}
