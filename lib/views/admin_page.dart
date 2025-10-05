import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/recipe.dart';
import '../model/user.dart';
import 'recipe_detail_page.dart';
import '../auth/login.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({Key? key}) : super(key: key);

  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  bool _showHidden = false;

  Future<void> _toggleHideRecipe(Recipe recipe) async {
    try {
      final newHidden = !recipe.isHidden;
      await FirebaseFirestore.instance
          .collection('recipes')
          .doc(recipe.id)
          .update({'isHidden': newHidden});

      // Send a notification to the recipe author when their post is hidden
      try {
        if (newHidden && recipe.authorId.isNotEmpty) {
          final admin = FirebaseAuth.instance.currentUser;
          final adminId = admin?.uid ?? '';
          final adminName = admin?.displayName ?? 'Admin';
          final adminImage = admin?.photoURL ?? '';

          final notifRef = FirebaseFirestore.instance
              .collection('notifications')
              .doc(recipe.authorId)
              .collection('items')
              .doc();

          await notifRef.set({
            'type': 'hidden',
            'fromUserId': adminId,
            'fromUsername': adminName,
            'fromUserImage': adminImage,
            'recipeId': recipe.id,
            'recipeTitle': recipe.title,
            'recipeImage': recipe.coverImageUrl,
            'message':
                'Your post has been hidden because it was found to be inappropriate.',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        // don't block the main flow if notification fails
        debugPrint('Failed to send hidden notification: $e');
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

  Future<void> _deleteRecipe(Recipe recipe) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text(
          'Are you sure you want to delete this recipe? This action cannot be undone.',
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
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          Switch(
            value: _showHidden,
            onChanged: (value) {
              setState(() {
                _showHidden = value;
              });
            },
          ),
          const SizedBox(width: 8),
          Text(_showHidden ? 'Show Hidden' : 'Show Active'),
          IconButton(
            icon: const Icon(Icons.logout),
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
            return const Center(child: Text('No recipes found'));
          }

          final recipes = snapshot.data!.docs
              .map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                data['id'] = doc.id; // Ensure ID is set
                return Recipe.fromJson(data);
              })
              .where(
                (recipe) => _showHidden ? recipe.isHidden : !recipe.isHidden,
              )
              .toList();

          return ListView.builder(
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              final recipe = recipes[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
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
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            recipe.coverImageUrl,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.image),
                        ),
                  title: Text(
                    recipe.title,
                    style: TextStyle(
                      decoration: recipe.isHidden
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  subtitle: Text(
                    'By ${recipe.authorName} • ${recipe.category}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Hide/Unhide button
                      IconButton(
                        icon: Icon(
                          recipe.isHidden
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => _toggleHideRecipe(recipe),
                        tooltip: recipe.isHidden ? 'Unhide' : 'Hide',
                      ),
                      // Delete button
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        color: Colors.red,
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
