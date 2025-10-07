import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:final_proj/services/follow_and_unfollow_services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../model/recipe.dart';
import 'recipe_detail_page.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  String _getSectionTitle(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inHours < 6) {
      return "New";
    } else if (difference.inDays == 0) {
      return "Today";
    } else if (difference.inDays == 1) {
      return "Yesterday";
    } else {
      return "${createdAt.year}-${createdAt.month}-${createdAt.day}";
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.orange),
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 35), // your logo
            const SizedBox(width: 10),
            const Text(
              "Notifications",
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("notifications")
            .doc(currentUid)
            .collection("items")
            .orderBy("createdAt", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No notifications yet"));
          }

          final docs = snapshot.data!.docs;
          Map<String, List<QueryDocumentSnapshot>> grouped = {};

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final ts = data["createdAt"] as Timestamp?;
            if (ts == null) continue;
            final section = _getSectionTitle(ts.toDate());
            grouped.putIfAbsent(section, () => []);
            grouped[section]!.add(doc);
          }

          return ListView(
            children: grouped.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ...entry.value.map((notif) {
                    final data = notif.data() as Map<String, dynamic>;
                    final type = data["type"];
                    final fromUser = data["fromUsername"] ?? "Someone";
                    final fromImage = data["fromUserImage"] ?? "";
                    final fromUid = data["fromUserId"] ?? "";
                    // createdAt intentionally omitted here; we use timestamps only for grouping above.
                    final recipeImage = data["recipeImage"] ?? "";
                    final recipeTitle = data["recipeTitle"] ?? "";

                    String message = "";
                    switch (type) {
                      case 'like':
                        message = "$fromUser liked your recipe: $recipeTitle";
                        break;
                      case 'follow':
                        message = "$fromUser started following you";
                        break;
                      case 'hidden':
                        message =
                            data['message'] ??
                            'Your post was hidden by an admin.';
                        break;
                      case 'unhidden':
                        message =
                            data['message'] ?? 'Your post is visible again.';
                        break;
                      case 'archived':
                        message =
                            data['message'] ??
                            'Your post was archived by an admin.';
                        break;
                      case 'unarchived':
                        message =
                            data['message'] ??
                            'Your post was restored by an admin.';
                        break;
                      case 'deleted_permanent':
                        message =
                            data['message'] ??
                            'An archived post was permanently removed.';
                        break;
                      default:
                        message =
                            data['message'] ?? 'You have a new notification.';
                    }

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: fromImage.isNotEmpty
                            ? NetworkImage(fromImage)
                            : null,
                        child: fromImage.isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(
                        fromUser,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(message),
                      trailing:
                          (type == 'like' ||
                                  type == 'hidden' ||
                                  type == 'unhidden' ||
                                  type == 'archived' ||
                                  type == 'unarchived') &&
                              recipeImage.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                recipeImage,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                              ),
                            )
                          : type == 'follow'
                          ? FollowButton(
                              fromUid: fromUid,
                              fromUsername: fromUser,
                              fromUserImage: fromImage,
                            )
                          : null,
                      onTap:
                          (type == 'like' ||
                              type == 'hidden' ||
                              type == 'unhidden' ||
                              type == 'unarchived')
                          ? () async {
                              final recipeId = data['recipeId'] ?? '';
                              if (recipeId.isEmpty) return;
                              final doc = await FirebaseFirestore.instance
                                  .collection('recipes')
                                  .doc(recipeId)
                                  .get();
                              if (!doc.exists) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Recipe not found.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              final recipeData = doc.data()!;
                              // If archived, inform instead of navigating (or choose to still navigate if you want view-only)
                              if ((recipeData['isArchived'] ?? false) == true) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('This recipe is archived.'),
                                  ),
                                );
                                return;
                              }
                              final recipe = Recipe.fromJson(recipeData);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      RecipeDetailPage(recipe: recipe),
                                ),
                              );
                            }
                          : null,
                    );
                  }),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class FollowButton extends StatefulWidget {
  final String fromUid;
  final String fromUsername;
  final String fromUserImage;

  const FollowButton({
    super.key,
    required this.fromUid,
    required this.fromUsername,
    required this.fromUserImage,
  });

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  bool isFollowing = false;
  final currentUid = FirebaseAuth.instance.currentUser!.uid;
  final FollowService _followService = FollowService();

  @override
  void initState() {
    super.initState();
    _followService.isFollowing(currentUid, widget.fromUid).listen((value) {
      setState(() {
        isFollowing = value;
      });
    });
  }

  Future<void> _toggleFollow() async {
    await _followService.toggleFollow(
      currentUid,
      widget.fromUid,
      widget.fromUsername,
      widget.fromUserImage,
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: _toggleFollow,
      style: TextButton.styleFrom(
        backgroundColor: isFollowing ? Colors.grey[300] : Colors.deepOrange,
        foregroundColor: isFollowing ? Colors.black : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Text(isFollowing ? "Followed" : "Follow"),
    );
  }
}
