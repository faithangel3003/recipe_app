import 'package:cloud_firestore/cloud_firestore.dart';

class LikeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> toggleLike(
    String recipeId,
    String userId,
    String username,
    String userImage,
  ) async {
    try {
      final recipeRef = _firestore.collection('recipes').doc(recipeId);
      final docSnapshot = await recipeRef.get();

      if (!docSnapshot.exists) {
        throw Exception('Recipe not found');
      }

      final data = docSnapshot.data() as Map<String, dynamic>;
      final List<dynamic> likedBy = List.from(data['likedBy'] ?? []);
      bool isCurrentlyLiked = likedBy.contains(userId);
      final authorId = data['authorId'] as String?;
      final recipeTitle = data['title'] ?? "Untitled";
      final recipeImage =
          data['thumbnail'] ?? ""; // Assuming you store recipe thumbnails

      if (isCurrentlyLiked) {
        await recipeRef.update({
          'likedBy': FieldValue.arrayRemove([userId]),
          'likes': FieldValue.increment(-1),
        });
      } else {
        await recipeRef.update({
          'likedBy': FieldValue.arrayUnion([userId]),
          'likes': FieldValue.increment(1),
        });

        // Add notification for author
        if (authorId != null && authorId != userId) {
          await _firestore
              .collection('notifications')
              .doc(authorId)
              .collection('items')
              .add({
                'type': 'like',
                'fromUserId': userId,
                'fromUsername': username,
                'fromUserImage': userImage,
                'recipeId': recipeId,
                'recipeTitle': recipeTitle,
                'recipeImage': recipeImage,
                'createdAt': FieldValue.serverTimestamp(),
                'read': false,
              });
        }
      }
    } catch (e) {
      print('Like error: $e');
      rethrow;
    }
  }

  // Check if user has liked a recipe
  Future<bool> hasUserLiked(String recipeId, String userId) async {
    try {
      final docSnapshot = await _firestore
          .collection('recipes')
          .doc(recipeId)
          .get();

      if (!docSnapshot.exists) return false;

      final data = docSnapshot.data() as Map<String, dynamic>;
      final List<dynamic> likedBy = List.from(data['likedBy'] ?? []);

      return likedBy.contains(userId);
    } catch (e) {
      print('Error checking like status: $e');
      return false;
    }
  }
}
