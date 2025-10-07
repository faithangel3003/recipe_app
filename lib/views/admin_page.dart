import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/recipe.dart';
import '../model/user.dart'; // Assuming you have a User model if needed elsewhere
import 'recipe_detail_page.dart';
import '../auth/login.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({Key? key}) : super(key: key);

  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  bool _showHidden = false;

  // Function to toggle the hidden status of a recipe and send notification
  Future<void> _toggleHideRecipe(Recipe recipe) async {
    try {
      final newHidden = !recipe.isHidden;
      await FirebaseFirestore.instance
          .collection('recipes')
          .doc(recipe.id)
          .update({'isHidden': newHidden});

      // Send a notification to the recipe author when their post is hidden/unhidden
      try {
        if (recipe.authorId.isNotEmpty) {
          final admin = FirebaseAuth.instance.currentUser;
          final adminId = admin?.uid ?? '';
          final adminName = admin?.displayName ?? 'Admin';
          final adminImage = admin?.photoURL ?? '';

          final notifRef = FirebaseFirestore.instance
              .collection('notifications')
              .doc(recipe.authorId)
              .collection('items')
              .doc();

          final message = newHidden
              ? 'Your post "${recipe.title}" has been hidden because it was found to be inappropriate.'
              : 'Your post "${recipe.title}" has been unhidden and is now visible to others.';

          await notifRef.set({
            'type': newHidden ? 'hidden' : 'unhidden',
            'fromUserId': adminId,
            'fromUsername': adminName,
            'fromUserImage': adminImage,
            'recipeId': recipe.id,
            'recipeTitle': recipe.title,
            'recipeImage': recipe.coverImageUrl,
            'message': message,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        debugPrint('Failed to send hide/unhide notification: $e');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newHidden ? 'Recipe hidden' : 'Recipe unhidden'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Function to delete a recipe and send notification
 Future<void> _deleteRecipe(Recipe recipe) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirm Delete'),
      content: Text(
        'Are you sure you want to delete "${recipe.title}"? This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('CANCEL'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('DELETE'),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  try {
    final admin = FirebaseAuth.instance.currentUser;
    final adminId = admin?.uid ?? '';
    final adminName = admin?.displayName ?? 'Admin';
    final adminImage = admin?.photoURL ?? '';

    // ✅ Create notification *before* deletion
    if (recipe.authorId.isNotEmpty) {
      final notifRef = FirebaseFirestore.instance
          .collection('notifications')
          .doc(recipe.authorId)
          .collection('items')
          .doc();

      await notifRef.set({
        'type': 'deleted', // ✅ Notification type
        'fromUserId': adminId,
        'fromUsername': adminName,
        'fromUserImage': adminImage,
        'recipeId': recipe.id,
        'recipeTitle': recipe.title,
        'recipeImage': recipe.coverImageUrl,
        'message':
            'Your post "${recipe.title}" has been deleted by the admin for violating community guidelines.',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // ✅ Delete recipe AFTER sending notification
    await FirebaseFirestore.instance
        .collection('recipes')
        .doc(recipe.id)
        .delete();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Recipe deleted successfully'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    debugPrint('Error deleting recipe: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error deleting recipe: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🔸 APP BAR - Orange gradient style
      appBar: AppBar(
        elevation: 6,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFA726), Color(0xFFFF7043)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 22,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          Row(
            children: [
              Text(
                _showHidden ? 'Hidden' : 'Active',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              Switch(
                value: _showHidden,
                onChanged: (value) {
                  setState(() {
                    _showHidden = value;
                  });
                },
                activeColor: Colors.white,
                inactiveThumbColor: Colors.orangeAccent,
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                tooltip: 'Logout',
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (!mounted) return;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
              ),
            ],
          ),
        ],
      ),

      // 🔸 BODY - modern cards with shadows
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('recipes')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No recipes found',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final recipes = snapshot.data!.docs
              .map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                data['id'] = doc.id;
                return Recipe.fromJson(data);
              })
              .where(
                (recipe) => _showHidden ? recipe.isHidden : !recipe.isHidden,
              )
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              final recipe = recipes[index];
              return Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecipeDetailPage(recipe: recipe),
                      ),
                    );
                  },
                  leading: recipe.coverImageUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            recipe.coverImageUrl,
                            width: 55,
                            height: 55,
                            fit: BoxFit.cover,
                            // Added error handling for image loading
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              width: 55,
                              height: 55,
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.broken_image,
                                  color: Colors.grey),
                            ),
                          ),
                        )
                      : Container(
                          width: 55,
                          height: 55,
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.image, color: Colors.grey),
                        ),
                  title: Text(
                    recipe.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: recipe.isHidden
                          ? Colors.grey // Grey out hidden items
                          : const Color(0xFF333333),
                      decoration: recipe.isHidden
                          ? TextDecoration.lineThrough // Strikethrough hidden items
                          : null,
                    ),
                  ),
                  subtitle: Text(
                    'By ${recipe.authorName} • ${recipe.category}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          recipe.isHidden
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: Colors.deepOrange,
                        ),
                        onPressed: () => _toggleHideRecipe(recipe),
                        tooltip: recipe.isHidden ? 'Unhide' : 'Hide',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteRecipe(recipe),
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}