class RecipeStep {
  final String description;
  final String imageUrl;

  RecipeStep({required this.description, required this.imageUrl});

  Map<String, dynamic> toJson() => {
    'description': description,
    'imageUrl': imageUrl,
  };

  factory RecipeStep.fromJson(Map<String, dynamic> json) => RecipeStep(
    description: json['description'] ?? '',
    imageUrl: json['imageUrl'] ?? '',
  );
}

class Recipe {
  // Removed duplicate toJson()
  final String id;
  final String authorId;
  final String authorName;
  final String authorProfileImage;
  final String coverImageUrl;
  final String title;
  final String description;
  final List<String> ingredients;
  final List<RecipeStep> steps;
  final int cookingDuration;
  final String category;

  final int likes;
  final DateTime createdAt;

  Recipe({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorProfileImage,
    required this.coverImageUrl,
    required this.title,
    required this.description,
    required this.ingredients,
    required this.steps,
    required this.cookingDuration,
    required this.category,
    required this.likes,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'authorId': authorId,
    'authorName': authorName,
    'authorProfileImage': authorProfileImage,
    'coverImageUrl': coverImageUrl,
    'title': title,
    'description': description,
    'ingredients': ingredients,
    'steps': steps.map((s) => s.toJson()).toList(),
    'cookingDuration': cookingDuration,
    'category': category,
    'likes': likes,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
    id: json['id'] ?? '',
    authorId: json['authorId'] ?? '',
    authorName: json['authorName'] ?? '',
    authorProfileImage: json['authorProfileImage'] ?? '',
    coverImageUrl: json['coverImageUrl'] ?? '',
    title: json['title'] ?? '',
    description: json['description'] ?? '',
    ingredients: List<String>.from(json['ingredients'] ?? []),
    steps: (json['steps'] as List<dynamic>? ?? [])
        .map((s) => RecipeStep.fromJson(s))
        .toList(),
    cookingDuration: json['cookingDuration'] ?? 0,
    likes: json['likes'] ?? 0,
    createdAt: DateTime.parse(
      json['createdAt'] ?? DateTime.now().toIso8601String(),
    ),
    category: json['category'] ?? 'Food',
  );
}
