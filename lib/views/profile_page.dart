import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:final_proj/views/edit_recipe_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/cloudinary_service.dart';
import '../model/recipe.dart';
import 'edit_profile_page.dart';
import '../model/user.dart';
import 'follow_list_page.dart';
import 'recipe_detail_page.dart';
import '../services/like_services.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _selectedIndex = 0;

  Future<void> _openEditProfile() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(firebaseUser.uid)
        .get();

    if (!doc.exists) return;

    final data = doc.data() ?? <String, dynamic>{};
    data['uid'] = data['uid'] ?? firebaseUser.uid;
    final appUser = AppUser.fromJson(Map<String, dynamic>.from(data));

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditProfilePage(user: appUser)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
  elevation: 4,
  backgroundColor: Colors.transparent,
  flexibleSpace: Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFFFA726), Color(0xFFFF7043)], // soft orange gradient
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ),
  title: const Text(
    "My Profile",
    style: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: Colors.white,
      letterSpacing: 1,
    ),
  ),
  centerTitle: true,
  iconTheme: const IconThemeData(color: Colors.white),
  actions: [
    IconButton(
      icon: const Icon(Icons.edit, color: Colors.white),
      onPressed: _openEditProfile,
    ),
    PopupMenuButton<String>(
      color: Colors.white,
      icon: const Icon(Icons.more_vert, color: Colors.white),
      onSelected: (value) async {
        if (value == 'logout') {
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            Navigator.of(context).pushReplacementNamed("/login");
          }
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'logout',
          child: Text(
            "Log Out",
            style: TextStyle(color: Colors.black87),
          ),
        ),
      ],
    ),
  ],
),

      body: SingleChildScrollView(
        child: Column(
          children: [
            // 🖼 Header with blurred background
            Stack(
              children: [
                Container(
                  height: 290,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/backgroundpic.jpg'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(color: Colors.black.withOpacity(0.4)),
                  ),
                ),
                Positioned.fill(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // Profile Picture with Edit Button
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 55,
                            backgroundColor: Colors.white,
                            child: CircleAvatar(
                              radius: 52,
                              backgroundImage: user?.photoURL != null
                                  ? NetworkImage(user!.photoURL!)
                                  : const NetworkImage(
                                      "https://via.placeholder.com/150"),
                            ),
                          ),
                          Positioned(
                            right: MediaQuery.of(context).size.width / 2 - 70,
                            bottom: 4,
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 2),
                                ),
                                padding: const EdgeInsets.all(6),
                                child: const Icon(Icons.add,
                                    color: Colors.white, size: 22),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // User name
                      Text(
                        user?.displayName ?? "Unknown User",
                        style: const TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(height: 15),

                      // Stats row
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(user?.uid)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || !snapshot.data!.exists) {
                            return _buildStats(0, 0, 0);
                          }
                          final data = snapshot.data!.data() ?? {};
                          final followers =
                              (data['followers'] as List<dynamic>? ?? []).length;
                          final following =
                              (data['following'] as List<dynamic>? ?? []).length;
                          return StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('recipes')
                                .where('authorId', isEqualTo: user?.uid)
                                .snapshots(),
                            builder: (context, snap) {
                              final recipes = snap.hasData
                                  ? snap.data!.docs.length
                                  : 0;
                              return _buildStats(recipes, following, followers);
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ✨ Smooth rounded transition
            Container(
              height: 25,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    offset: Offset(0, -2),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),

            // 📑 Tabs + Content
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _tabButton("Recipes", 0),
                      const SizedBox(width: 25),
                      _tabButton("Liked", 1),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _selectedIndex == 0
                      ? _buildFoodGrid()
                      : _buildLikedGrid(),
                ],
              ),
            ),
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

          GestureDetector(
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

          GestureDetector(
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
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Colors.white, // ✅ Make the numbers white
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: const TextStyle(
          color: Colors.grey, // label stays grey for contrast
          fontSize: 14,
        ),
      ),
    ],
  );
}

  Widget _tabButton(String text, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Column(
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.black : Colors.grey,
            ),
          ),
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 2,
              width: 40,
              color: Colors.orange,
            ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final user = FirebaseAuth.instance.currentUser;
    final XFile? image =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image == null || user == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final cloudinary = CloudinaryService();
      final uploadedUrl =
          await cloudinary.uploadFile(File(image.path), folder: 'profile_images');
      await user.updatePhotoURL(uploadedUrl);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'profileImageUrl': uploadedUrl});
    } finally {
      if (mounted) Navigator.pop(context);
      setState(() {});
    }
  }


  // Recipes Tab
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
              isOwner: true,
            );
          },
        );
      },
    );
  }

  // Liked Tab
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
              isOwner: false,
            );
          },
        );
      },
    );
  }
}

// Profile Recipe Card
class _ProfileRecipeCard extends StatefulWidget {
  final Recipe recipe;
  final String recipeId;
  final bool isOwner;
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
    _isLiked = widget.recipe.likedBy
        .contains(FirebaseAuth.instance.currentUser!.uid);
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
              final userData =
                  snapshot.data!.data() as Map<String, dynamic>?;
              if (userData == null) return const SizedBox(height: 30);

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundImage: (userData['profileImageUrl'] != null &&
                              userData['profileImageUrl'].isNotEmpty)
                          ? NetworkImage(userData['profileImageUrl'])
                          : null,
                      child: (userData['profileImageUrl'] == null ||
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

        // Recipe Card
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
                                child: CircularProgressIndicator(strokeWidth: 2),
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
                        icon: const Icon(Icons.more_vert,
                            color: Colors.white, size: 20),
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
                          PopupMenuItem(
                              value: 'edit', child: Text('Edit')),
                          PopupMenuItem(
                              value: 'delete', child: Text('Delete')),
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


