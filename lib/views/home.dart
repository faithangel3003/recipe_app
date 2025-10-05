import 'package:final_proj/services/like_services.dart';
import 'package:final_proj/views/recipe_detail_page.dart';
import 'package:final_proj/views/search_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/recipe.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String selectedCategory = "All"; // 🔥 selected category state

  @override
  Widget build(BuildContext context) {
    return Scaffold(
       appBar: AppBar(
  automaticallyImplyLeading: false,
  elevation: 0,
  flexibleSpace: Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.orangeAccent, Colors.deepOrange],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ),
  title: Row(
    children: [
      Image.asset('assets/logo.png', height: 36),
      const SizedBox(width: 10),
      const Text(
        "INGRDNTS",
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  ),
),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔎 Search Bar
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCategoryChip("All"),
                  const SizedBox(width: 10),
                  _buildCategoryChip("Food"),
                  const SizedBox(width: 10),
                  _buildCategoryChip("Drink"),
                  const SizedBox(width: 10),
                  _buildCategoryChip("Snack"),
                  const SizedBox(width: 10),
                  _buildCategoryChip("Dessert"),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Tabs
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
                        Tab(text: "For You"),
                        Tab(text: "Following"),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [_buildFoodGrid(), _buildFollowingFoodGrid()],
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

  // Category Chip (now clickable)
  Widget _buildCategoryChip(String text) {
    final bool selected = (text == selectedCategory);
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedCategory = text;
        });
      },
      child: Container(
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
      ),
    );
  }

  // Following Food Grid
  Widget _buildFollowingFoodGrid() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(
        child: Text('Please log in to see followed recipes.'),
      );
    }
    final userId = user.uid;
    final userName = user.displayName ?? "Unknown";
    final userImage = user.photoURL ?? "";

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!userSnapshot.hasData || userSnapshot.data == null) {
          return const Center(child: Text('Unable to load user data'));
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
        if (userData == null) {
          return const Center(child: Text('User data not found'));
        }

        final following = List<String>.from(userData['following'] ?? []);

        if (following.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Follow some chefs to see their recipes here!',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

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
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.restaurant,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No recipes yet from people you follow',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              );
            }

            final recipes = snapshot.data!.docs
                .map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return Recipe.fromJson(data);
                })
                .where(
                  (recipe) =>
                      following.contains(recipe.authorId) &&
                      (selectedCategory == "All" ||
                          recipe.category == selectedCategory),
                )
                .toList();

            return GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 20,
                childAspectRatio: 0.90,
              ),
              itemCount: recipes.length,
              itemBuilder: (context, index) {
                final item = recipes[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _FoodGridItem(
                    item: item,
                    userId: userId,
                    userName: userName,
                    userImage: userImage,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // Food Grid (For You) with filtering
  Widget _buildFoodGrid() {
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

        final recipes = snapshot.data!.docs
            .map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return Recipe.fromJson(data);
            })
            .where(
              (recipe) =>
                  !recipe.isHidden &&
                  (selectedCategory == "All" ||
                      recipe.category == selectedCategory),
            )
            .toList();

        return GridView.builder(
          padding: const EdgeInsets.all(10),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 20,
            childAspectRatio: 0.90,
          ),
          itemCount: recipes.length,
          itemBuilder: (context, index) {
            final item = recipes[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _FoodGridItem(
                item: item,
                userId: userId,
                userName: userName,
                userImage: userImage,
              ),
            );
          },
        );
      },
    );
  }
}

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
    setState(() => _isLoading = true);

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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 👤 Author Row ABOVE card
        FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(item.authorId) // must exist in Recipe
              .get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox(height: 30);
            final userData = snapshot.data!.data() as Map<String, dynamic>?;
            if (userData == null) return const SizedBox(height: 30);

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundImage:
                        userData['profileImageUrl'] != null &&
                            userData['profileImageUrl'].isNotEmpty
                        ? NetworkImage(userData['profileImageUrl'])
                        : null,
                    child:
                        (userData['profileImageUrl'] == null ||
                            userData['profileImageUrl'].isEmpty)
                        ? const Icon(Icons.person, size: 16)
                        : null,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      userData['username'] ?? "Unknown",
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // 📌 Recipe Card (only image + heart)
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RecipeDetailPage(recipe: item),
                ),
              );
            },
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: item.coverImageUrl.isNotEmpty
                      ? Image.network(
                          item.coverImageUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(child: Icon(Icons.image)),
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
          ),
        ),

        const SizedBox(height: 6),

        // 📌 Title + Meta + Likes BELOW card
        Text(
          item.title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          maxLines: 1,
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
            Icon(Icons.favorite, color: Colors.red.shade400, size: 14),
            const SizedBox(width: 4),
            Text('$_likesCount likes', style: const TextStyle(fontSize: 12)),
          ],
        ),
      ],
    );
  }
}
