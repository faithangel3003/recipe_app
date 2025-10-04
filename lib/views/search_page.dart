import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/recipe.dart';
import 'recipe_detail_page.dart';
import '../services/like_services.dart';

class SearchPage extends StatefulWidget {
  final String userId;
  const SearchPage({Key? key, required this.userId}) : super(key: key);
  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String query = "";
  bool isLoading = false;
  List<Map<String, dynamic>> results = [];

  // Fetch recipes from Firestore and perform local fuzzy matching.
  Future<void> searchRecipes(String q) async {
    final String trimmed = q.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      isLoading = true;
      results = [];
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('recipes')
          .get();

      print('Fetched ${snapshot.docs.length} recipes');
      final List<Map<String, dynamic>> matches = [];
      final searchLower = trimmed.toLowerCase();

      // First try exact matches
      for (final doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;

        final title = (data['title'] ?? '').toString().toLowerCase();
        if (title == searchLower) {
          matches.add(data);
          print('Exact match: $title');
        }
      }

      // If no exact matches, try contains
      if (matches.isEmpty) {
        for (final doc in snapshot.docs) {
          final data = doc.data();
          data['id'] = doc.id;

          final title = (data['title'] ?? '').toString().toLowerCase();
          if (title.contains(searchLower)) {
            matches.add(data);
            print('Substring match: $title');
          }
        }
      }

      // If still no matches, try fuzzy (very permissive)
      if (matches.isEmpty) {
        for (final doc in snapshot.docs) {
          final data = doc.data();
          data['id'] = doc.id;

          final title = (data['title'] ?? '').toString().toLowerCase();
          // Split into words and check each
          final words = title.split(' ');
          for (final word in words) {
            final dist = _levenshtein(word, searchLower);
            // Accept if Levenshtein distance is small relative to word length
            if (dist <= 3 || dist <= word.length ~/ 2) {
              matches.add(data);
              print('Fuzzy match: $title (distance: $dist)');
              break;
            }
          }
        }
      }

      print('Found ${matches.length} total matches');

      setState(() {
        results = matches;
        isLoading = false;
      });
    } catch (e) {
      print('Search error: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  int _levenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    List<int> prev = List.generate(b.length + 1, (i) => i);
    List<int> curr = List.filled(b.length + 1, 0);

    for (int i = 0; i < a.length; i++) {
      curr[0] = i + 1;
      for (int j = 0; j < b.length; j++) {
        curr[j + 1] = min(
          prev[j + 1] + 1,
          min(curr[j] + 1, prev[j] + (a[i] != b[j] ? 1 : 0)),
        );
      }
      final temp = prev;
      prev = curr;
      curr = temp;
    }
    return prev[b.length];
  }

  int min(int a, int b) => a < b ? a : b;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  final val = _searchController.text.trim();
                  if (val.isNotEmpty) {
                    setState(() => query = val);
                    searchRecipes(val);
                  }
                },
                child: const Icon(Icons.search, color: Colors.grey),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: "Search recipes...",
                    border: InputBorder.none,
                  ),
                  onSubmitted: (val) {
                    setState(() => query = val);
                    searchRecipes(val);
                  },
                ),
              ),
              if (_searchController.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _searchController.clear();
                      query = "";
                      results.clear();
                    });
                  },
                  child: const Icon(Icons.close, color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : results.isEmpty
          ? const Center(child: Text("No results found"))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 20,
                childAspectRatio: 0.90,
              ),
              itemCount: results.length,
              itemBuilder: (context, index) {
                final recipe = Recipe.fromJson(results[index]);
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) {
                  return const Center(
                    child: Text('Please log in to like recipes.'),
                  );
                }
                final userId = user.uid;
                final userName = user.displayName ?? "Unknown";
                final userImage = user.photoURL ?? "";

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _FoodGridItem(
                    item: recipe,
                    userId: userId,
                    userName: userName,
                    userImage: userImage,
                  ),
                );
              },
            ),
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
        FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(item.authorId)
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
