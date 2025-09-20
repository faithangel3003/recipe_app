class RecipeStep {
  final int stepNumber;
  final String description;
  final String imageUrl; // step image

  RecipeStep({
    required this.stepNumber,
    required this.description,
    required this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'stepNumber': stepNumber,
      'description': description,
      'imageUrl': imageUrl,
    };
  }

  factory RecipeStep.fromMap(Map<String, dynamic> map) {
    return RecipeStep(
      stepNumber: map['stepNumber'] ?? 0,
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
    );
  }
}
