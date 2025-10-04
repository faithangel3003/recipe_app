import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'other_user_page.dart';

class FollowListPage extends StatelessWidget {
  final String userId;
  final String type; // "followers" or "following"

  const FollowListPage({super.key, required this.userId, required this.type});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(type == "followers" ? "Followers" : "Following"),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .doc(userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.data() ?? <String, dynamic>{};
          final List<dynamic> ids = List<dynamic>.from(data[type] ?? []);

          if (ids.isEmpty) {
            return Center(child: Text("No $type yet"));
          }

          return ListView.builder(
            itemCount: ids.length,
            itemBuilder: (context, index) {
              final uid = ids[index];
              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance
                    .collection("users")
                    .doc(uid.toString())
                    .get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) {
                    return const ListTile(title: Text("Loading..."));
                  }
                  final userData = userSnap.data!.data() ?? <String, dynamic>{};

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                          (userData['profileImageUrl'] != null &&
                              userData['profileImageUrl'].isNotEmpty)
                          ? NetworkImage(userData['profileImageUrl'])
                          : null,
                      child:
                          (userData['profileImageUrl'] == null ||
                              userData['profileImageUrl'].isEmpty)
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(userData['username'] ?? "Unknown"),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              OtherUserProfilePage(userId: uid.toString()),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
