import 'package:final_proj/model/recipe_step.dart';

class Recipe {
  final String recipeId;
  final String title;
  final String coverPhoto; // main cover image
  final String cookingDuration; // e.g. "45 mins"
  final List<String> ingredients;
  final List<RecipeStep> steps; // steps with images
  final int likes;
  final String authorId; // userId
  final String authorName; // username
  final String authorProfileImg; // profile image
  final DateTime createdAt;

  Recipe({
    required this.recipeId,
    required this.title,
    required this.coverPhoto,
    required this.cookingDuration,
    required this.ingredients,
    required this.steps,
    required this.likes,
    required this.authorId,
    required this.authorName,
    required this.authorProfileImg,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'recipeId': recipeId,
      'title': title,
      'coverPhoto': coverPhoto,
      'cookingDuration': cookingDuration,
      'ingredients': ingredients,
      'steps': steps.map((s) => s.toMap()).toList(),
      'likes': likes,
      'authorId': authorId,
      'authorName': authorName,
      'authorProfileImg': authorProfileImg,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Recipe.fromMap(Map<String, dynamic> map) {
    return Recipe(
      recipeId: map['recipeId'] ?? '',
      title: map['title'] ?? '',
      coverPhoto: map['coverPhoto'] ?? '',
      cookingDuration: map['cookingDuration'] ?? '',
      ingredients: List<String>.from(map['ingredients'] ?? []),
      steps: (map['steps'] as List<dynamic>)
          .map((s) => RecipeStep.fromMap(s))
          .toList(),
      likes: map['likes'] ?? 0,
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      authorProfileImg: map['authorProfileImg'] ?? '',
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}
