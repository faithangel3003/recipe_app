import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/recipe.dart';
import 'recipe_detail_page.dart';
import '../auth/login.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({Key? key}) : super(key: key);

  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  bool _showHidden = false;
  bool _viewArchived =
      false; // when true show archived recipes instead of active/hidden

  Future<void> _toggleHideRecipe(Recipe recipe) async {
    try {
      final newHidden = !recipe.isHidden;
      await FirebaseFirestore.instance
          .collection('recipes')
          .doc(recipe.id)
          .update({'isHidden': newHidden});

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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newHidden ? 'Recipe hidden' : 'Recipe unhidden'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _restoreRecipe(Recipe recipe) async {
    try {
      await FirebaseFirestore.instance
          .collection('recipes')
          .doc(recipe.id)
          .update({'isArchived': false});

      try {
        if (recipe.authorId.isNotEmpty) {
          final admin = FirebaseAuth.instance.currentUser;
          final adminId = admin?.uid ?? '';
          final adminName = admin?.displayName ?? 'Admin';
          final adminImage = admin?.photoURL ?? '';
          await FirebaseFirestore.instance
              .collection('notifications')
              .doc(recipe.authorId)
              .collection('items')
              .add({
                'type': 'unarchived',
                'fromUserId': adminId,
                'fromUsername': adminName,
                'fromUserImage': adminImage,
                'recipeId': recipe.id,
                'recipeTitle': recipe.title,
                'recipeImage': recipe.coverImageUrl,
                'message':
                    'Your post "${recipe.title}" was restored by an admin.',
                'createdAt': FieldValue.serverTimestamp(),
              });
        }
      } catch (e) {
        debugPrint('Failed to send unarchive notification: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recipe restored'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error restoring recipe: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteOrArchiveRecipe(Recipe recipe) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          recipe.isArchived ? 'Permanently Delete?' : 'Archive Recipe?',
        ),
        content: Text(
          recipe.isArchived
              ? 'This will permanently remove "${recipe.title}". Continue?'
              : 'Archiving will hide "${recipe.title}" from everyone except admins. You can still restore it later. Proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(recipe.isArchived ? 'DELETE' : 'ARCHIVE'),
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

      if (recipe.isArchived) {
        // permanent delete path
        await FirebaseFirestore.instance
            .collection('recipes')
            .doc(recipe.id)
            .delete();
        if (recipe.authorId.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('notifications')
              .doc(recipe.authorId)
              .collection('items')
              .add({
                'type': 'deleted_permanent',
                'fromUserId': adminId,
                'fromUsername': adminName,
                'fromUserImage': adminImage,
                'recipeId': recipe.id,
                'recipeTitle': recipe.title,
                'recipeImage': recipe.coverImageUrl,
                'message':
                    'Your archived post "${recipe.title}" was permanently removed by an admin.',
                'createdAt': FieldValue.serverTimestamp(),
              });
        }
      } else {
        // archive instead of delete
        await FirebaseFirestore.instance
            .collection('recipes')
            .doc(recipe.id)
            .update({'isArchived': true});
        if (recipe.authorId.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('notifications')
              .doc(recipe.authorId)
              .collection('items')
              .add({
                'type': 'archived',
                'fromUserId': adminId,
                'fromUsername': adminName,
                'fromUserImage': adminImage,
                'recipeId': recipe.id,
                'recipeTitle': recipe.title,
                'recipeImage': recipe.coverImageUrl,
                'message':
                    'Your post "${recipe.title}" was archived by an admin.',
                'createdAt': FieldValue.serverTimestamp(),
              });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              recipe.isArchived
                  ? 'Recipe permanently deleted'
                  : 'Recipe archived',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting recipe: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing recipe: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              // Archived view toggle
              IconButton(
                tooltip: _viewArchived ? 'Show Active' : 'Show Archived',
                icon: Icon(
                  _viewArchived
                      ? Icons.inventory_2_outlined
                      : Icons.archive_outlined,
                  color: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _viewArchived = !_viewArchived;
                  });
                },
              ),
              Text(
                _viewArchived
                    ? 'Archived'
                    : (_showHidden ? 'Hidden' : 'Active'),
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              Switch(
                value: _showHidden,
                onChanged: (value) {
                  if (_viewArchived) return; // disabled while viewing archived
                  setState(() => _showHidden = value);
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
                (recipe) => _viewArchived
                    ? recipe.isArchived
                    : (!recipe.isArchived &&
                          (_showHidden ? recipe.isHidden : !recipe.isHidden)),
              )
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              final recipe = recipes[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
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
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  width: 55,
                                  height: 55,
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                  ),
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
                          ? Colors.grey
                          : const Color(0xFF333333),
                      decoration: recipe.isHidden
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  subtitle: Text(
                    'By ${recipe.authorName} • ${recipe.category}',
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
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
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          switch (value) {
                            case 'archive':
                              _deleteOrArchiveRecipe(recipe);
                              break;
                            case 'delete':
                              _deleteOrArchiveRecipe(recipe);
                              break;
                            case 'restore':
                              _restoreRecipe(recipe);
                              break;
                            case 'unhide':
                              _toggleHideRecipe(recipe);
                              break;
                            case 'hide':
                              _toggleHideRecipe(recipe);
                              break;
                          }
                        },
                        itemBuilder: (context) {
                          return <PopupMenuEntry<String>>[
                            if (!recipe.isArchived)
                              const PopupMenuItem(
                                value: 'archive',
                                child: Text('Archive'),
                              ),
                            if (recipe.isArchived) ...[
                              const PopupMenuItem(
                                value: 'restore',
                                child: Text('Restore'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete Permanently'),
                              ),
                            ],
                            if (!recipe.isArchived)
                              PopupMenuItem(
                                value: recipe.isHidden ? 'unhide' : 'hide',
                                child: Text(
                                  recipe.isHidden ? 'Unhide' : 'Hide',
                                ),
                              ),
                          ];
                        },
                        icon: const Icon(Icons.more_vert, color: Colors.red),
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
