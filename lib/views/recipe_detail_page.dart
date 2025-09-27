import 'package:final_proj/services/follow_and_unfollow_services.dart';
import 'package:final_proj/services/user_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/recipe.dart';

class RecipeDetailPage extends StatelessWidget {
  final Recipe recipe;

  const RecipeDetailPage({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // Handle case where user is not logged in
      return Scaffold(
        body: Center(child: Text('Please log in to view recipe details')),
      );
    }
    final currentUid = currentUser.uid;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await UserService().ensureUserDocumentExists(
          currentUid,
          currentUser.displayName ?? "User",
          currentUser.photoURL ?? "",
        );
      } catch (e) {
        print('Error ensuring user document: $e');
      }
    });

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Cover image
          SliverAppBar(
            expandedHeight: 250,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: recipe.coverImageUrl.isNotEmpty
                  ? Image.network(
                      recipe.coverImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey.shade300,
                        child: const Center(
                          child: Icon(
                            Icons.broken_image,
                            size: 48,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    )
                  : Container(color: Colors.grey.shade300),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + category + duration
                  Text(
                    recipe.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${recipe.category} • ${recipe.cookingDuration} mins",
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),

                  // Author + likes + FOLLOW BUTTON
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: recipe.authorProfileImage.isNotEmpty
                            ? NetworkImage(recipe.authorProfileImage)
                            : null,
                        child: recipe.authorProfileImage.isEmpty
                            ? const Icon(Icons.person, size: 20)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recipe.authorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${recipe.likes} Likes',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // FOLLOW BUTTON with state management
                      if (recipe.authorId != currentUid)
                        _FollowButton(
                          currentUid: currentUid,
                          targetUid: recipe.authorId,
                          username: currentUser.displayName ?? "User",
                          profileImageUrl: currentUser.photoURL ?? "",
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Description
                  const Text(
                    "Description",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    recipe.description,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 20),

                  // Ingredients
                  const Text(
                    "Ingredients",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: recipe.ingredients.map((ingredient) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 18,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                ingredient,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Steps
                  const Text(
                    "Steps",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Column(
                    children: recipe.steps.asMap().entries.map((entry) {
                      final index = entry.key + 1;
                      final step = entry.value;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.orange,
                                  radius: 14,
                                  child: Text(
                                    "$index",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    step.description,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (step.imageUrl.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  step.imageUrl,
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        height: 180,
                                        width: double.infinity,
                                        color: Colors.grey.shade300,
                                        child: const Center(
                                          child: Icon(
                                            Icons.broken_image,
                                            size: 48,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Separate widget for the follow button with state management
class _FollowButton extends StatefulWidget {
  final String currentUid;
  final String targetUid;
  final String username;
  final String profileImageUrl;

  const _FollowButton({
    required this.currentUid,
    required this.targetUid,
    required this.username,
    required this.profileImageUrl,
  });

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  final FollowService _followService = FollowService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: _followService.isFollowing(widget.currentUid, widget.targetUid),
      builder: (context, snapshot) {
        final isFollowing = snapshot.data ?? false;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: _isLoading
              ? SizedBox(
                  width: 100,
                  height: 36,
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isFollowing ? Colors.grey : Colors.green,
                        ),
                      ),
                    ),
                  ),
                )
              : ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          setState(() {
                            _isLoading = true;
                          });

                          try {
                            await _followService.toggleFollow(
                              widget.currentUid,
                              widget.targetUid,
                              widget.username,
                              widget.profileImageUrl,
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isLoading = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFollowing ? Colors.grey : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: Text(isFollowing ? "Following" : "Follow"),
                ),
        );
      },
    );
  }
}
