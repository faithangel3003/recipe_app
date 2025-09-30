import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../model/recipe.dart';
import 'recipe_detail_page.dart';
import 'dart:io';
import '../services/cloudinary_service.dart';

import 'edit_recipe_page.dart';

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
        title: const Text("Profile"),
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
            // Profile header with image and upload button
            Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: user?.photoURL != null
                      ? NetworkImage(user!.photoURL!)
                      : const NetworkImage("https://via.placeholder.com/150"),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
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
                          Navigator.pop(context); // close loading dialog
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    "Profile picture updated!",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text("OK"),
                                  ),
                                ],
                              ),
                            ),
                          );
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Text("Followers: 0 • Following: 0");
                }
                final data =
                    snapshot.data!.data() as Map<String, dynamic>? ?? {};
                final followers =
                    (data['followers'] as List<dynamic>? ?? []).length;
                final following =
                    (data['following'] as List<dynamic>? ?? []).length;
                return Text("Followers: $followers • Following: $following");
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

  Widget _buildFoodGrid() {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('recipes')
          .where('authorId', isEqualTo: user!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("Error loading recipes"));
        }
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
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.8,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final recipe = Recipe.fromJson(data);
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecipeDetailPage(recipe: recipe),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: recipe.coverImageUrl.isNotEmpty
                            ? Image.network(
                                recipe.coverImageUrl,
                                height: 100,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 100,
                                    color: Colors.grey.shade300,
                                    child: const Center(
                                      child: Icon(Icons.broken_image, size: 40),
                                    ),
                                  );
                                },
                              )
                            : Container(
                                height: 100,
                                color: Colors.grey.shade300,
                                child: const Center(
                                  child: Icon(Icons.image, size: 40),
                                ),
                              ),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.deepOrange,
                            shape: BoxShape.circle,
                          ),
                          child: PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.white,
                              size: 28,
                            ),
                            onSelected: (value) async {
                              if (value == 'edit') {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditRecipePage(
                                      recipeId: docs[index].id,
                                      recipeData: data,
                                    ),
                                  ),
                                );
                                if (result == true) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Recipe updated'),
                                    ),
                                  );
                                }
                              } else if (value == 'delete') {
                                await FirebaseFirestore.instance
                                    .collection('recipes')
                                    .doc(docs[index].id)
                                    .delete();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Recipe deleted'),
                                  ),
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe.authorName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          recipe.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${recipe.category} • ${recipe.cookingDuration} mins',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.favorite,
                              color: Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${recipe.likes} likes',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLikedGrid() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("Please log in to see liked recipes"));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('recipes')
          .where('likedBy', arrayContains: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("Error loading liked recipes"));
        }
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
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.8,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final recipe = Recipe.fromJson(data);
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecipeDetailPage(recipe: recipe),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: recipe.coverImageUrl.isNotEmpty
                            ? Image.network(
                                recipe.coverImageUrl,
                                height: 100,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 100,
                                    color: Colors.grey.shade300,
                                    child: const Center(
                                      child: Icon(Icons.broken_image, size: 40),
                                    ),
                                  );
                                },
                              )
                            : Container(
                                height: 100,
                                color: Colors.grey.shade300,
                                child: const Center(
                                  child: Icon(Icons.image, size: 40),
                                ),
                              ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe.authorName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          recipe.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${recipe.category} • ${recipe.cookingDuration} mins',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.favorite,
                              color: Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${recipe.likes} likes',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
