import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../model/recipe.dart';
import 'recipe_detail_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key, required String userId}) : super(key: key);

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String query = "";
  String selectedCategory = "All";
  double cookingDuration = 60; // default max minutes

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: "Search",
                    border: InputBorder.none,
                  ),
                  onChanged: (val) {
                    setState(() {
                      query = val.trim();
                    });
                    _saveSearch(val.trim());
                  },
                ),
              ),
              if (_searchController.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _searchController.clear();
                      query = "";
                    });
                  },
                  child: const Icon(Icons.close, color: Colors.grey),
                ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.black),
            onPressed: _openFilterDialog,
          ),
        ],
      ),
      body: query.isEmpty ? _buildSuggestions() : _buildSearchResults(query),
    );
  }

  /// Save search to Firestore (for dynamic recent searches)
  Future<void> _saveSearch(String search) async {
    if (search.isEmpty) return;
    final ref = FirebaseFirestore.instance.collection("recentSearches");
    await ref.doc(search).set({
      "query": search,
      "timestamp": FieldValue.serverTimestamp(),
    });
  }

  Widget _buildSuggestions() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("recentSearches")
          .orderBy("timestamp", descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final recent = snapshot.data?.docs
            .map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return (data["query"] ?? "") as String;
            })
            .where((q) => q.isNotEmpty)
            .toList();

        if (recent == null || recent.isEmpty) {
          return const Center(child: Text("No recent searches"));
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text("Recent", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...recent.map(
              (item) => ListTile(
                leading: const Icon(Icons.history, color: Colors.grey),
                title: Text(item),
                onTap: () {
                  setState(() {
                    query = item;
                    _searchController.text = item;
                  });
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchResults(String searchQuery) {
    Query queryRef = FirebaseFirestore.instance.collection('recipes');

    // search filter
    queryRef = queryRef
        .where('title', isGreaterThanOrEqualTo: searchQuery)
        .where('title', isLessThanOrEqualTo: "$searchQuery\uf8ff");

    // category filter
    if (selectedCategory != "All") {
      queryRef = queryRef.where('category', isEqualTo: selectedCategory);
    }

    // duration filter
    queryRef = queryRef.where(
      'cookingDuration',
      isLessThanOrEqualTo: cookingDuration.toInt(),
    );

    return StreamBuilder<QuerySnapshot>(
      stream: queryRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No results found"));
        }

        final results = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return Recipe.fromJson(data);
        }).toList();

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.8,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final recipe = results[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecipeDetailPage(recipe: recipe),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: recipe.coverImageUrl.isNotEmpty
                        ? Image.network(
                            recipe.coverImageUrl,
                            height: 100,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            height: 100,
                            color: Colors.grey.shade300,
                            child: const Center(child: Icon(Icons.image)),
                          ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    recipe.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    "${recipe.category} • ${recipe.cookingDuration} mins",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Add a Filter",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 20),

                  // Category filter
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: ["All", "Food", "Drink"].map((cat) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: selectedCategory == cat,
                          selectedColor: Colors.orange,
                          onSelected: (_) {
                            setModalState(() {
                              selectedCategory = cat;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Duration filter
                  const Text("Cooking Duration (in minutes)"),
                  Slider(
                    value: cookingDuration,
                    min: 10,
                    max: 60,
                    divisions: 5,
                    label: "${cookingDuration.round()} mins",
                    activeColor: Colors.orange,
                    onChanged: (val) {
                      setModalState(() {
                        cookingDuration = val;
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        child: const Text("Cancel"),
                        onPressed: () => Navigator.pop(context),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child: const Text("Done"),
                        onPressed: () {
                          setState(() {});
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
