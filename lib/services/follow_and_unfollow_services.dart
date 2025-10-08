import 'package:cloud_firestore/cloud_firestore.dart';

class FollowService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<bool> toggleFollow(
    String currentUid,
    String targetUid,
    String username,
    String profileImageUrl,
  ) async {
    // Quick self-follow guard
    if (currentUid == targetUid) {
      throw Exception('You cannot follow yourself');
    }

    final currentUserRef = _db.collection("users").doc(currentUid);
    final targetUserRef = _db.collection("users").doc(targetUid);

    try {
      // Wrap in a transaction to avoid race conditions & reduce round trips
      final bool result = await _db.runTransaction<bool>((txn) async {
        final currentSnap = await txn.get(currentUserRef);
        final targetSnap = await txn.get(targetUserRef);

        if (!currentSnap.exists) {
          throw Exception('Current user not found');
        }
        if (!targetSnap.exists) {
          throw Exception('User to follow not found');
        }

        final currentData = currentSnap.data() ?? <String, dynamic>{};
        final following = List<String>.from(currentData['following'] ?? []);
        final alreadyFollowing = following.contains(targetUid);

        if (alreadyFollowing) {
          txn.update(currentUserRef, {
            'following': FieldValue.arrayRemove([targetUid]),
          });
          txn.update(targetUserRef, {
            'followers': FieldValue.arrayRemove([currentUid]),
          });
          return false; // now not following
        } else {
          txn.update(currentUserRef, {
            'following': FieldValue.arrayUnion([targetUid]),
          });
          txn.update(targetUserRef, {
            'followers': FieldValue.arrayUnion([currentUid]),
          });
          return true; // now following
        }
      });

      // Only create notification if the transaction ended in a follow action
      if (result) {
        // Fire-and-forget notification (don't block UI if slow)
        _db
            .collection('notifications')
            .doc(targetUid)
            .collection('items')
            .add({
              'type': 'follow',
              'fromUserId': currentUid,
              'fromUsername': username,
              'fromUserImage': profileImageUrl,
              'createdAt': FieldValue.serverTimestamp(),
              'read': false,
            })
            .catchError((e) {
              // Return a valid DocumentReference to satisfy the type; we simply point to a placeholder doc.
              return _db
                  .collection('notifications')
                  .doc(targetUid)
                  .collection('items')
                  .doc('placeholder');
            });
      }

      return result;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception('Permission denied – check Firestore security rules');
      }
      throw Exception('Firestore error: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  Stream<bool> isFollowing(String currentUid, String targetUid) {
    return _db.collection("users").doc(currentUid).snapshots().map((snapshot) {
      if (!snapshot.exists) return false;
      final data = snapshot.data() ?? <String, dynamic>{};
      final following = List<String>.from(data["following"] ?? []);
      return following.contains(targetUid);
    });
  }
}
