import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/recipe.dart';
import '../services/follow_and_unfollow_services.dart';
import 'recipe_detail_page.dart';

class OtherUserProfilePage extends StatefulWidget {
  final String userId;
  const OtherUserProfilePage({Key? key, required this.userId})
      : super(key: key);

  @override
  _OtherUserProfilePageState createState() => _OtherUserProfilePageState();
}

class _OtherUserProfilePageState extends State<OtherUserProfilePage> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  bool _isProcessingFollow = false;

  Future<void> _toggleFollow() async {
    if (_currentUser == null || _isProcessingFollow) return;
    setState(() => _isProcessingFollow = true);
    final currentUid = _currentUser!.uid;

    try {
      final currentUserSnap =
          await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
      final currentUserData = currentUserSnap.data() ?? {};
      final username = currentUserData['username'] ??
          currentUserData['name'] ??
          'Someone';
      final profileImageUrl = currentUserData['photoUrl'] ??
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isProcessingFollow = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 4,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFA726), Color.fromARGB(255, 250, 135, 100)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          "User Profile",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .doc(widget.userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data?.data() ?? {};
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
                // 🌆 Background with blur (replacing orange gradient)
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
                        child: Container(
                          color: Colors.black.withOpacity(0.4),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          CircleAvatar(
                            radius: 55,
                            backgroundColor: Colors.white,
                            child: CircleAvatar(
                              radius: 52,
                              backgroundImage: photoUrl.isNotEmpty
                                  ? NetworkImage(photoUrl)
                                  : const NetworkImage(
                                      "https://via.placeholder.com/150"),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 20,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isFollowing
                                    ? Colors.grey[700]
                                    : Colors.orange,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 26,
                                  vertical: 10,
                                ),
                                elevation: 3,
                              ),
                              onPressed: _toggleFollow,
                              child: _isProcessingFollow
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      isFollowing ? "Following" : "Follow",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStat("Recipes", widget.userId),
                              Column(
                                children: [
                                  Text(
                                    "${followers.length}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Text(
                                    "Followers",
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  Text(
                                    "${following.length}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Text(
                                    "Following",
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

               Container(
  width: double.infinity,
  decoration: const BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(25),
      topRight: Radius.circular(25),
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black26,
        offset: Offset(0, -3),
        blurRadius: 10,
      ),
    ],
  ),
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        "Recipes",
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      const SizedBox(height: 10),
      _buildRecipeGrid(),
    ],
  ),
),

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
        int count = 0;
        if (snapshot.hasData) {
          count = snapshot.data!.docs.where((doc) {
            final data = doc.data();
            final archived =
                data['isArchived'] == true || data['isArchived'] == 'true';
            return !archived;
          }).length;
        }
        return Column(
          children: [
            Text(
              "$count",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(label, style: const TextStyle(color: Colors.white70)),
          ],
        );
      },
    );
  }

  Widget _buildRecipeGrid() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection("recipes")
          .where("authorId", isEqualTo: widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              "No recipes found",
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data();
          final isArchived = data['isArchived'] == true || data['isArchived'] == 'true';
          final isHidden = data['isHidden'] == true || data['isHidden'] == 'true';
          final authorId = data['authorId'];
          final isOwner = _currentUser?.uid == authorId;

          // ✅ Only show hidden/archived if the current user is the owner
          if ((isArchived || isHidden) && !isOwner) return false;
          return true;
        }).toList();

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(10),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 20,
            childAspectRatio: 1.00,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final recipe = Recipe.fromJson({...data, 'id': docs[index].id});

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecipeDetailPage(recipe: recipe),
                  ),
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                child: const Center(
                                  child: Icon(Icons.image, color: Colors.grey),
                                ),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          recipe.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
