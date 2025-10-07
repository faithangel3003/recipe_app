import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'other_user_page.dart';

class FollowListPage extends StatelessWidget {
  final String userId;

  const FollowListPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Followers + Following
      child: Scaffold(
        appBar: AppBar(
          elevation: 4,
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
            "Connections",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 22,
              letterSpacing: 0.5,
            ),
          ),
          centerTitle: true,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: "Followers"),
              Tab(text: "Following"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _UserList(type: "followers", userId: userId),
            _UserList(type: "following", userId: userId),
          ],
        ),
      ),
    );
  }
}

class _UserList extends StatelessWidget {
  final String userId;
  final String type;

  const _UserList({required this.userId, required this.type});

  Future<void> _toggleFollow(
      String targetUserId, bool isFollowing, BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final currentUid = currentUser.uid;

    final currentUserRef =
        FirebaseFirestore.instance.collection("users").doc(currentUid);
    final targetUserRef =
        FirebaseFirestore.instance.collection("users").doc(targetUserId);

    try {
      if (isFollowing) {
        // Unfollow
        await currentUserRef.update({
          "following": FieldValue.arrayRemove([targetUserId]),
        });
        await targetUserRef.update({
          "followers": FieldValue.arrayRemove([currentUid]),
        });
      } else {
        // Follow
        await currentUserRef.update({
          "following": FieldValue.arrayUnion([targetUserId]),
        });
        await targetUserRef.update({
          "followers": FieldValue.arrayUnion([currentUid]),
        });
      }
    } catch (e) {
      debugPrint("Follow/Unfollow error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Something went wrong: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.data() ?? <String, dynamic>{};
        final List<String> ids = List<String>.from(data[type] ?? []);

        if (ids.isEmpty) {
          return Center(
            child: Text(
              "No $type yet",
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          itemCount: ids.length,
          itemBuilder: (context, index) {
            final uid = ids[index];
            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance
                  .collection("users")
                  .doc(uid)
                  .get(),
              builder: (context, userSnap) {
                if (!userSnap.hasData) {
                  return const SizedBox();
                }

                final userData = userSnap.data!.data() ?? <String, dynamic>{};
                if (userData.isEmpty) return const SizedBox();

                final username = userData['username'] ?? "Unknown";
                final profileUrl = userData['profileImageUrl'] ?? "";

                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection("users")
                      .doc(currentUid)
                      .snapshots(),
                  builder: (context, currentUserSnap) {
                    if (!currentUserSnap.hasData) return const SizedBox();
                    final currentData =
                        currentUserSnap.data!.data() ?? <String, dynamic>{};
                    final List<String> myFollowing = List<String>.from(
                      currentData['following'] ?? [],
                    );
                    final bool isFollowing = myFollowing.contains(uid);

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        leading: CircleAvatar(
                          radius: 26,
                          backgroundImage: profileUrl.isNotEmpty
                              ? NetworkImage(profileUrl)
                              : null,
                          backgroundColor: Colors.orange.shade100,
                          child: profileUrl.isEmpty
                              ? const Icon(Icons.person, color: Colors.white70)
                              : null,
                        ),
                        title: Text(
                          username,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  OtherUserProfilePage(userId: uid.toString()),
                            ),
                          );
                        },
                        trailing: uid == currentUid
                            ? null
                            : ElevatedButton(
                                onPressed: () => _toggleFollow(
                                  uid.toString(),
                                  isFollowing,
                                  context,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isFollowing
                                      ? Colors.grey[200]
                                      : const Color(0xFFFF7043),
                                  foregroundColor: isFollowing
                                      ? Colors.black
                                      : Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: Text(
                                  isFollowing ? "Following" : "Follow",
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
