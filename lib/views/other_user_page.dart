import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/follow_and_unfollow_services.dart';

import '../model/recipe.dart';
import 'recipe_detail_page.dart';

class OtherUserProfilePage extends StatefulWidget {
  final String userId;
  const OtherUserProfilePage({Key? key, required this.userId})
    : super(key: key);

  @override
  _OtherUserProfilePageState createState() => _OtherUserProfilePageState();
}

class _OtherUserProfilePageState extends State<OtherUserProfilePage> {
  int _selectedIndex = 0;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  bool _isProcessingFollow = false;

  Future<void> _toggleFollow() async {
    if (_currentUser == null) return;
    if (_isProcessingFollow) return;

    setState(() => _isProcessingFollow = true);
    final currentUid = _currentUser.uid;

    try {
      // Fetch current user's display info for notification payload
      final currentUserSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .get();
      final currentUserData = currentUserSnap.data() ?? <String, dynamic>{};
      final username =
          currentUserData['username'] ?? currentUserData['name'] ?? 'Someone';
      final profileImageUrl =
          currentUserData['photoUrl'] ??
          currentUserData['profileImageUrl'] ??
          '';

      final service = FollowService();
      final nowFollowing = await service.toggleFollow(
        currentUid,
        widget.userId,
        username,
        profileImageUrl,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nowFollowing ? 'Followed $username' : 'Unfollowed $username',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update follow status: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessingFollow = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("User Profile")),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .doc(widget.userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data?.data() ?? <String, dynamic>{};
          final name = userData["name"] ?? userData['username'] ?? "Unknown";
          final photoUrl =
              userData["photoUrl"] ?? userData['profileImageUrl'] ?? "";
          final followers = List.from(userData["followers"] ?? []);
          final following = List.from(userData["following"] ?? []);

          final currentUid = _currentUser?.uid;
          final isFollowing =
              currentUid != null && followers.contains(currentUid);

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                CircleAvatar(
                  radius: 50,
                  backgroundImage: photoUrl.isNotEmpty
                      ? NetworkImage(photoUrl)
                      : null,
                  child: photoUrl.isEmpty
                      ? const Icon(Icons.person, size: 50)
                      : null,
                ),
                const SizedBox(height: 10),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _toggleFollow,
                  child: Text(isFollowing ? "Unfollow" : "Follow"),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStat("Recipes", widget.userId),
                    Column(
                      children: [
                        Text(
                          "${followers.length}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Text("Followers"),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          "${following.length}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Text("Following"),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [_buildTab("Recipes", 0), _buildTab("Liked", 1)],
                ),
                const SizedBox(height: 12),
                _buildContent(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStat(String label, String userId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection("recipes")
          .where("authorId", isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return Column(
          children: [
            Text("$count", style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(label),
          ],
        );
      },
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.deepOrange : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final Query<Map<String, dynamic>> query = _selectedIndex == 0
        ? FirebaseFirestore.instance
              .collection("recipes")
              .where("authorId", isEqualTo: widget.userId)
        : FirebaseFirestore.instance
              .collection("recipes")
              .where("likedBy", arrayContains: widget.userId);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No recipes found"));
        }

        final docs = snapshot.data!.docs;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.9,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final raw = doc.data();
            final data = Map<String, dynamic>.from(raw);
            data['id'] = doc.id;
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
              child: Card(
                child: Column(
                  children: [
                    Expanded(
                      child: recipe.coverImageUrl.isNotEmpty
                          ? Image.network(
                              recipe.coverImageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            )
                          : Container(
                              color: Colors.grey.shade200,
                              width: double.infinity,
                              child: const Icon(Icons.image),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        recipe.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
