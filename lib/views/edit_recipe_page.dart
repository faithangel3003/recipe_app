import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/recipe.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/cloudinary_service.dart';

class EditRecipePage extends StatefulWidget {
  final String recipeId;
  final Map<String, dynamic> recipeData;

  const EditRecipePage({
    super.key,
    required this.recipeId,
    required this.recipeData,
  });

  @override
  State<EditRecipePage> createState() => _EditRecipePageState();
}

class _EditRecipePageState extends State<EditRecipePage> {
  final ImagePicker _picker = ImagePicker();
  final CloudinaryService _cloudinary = CloudinaryService();

  File? coverImageFile;
  String? coverImageUrl;

  late TextEditingController foodNameController;
  late TextEditingController descriptionController;
  late TextEditingController durationController;
  String selectedCategory = "Food";

  List<TextEditingController> ingredientControllers = [];
  List<TextEditingController> stepControllers = [];
  List<File?> stepImageFiles = [];
  List<String?> stepImageUrls = [];

  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final data = widget.recipeData;
    foodNameController = TextEditingController(text: data['title'] ?? '');
    descriptionController = TextEditingController(
      text: data['description'] ?? '',
    );
    durationController = TextEditingController(
      text: (data['cookingDuration'] ?? 30).toString(),
    );
    selectedCategory = data['category'] ?? 'Food';
    coverImageUrl = data['coverImageUrl'] ?? '';

    // Ingredients
    final ingredients = List<String>.from(data['ingredients'] ?? []);
    ingredientControllers = ingredients.isNotEmpty
        ? ingredients.map((s) => TextEditingController(text: s)).toList()
        : [TextEditingController()];

    // Steps
    final steps = (data['steps'] as List<dynamic>? ?? []);
    if (steps.isNotEmpty) {
      stepControllers = steps
          .map((s) => TextEditingController(text: s['description'] ?? ''))
          .toList();
      stepImageUrls = steps.map((s) => s['imageUrl'] as String? ?? '').toList();
      stepImageFiles = List<File?>.filled(steps.length, null, growable: true);
    } else {
      stepControllers = [TextEditingController()];
      stepImageFiles = [null];
      stepImageUrls = [''];
    }
  }

  Future<void> pickCoverImage() async {
    final XFile? x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (x != null) setState(() => coverImageFile = File(x.path));
  }

  Future<void> pickStepImage(int index) async {
    final XFile? x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (x != null) setState(() => stepImageFiles[index] = File(x.path));
  }

  void addIngredient() {
    setState(() => ingredientControllers.add(TextEditingController()));
  }

  void removeIngredient(int index) {
    if (ingredientControllers.length <= 1) return;
    setState(() {
      ingredientControllers[index].dispose();
      ingredientControllers.removeAt(index);
    });
  }

  void addStepField() {
    setState(() {
      stepControllers.add(TextEditingController());
      stepImageFiles.add(null);
      stepImageUrls.add('');
    });
  }

  void removeStepField(int index) {
    if (stepControllers.length <= 1) return;
    setState(() {
      stepControllers[index].dispose();
      stepControllers.removeAt(index);
      stepImageFiles.removeAt(index);
      stepImageUrls.removeAt(index);
    });
  }

  Future<void> _saveRecipe() async {
    setState(() => _isUploading = true);
    try {
      // Cover image
      String newCoverUrl = coverImageUrl ?? '';
      if (coverImageFile != null) {
        newCoverUrl = await _cloudinary.uploadFile(
          coverImageFile!,
          folder: 'recipes/covers',
        );
      }

      // Step images
      List<RecipeStep> steps = [];
      for (int i = 0; i < stepControllers.length; i++) {
        String imageUrl = stepImageUrls.length > i
            ? stepImageUrls[i] ?? ''
            : '';
        if (stepImageFiles.length > i && stepImageFiles[i] != null) {
          imageUrl = await _cloudinary.uploadFile(
            stepImageFiles[i]!,
            folder: 'recipes/steps',
          );
        }
        steps.add(
          RecipeStep(
            description: stepControllers[i].text.trim(),
            imageUrl: imageUrl,
          ),
        );
      }

      // Ingredients
      final ingredients = ingredientControllers
          .map((c) => c.text.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('recipes')
          .doc(widget.recipeId)
          .update({
            'title': foodNameController.text.trim(),
            'description': descriptionController.text.trim(),
            'coverImageUrl': newCoverUrl,
            'ingredients': ingredients,
            'steps': steps.map((s) => s.toJson()).toList(),
            'cookingDuration': int.tryParse(durationController.text) ?? 0,
            'category': selectedCategory,
          });
      setState(() => _isUploading = false);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.black),
              ),
            ),
            const Text("Edit Recipe", style: TextStyle(color: Colors.black)),
          ],
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover picker & preview
                GestureDetector(
                  onTap: pickCoverImage,
                  child: Container(
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: coverImageFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: kIsWeb
                                ? Image.network(
                                    coverImageUrl ?? '',
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  )
                                : Image.file(
                                    coverImageFile!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  ),
                          )
                        : (coverImageUrl != null && coverImageUrl!.isNotEmpty)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              coverImageUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          )
                        : const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.image, size: 40),
                                Text("Add Cover Photo"),
                                Text(
                                  "(up to 12 Mb)",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Food Name",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: foodNameController,
                  decoration: const InputDecoration(
                    hintText: "Enter food name",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Description",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: "Tell a little about your food",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Cooking Duration (in minutes)",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () {
                        final val = int.tryParse(durationController.text) ?? 1;
                        if (val > 1) {
                          setState(
                            () =>
                                durationController.text = (val - 1).toString(),
                          );
                        }
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: durationController,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.green),
                      onPressed: () {
                        final val = int.tryParse(durationController.text) ?? 1;
                        if (val < 300) {
                          setState(
                            () =>
                                durationController.text = (val + 1).toString(),
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Category
                const Text(
                  "Category",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  items: ["Food", "Drink", "Dessert", "Snack"]
                      .map(
                        (cat) => DropdownMenuItem(value: cat, child: Text(cat)),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedCategory = value ?? "Food";
                    });
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Ingredients",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...List.generate(ingredientControllers.length, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: ingredientControllers[i],
                            decoration: const InputDecoration(
                              hintText: "Enter ingredient",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (ingredientControllers.length > 1)
                          IconButton(
                            onPressed: () => removeIngredient(i),
                            icon: const Icon(
                              Icons.remove_circle,
                              color: Colors.red,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
                OutlinedButton.icon(
                  onPressed: addIngredient,
                  icon: const Icon(Icons.add),
                  label: const Text("Add Ingredient"),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Steps",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...List.generate(stepControllers.length, (i) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: stepControllers[i],
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: "Describe step ${i + 1}",
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => pickStepImage(i),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text("Add Step Image"),
                          ),
                          const SizedBox(width: 8),
                          if (stepImageFiles.length > i &&
                              stepImageFiles[i] != null)
                            Stack(
                              children: [
                                SizedBox(
                                  width: 60,
                                  height: 60,
                                  child: kIsWeb
                                      ? (stepImageUrls.length > i &&
                                                stepImageUrls[i] != null &&
                                                stepImageUrls[i]!.isNotEmpty
                                            ? Image.network(
                                                stepImageUrls[i]!,
                                                fit: BoxFit.cover,
                                              )
                                            : const Icon(Icons.image))
                                      : Image.file(
                                          stepImageFiles[i]!,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        stepImageFiles[i] = null;
                                        // If there was a previous url, keep it unless user wants to clear both
                                      });
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 18,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else if (stepImageUrls.length > i &&
                              stepImageUrls[i] != null &&
                              stepImageUrls[i]!.isNotEmpty)
                            Stack(
                              children: [
                                SizedBox(
                                  width: 60,
                                  height: 60,
                                  child: Image.network(
                                    stepImageUrls[i]!,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        stepImageUrls[i] = '';
                                      });
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 18,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          const Spacer(),
                          if (stepControllers.length > 1)
                            IconButton(
                              onPressed: () => removeStepField(i),
                              icon: const Icon(
                                Icons.remove_circle,
                                color: Colors.red,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                }),
                OutlinedButton.icon(
                  onPressed: addStepField,
                  icon: const Icon(Icons.add),
                  label: const Text("Add More Steps"),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _saveRecipe,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text("Save Changes"),
                ),
              ],
            ),
          ),
          if (_isUploading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    foodNameController.dispose();
    descriptionController.dispose();
    durationController.dispose();
    for (final c in ingredientControllers) {
      c.dispose();
    }
    for (final c in stepControllers) {
      c.dispose();
    }
    super.dispose();
  }
}
