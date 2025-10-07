import 'package:cloud_firestore/cloud_firestore.dart';

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
  final List<String> likedBy;
  final DateTime createdAt;
  final bool isHidden;
  final bool isArchived; // soft-deletion / archival status

  int get likes => likedBy.length;

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
    required this.likedBy,
    required this.createdAt,
    this.isHidden = false,
    this.isArchived = false,
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
    'likedBy': likedBy,
    'createdAt': createdAt.toIso8601String(),
    'isHidden': isHidden,
    'isArchived': isArchived,
  };

  factory Recipe.fromJson(Map<String, dynamic> json) {
    // Handle createdAt field - it could be string (ISO) or timestamp
    DateTime parseCreatedAt(dynamic createdAtValue) {
      if (createdAtValue == null) return DateTime.now();

      if (createdAtValue is String) {
        // Try parsing as ISO string
        return DateTime.tryParse(createdAtValue) ?? DateTime.now();
      } else if (createdAtValue is num) {
        // Handle timestamp (milliseconds or seconds)
        return DateTime.fromMillisecondsSinceEpoch(
          createdAtValue is int
              ? createdAtValue
              : createdAtValue.toInt() * 1000,
        );
      } else if (createdAtValue is Timestamp) {
        // Handle Firestore Timestamp
        return createdAtValue.toDate();
      }

      return DateTime.now();
    }

    return Recipe(
      id: json['id']?.toString() ?? '',
      authorId: json['authorId']?.toString() ?? '',
      authorName: json['authorName']?.toString() ?? '',
      authorProfileImage: json['authorProfileImage']?.toString() ?? '',
      coverImageUrl: json['coverImageUrl']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      ingredients: List<String>.from(json['ingredients'] ?? []),
      steps: (json['steps'] as List<dynamic>? ?? [])
          .map(
            (s) => RecipeStep.fromJson(
              s is Map<String, dynamic> ? s : Map<String, dynamic>.from(s),
            ),
          )
          .toList(),
      cookingDuration: (json['cookingDuration'] as num?)?.toInt() ?? 0,
      category: json['category']?.toString() ?? 'Food',
      likedBy: List<String>.from(json['likedBy'] ?? []),
      createdAt: parseCreatedAt(json['createdAt']),
      isHidden: json['isHidden'] ?? false,
      isArchived: json['isArchived'] ?? false,
    );
  }
}
