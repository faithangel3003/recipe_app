import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:final_proj/views/follow_list_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../model/recipe.dart';
import 'recipe_detail_page.dart';
import 'dart:io';
import '../services/cloudinary_service.dart';
import 'edit_recipe_page.dart';
import '../services/like_services.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile"),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed("/login");
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'logout', child: Text("Log Out")),
            ],
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Profile image with edit button
            Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: user?.photoURL != null
                      ? NetworkImage(user!.photoURL!)
                      : const NetworkImage("https://via.placeholder.com/150"),
                ),
                Positioned(
                  bottom: 0,
                  right: MediaQuery.of(context).size.width / 2 - 60,
                  child: GestureDetector(
                    onTap: () async {
                      final ImagePicker picker = ImagePicker();
                      final XFile? x = await picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 80,
                      );
                      if (x != null && user != null) {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) =>
                              const Center(child: CircularProgressIndicator()),
                        );
                        final cloudinary = CloudinaryService();
                        String uploadedUrl = await cloudinary.uploadFile(
                          File(x.path),
                          folder: 'users/profile_images',
                        );
                        await user.updatePhotoURL(uploadedUrl);
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .update({'profileImageUrl': uploadedUrl});
                        if (mounted) {
                          Navigator.pop(context);
                          setState(() {});
                        }
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              user?.displayName ?? "Unknown User",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            // Stats row: user doc stream to show follower/following counts and
            // nested stream to count recipes authored by the current user.
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return _buildStats(0, 0, 0);
                }
                final data = snapshot.data!.data() ?? <String, dynamic>{};
                final followers =
                    (data['followers'] as List<dynamic>? ?? []).length;
                final following =
                    (data['following'] as List<dynamic>? ?? []).length;

                // Nested stream to count recipes authored by this user
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('recipes')
                      .where('authorId', isEqualTo: user?.uid)
                      .snapshots(),
                  builder: (context, recipesSnap) {
                    final recipesCount = recipesSnap.hasData
                        ? recipesSnap.data!.docs.length
                        : 0;
                    return _buildStats(recipesCount, following, followers);
                  },
                );
              },
            ),
            const SizedBox(height: 20),
            // Tab bar
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _tabButton("Recipes", 0),
                const SizedBox(width: 20),
                _tabButton("Liked", 1),
              ],
            ),
            const SizedBox(height: 10),
            // Tab content
            _selectedIndex == 0 ? _buildFoodGrid() : _buildLikedGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(int recipes, int following, int followers) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statItem("Recipes", recipes),

          // ✅ FOLLOWING
          GestureDetector(
            behavior:
                HitTestBehavior.opaque, // ensures the whole area is tappable
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FollowListPage(
                    userId: FirebaseAuth.instance.currentUser!.uid,
                  ),
                ),
              );
            },
            child: _statItem("Following", following),
          ),

          // ✅ FOLLOWERS
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FollowListPage(
                    userId: FirebaseAuth.instance.currentUser!.uid,
                  ),
                ),
              );
            },
            child: _statItem("Followers", followers),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
      ],
    );
  }

  Widget _tabButton(String text, int index) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Column(
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: _selectedIndex == index
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: _selectedIndex == index ? Colors.black : Colors.grey,
            ),
          ),
          if (_selectedIndex == index)
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 2,
              width: 30,
              color: Colors.black,
            ),
        ],
      ),
    );
  }

  // -------------------- Recipes Tab (Owner) -------------------- //
  Widget _buildFoodGrid() {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('recipes')
          .where('authorId', isEqualTo: user!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text("No recipes yet"));
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(10),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 20,
            childAspectRatio: 1.10,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final recipe = Recipe.fromJson(data);
            return _ProfileRecipeCard(
              recipe: recipe,
              recipeId: docs[index].id,
              isOwner: true, // Recipes tab
            );
          },
        );
      },
    );
  }

  // -------------------- Liked Tab -------------------- //
  Widget _buildLikedGrid() {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('recipes')
          .where('likedBy', arrayContains: user!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text("No liked recipes yet"));
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(10),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 20,
            childAspectRatio: 0.90,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final recipe = Recipe.fromJson(data);
            return _ProfileRecipeCard(
              recipe: recipe,
              recipeId: docs[index].id,
              isOwner: false, // Liked tab
            );
          },
        );
      },
    );
  }
}

// -------------------- Profile Recipe Card -------------------- //
class _ProfileRecipeCard extends StatefulWidget {
  final Recipe recipe;
  final String recipeId;
  final bool isOwner; // true = Recipes tab, false = Liked tab
  const _ProfileRecipeCard({
    required this.recipe,
    required this.recipeId,
    required this.isOwner,
    Key? key,
  }) : super(key: key);

  @override
  State<_ProfileRecipeCard> createState() => _ProfileRecipeCardState();
}

class _ProfileRecipeCardState extends State<_ProfileRecipeCard> {
  late bool _isLiked;
  late int _likesCount;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.recipe.likedBy.contains(
      FirebaseAuth.instance.currentUser!.uid,
    );
    _likesCount = widget.recipe.likes;
  }

  Future<void> _handleLike() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final bool originalIsLiked = _isLiked;
    final int originalLikesCount = _likesCount;

    setState(() {
      if (_isLiked)
        _likesCount--;
      else
        _likesCount++;
      _isLiked = !_isLiked;
    });

    try {
      await LikeService().toggleLike(
        widget.recipe.id,
        FirebaseAuth.instance.currentUser!.uid,
        FirebaseAuth.instance.currentUser!.displayName ?? "Unknown",
        FirebaseAuth.instance.currentUser!.photoURL ?? "",
      );
    } catch (e) {
      setState(() {
        _isLiked = originalIsLiked;
        _likesCount = originalLikesCount;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update like: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Author Row ONLY for Liked tab
        if (!widget.isOwner)
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(recipe.authorId)
                .get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox(height: 30);
              final userData = snapshot.data!.data() as Map<String, dynamic>?;
              if (userData == null) return const SizedBox(height: 30);

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundImage:
                          (userData['profileImageUrl'] != null &&
                              userData['profileImageUrl'].isNotEmpty)
                          ? NetworkImage(userData['profileImageUrl'])
                          : null,
                      child:
                          (userData['profileImageUrl'] == null ||
                              userData['profileImageUrl'].isEmpty)
                          ? const Icon(Icons.person, size: 16)
                          : null,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        userData['username'] ?? "Unknown",
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

        // Recipe Card wrapped in GestureDetector to navigate to RecipeDetailPage
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RecipeDetailPage(recipe: recipe),
                ),
              );
            },
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: recipe.coverImageUrl.isNotEmpty
                      ? Image.network(
                          recipe.coverImageUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(child: Icon(Icons.image)),
                        ),
                ),
                // Heart icon ONLY for Liked tab
                if (!widget.isOwner)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: GestureDetector(
                      onTap: _handleLike,
                      child: CircleAvatar(
                        backgroundColor: Colors.white.withOpacity(0.9),
                        radius: 16,
                        child: _isLoading
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                _isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: _isLiked ? Colors.red : Colors.grey,
                                size: 18,
                              ),
                      ),
                    ),
                  ),
                // 3-dot menu ONLY for Recipes tab
                if (widget.isOwner)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_vert,
                          color: Colors.white,
                          size: 20,
                        ),
                        onSelected: (value) async {
                          if (value == 'edit') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditRecipePage(
                                  recipeId: widget.recipeId,
                                  recipeData: recipe.toJson(),
                                ),
                              ),
                            );
                          } else if (value == 'delete') {
                            await FirebaseFirestore.instance
                                .collection('recipes')
                                .doc(widget.recipeId)
                                .delete();
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 6),
        // Title + Meta + Likes
        Text(
          recipe.title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          '${recipe.category} • ${recipe.cookingDuration} mins',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.favorite, color: Colors.red.shade400, size: 14),
            const SizedBox(width: 4),
            Text('$_likesCount likes', style: const TextStyle(fontSize: 12)),
          ],
        ),
      ],
    );
  }
}
