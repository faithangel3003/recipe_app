import 'package:final_proj/services/like_services.dart';
import 'package:final_proj/views/recipe_detail_page.dart';
import 'package:final_proj/views/search_page.dart'; // ✅ import search page
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/recipe.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(""),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔎 Search Bar → navigates to SearchPage
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SearchPage(userId: ''),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, color: Colors.grey),
                    SizedBox(width: 8),
                    Text(
                      "Search",
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Category
            const Text(
              "Category",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildCategoryChip("All", true),
                const SizedBox(width: 10),
                _buildCategoryChip("Food", false),
                const SizedBox(width: 10),
                _buildCategoryChip("Drink", false),
              ],
            ),
            const SizedBox(height: 20),

            // Tabs (Left / Right)
            DefaultTabController(
              length: 2,
              child: Expanded(
                child: Column(
                  children: [
                    const TabBar(
                      labelColor: Colors.green,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.green,
                      tabs: [
                        Tab(text: "Left"),
                        Tab(text: "Right"),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildFoodGrid(),
                          const Center(child: Text("Right Tab Content")),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Category Chip Widget
  static Widget _buildCategoryChip(String text, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? Colors.orange : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: selected ? Colors.white : Colors.black,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // Food Grid
  static Widget _buildFoodGrid() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please log in to like recipes.'));
    }
    final userId = user.uid;
    final userName = user.displayName ?? "Unknown";
    final userImage = user.photoURL ?? "";

    return StreamBuilder<QuerySnapshot>(
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

        final recipes = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return Recipe.fromJson(data);
        }).toList();

        return GridView.builder(
          padding: const EdgeInsets.only(top: 10),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.8,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: recipes.length,
          itemBuilder: (context, index) {
            final item = recipes[index];
            return _FoodGridItem(
              item: item,
              userId: userId,
              userName: userName,
              userImage: userImage,
            );
          },
        );
      },
    );
  }
}

// 🔥 Food Item Card
class _FoodGridItem extends StatefulWidget {
  final Recipe item;
  final String userId;
  final String userName;
  final String userImage;
  const _FoodGridItem({
    required this.item,
    required this.userId,
    required this.userName,
    required this.userImage,
    Key? key,
  }) : super(key: key);

  @override
  State<_FoodGridItem> createState() => _FoodGridItemState();
}

class _FoodGridItemState extends State<_FoodGridItem> {
  late bool _isLiked;
  late int _likesCount;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.item.likedBy.contains(widget.userId);
    _likesCount = widget.item.likes;
  }

  Future<void> _handleLike() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    final bool originalIsLiked = _isLiked;
    final int originalLikesCount = _likesCount;

    setState(() {
      if (_isLiked) {
        _likesCount--;
      } else {
        _likesCount++;
      }
      _isLiked = !_isLiked;
    });

    try {
      await LikeService().toggleLike(
        widget.item.id,
        widget.userId,
        widget.userName,
        widget.userImage,
      );
    } catch (e) {
      setState(() {
        _isLiked = originalIsLiked;
        _likesCount = originalLikesCount;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update like: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RecipeDetailPage(recipe: item)),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: item.coverImageUrl.isNotEmpty
                    ? Image.network(
                        item.coverImageUrl,
                        height: 100,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 100,
                            color: Colors.grey.shade300,
                            child: const Center(
                              child: Icon(Icons.broken_image, size: 40),
                            ),
                          );
                        },
                      )
                    : Container(
                        height: 100,
                        color: Colors.grey.shade300,
                        child: const Center(child: Icon(Icons.image, size: 40)),
                      ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: GestureDetector(
                  onTap: _handleLike,
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.9),
                    radius: 16,
                    child: _isLoading
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _isLiked ? Icons.favorite : Icons.favorite_border,
                            color: _isLiked ? Colors.red : Colors.grey,
                            size: 18,
                          ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.authorName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.category} • ${item.cookingDuration} mins',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.favorite, color: Colors.red, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '$_likesCount likes',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
