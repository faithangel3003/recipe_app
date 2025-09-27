import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text("Notifications")),
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

          final notifs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: notifs.length,
            itemBuilder: (context, index) {
              final data = notifs[index].data() as Map<String, dynamic>;
              final type = data["type"];
              final fromUser = data["fromUsername"] ?? "Someone";
              final fromImage = data["fromUserImage"] ?? "";
              final createdAt = (data["createdAt"] as Timestamp?)?.toDate();

              String message = "";
              if (type == "like") {
                message = "$fromUser liked your recipe";
              } else if (type == "follow") {
                message = "$fromUser started following you";
              }

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: fromImage.isNotEmpty
                      ? NetworkImage(fromImage)
                      : null,
                  child: fromImage.isEmpty ? const Icon(Icons.person) : null,
                ),
                title: Text(message),
                subtitle: createdAt != null ? Text(createdAt.toString()) : null,
              );
            },
          );
        },
      ),
    );
  }
}
