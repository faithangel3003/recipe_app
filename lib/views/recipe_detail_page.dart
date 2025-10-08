import 'package:final_proj/services/follow_and_unfollow_services.dart';
import 'package:final_proj/services/user_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/recipe.dart';
import 'other_user_page.dart';

class RecipeDetailPage extends StatelessWidget {
  final Recipe recipe;

  const RecipeDetailPage({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Scaffold(
        body: Center(child: Text('Please log in to view recipe details')),
      );
    }
    final currentUid = currentUser.uid;

    if (recipe.isArchived && recipe.authorId != currentUid) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Recipe Unavailable'),
          backgroundColor: Colors.orange.shade600,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'This recipe has been archived by an admin and is not available.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

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
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        slivers: [
          // --- COVER IMAGE WITH OVERLAY ---
          SliverAppBar(
            expandedHeight: 280,
            floating: false,
            pinned: true,
            backgroundColor: Colors.orange.shade700,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              title: Container(
                padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
                child: Text(
                  recipe.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  recipe.coverImageUrl.isNotEmpty
                      ? Image.network(
                          recipe.coverImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
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
                  Container(
                    color: Colors.black.withOpacity(0.35), // dark overlay
                  ),
                ],
              ),
            ),
          ),

          // --- RECIPE BODY ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- CATEGORY + DURATION ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Chip(
                        backgroundColor: Colors.orange.shade100,
                        label: Text(
                          recipe.category,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.timer, color: Colors.orange, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            "${recipe.cookingDuration} mins",
                            style: const TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- AUTHOR SECTION ---
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  OtherUserProfilePage(userId: recipe.authorId),
                            ),
                          );
                        },
                        child: CircleAvatar(
                          radius: 22,
                          backgroundImage: recipe.authorProfileImage.isNotEmpty
                              ? NetworkImage(recipe.authorProfileImage)
                              : null,
                          child: recipe.authorProfileImage.isEmpty
                              ? const Icon(Icons.person, size: 20)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OtherUserProfilePage(
                                  userId: recipe.authorId,
                                ),
                              ),
                            );
                          },
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
                      ),
                      const SizedBox(width: 10),
                      if (recipe.authorId != currentUid)
                        _FollowButton(
                          currentUid: currentUid,
                          targetUid: recipe.authorId,
                          username: currentUser.displayName ?? "User",
                          profileImageUrl: currentUser.photoURL ?? "",
                        ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // --- DESCRIPTION ---
                  Text(
                    "Description",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Colors.orange.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      recipe.description,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- INGREDIENTS ---
                  Text(
                    "Ingredients",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Colors.orange.shade800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...recipe.ingredients.map((ingredient) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.circle, size: 8, color: Colors.orange),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              ingredient,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 24),

                  // --- STEPS ---
                  Text(
                    "Steps",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Colors.orange.shade800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...recipe.steps.asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final step = entry.value;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
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
                                  const SizedBox(width: 10),
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
                              const SizedBox(height: 10),
                              if (step.imageUrl.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    step.imageUrl,
                                    height: 180,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
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
                        ),
                      ),
                    );
                  }),
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

// --- FOLLOW BUTTON ---
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
              ? Container(
                  width: 90,
                  height: 36,
                  alignment: Alignment.center,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isFollowing ? Colors.grey : Colors.orange,
                    ),
                  ),
                )
              : ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          setState(() => _isLoading = true);
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
                            if (mounted) setState(() => _isLoading = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isFollowing ? Colors.grey.shade400 : Colors.orange,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
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
