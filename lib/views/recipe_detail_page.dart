import 'package:final_proj/services/follow_and_unfollow_services.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/recipe.dart';

class RecipeDetailPage extends StatelessWidget {
  final Recipe recipe;

  const RecipeDetailPage({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Cover image
          SliverAppBar(
            expandedHeight: 250,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: recipe.coverImageUrl.isNotEmpty
                  ? Image.network(
                      recipe.coverImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey.shade300,
                        child: const Center(
                          child: Icon(
                            Icons.broken_image,
                            size: 48,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    )
                  : Container(color: Colors.grey.shade300),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + category + duration
                  Text(
                    recipe.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${recipe.category} • ${recipe.cookingDuration} mins",
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),

                  // Author + likes + FOLLOW BUTTON
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundImage: recipe.authorProfileImage.isNotEmpty
                            ? NetworkImage(recipe.authorProfileImage)
                            : null,
                        child: recipe.authorProfileImage.isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        recipe.authorName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      // FOLLOW BUTTON
                      if (recipe.authorId != currentUid)
                        ElevatedButton(
                          onPressed: () async {
                            await FollowService().toggleFollow(
                              currentUid,
                              recipe.authorId,
                              FirebaseAuth.instance.currentUser!.displayName ??
                                  "User",
                              FirebaseAuth.instance.currentUser!.photoURL ?? "",
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text("Follow"),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Likes row
                  Row(
                    children: [
                      const Icon(Icons.favorite, color: Colors.red),
                      const SizedBox(width: 4),
                      Text("${recipe.likes} Likes"),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Description
                  const Text(
                    "Description",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(recipe.description),
                  const SizedBox(height: 20),

                  // Ingredients
                  const Text(
                    "Ingredients",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: recipe.ingredients.map((ingredient) {
                      return Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 18,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(ingredient),
                        ],
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Steps
                  const Text(
                    "Steps",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    children: recipe.steps.asMap().entries.map((entry) {
                      final index = entry.key + 1;
                      final step = entry.value;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.orange,
                                  radius: 14,
                                  child: Text(
                                    "$index",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(step.description)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (step.imageUrl.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  step.imageUrl,
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        height: 150,
                                        width: double.infinity,
                                        color: Colors.grey.shade300,
                                        child: const Center(
                                          child: Icon(
                                            Icons.broken_image,
                                            size: 48,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
