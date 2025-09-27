import 'package:cloud_firestore/cloud_firestore.dart';

class FollowService {
  final _db = FirebaseFirestore.instance;

  Future<void> toggleFollow(
    String currentUid,
    String targetUid,
    String username,
    String profileImageUrl,
  ) async {
    final currentUserRef = _db.collection("users").doc(currentUid);
    final targetUserRef = _db.collection("users").doc(targetUid);

    final targetSnap = await targetUserRef.get();
    final targetData = targetSnap.data() as Map<String, dynamic>;
    final followers = List<String>.from(targetData["followers"] ?? []);

    if (followers.contains(currentUid)) {
      // Unfollow
      await currentUserRef.update({
        "following": FieldValue.arrayRemove([targetUid]),
      });
      await targetUserRef.update({
        "followers": FieldValue.arrayRemove([currentUid]),
      });
    } else {
      // Follow
      await currentUserRef.update({
        "following": FieldValue.arrayUnion([targetUid]),
      });
      await targetUserRef.update({
        "followers": FieldValue.arrayUnion([currentUid]),
      });

      // Add notification
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
          });
    }
  }
}
