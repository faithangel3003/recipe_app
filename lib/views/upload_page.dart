import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/recipe.dart';
import '../services/cloudinary_service.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  int step = 1;

  // Inputs
  final TextEditingController foodNameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final List<TextEditingController> ingredientControllers = [
    TextEditingController(),
  ];
  final List<TextEditingController> stepControllers = [TextEditingController()];

  // Images - Use Uint8List for web compatibility
  Uint8List? coverImageBytes;
  List<Uint8List?> stepImageBytesList = <Uint8List?>[];

  double cookingDuration = 30;
  String selectedCategory = "Food";

  final ImagePicker _picker = ImagePicker();
  final CloudinaryService _cloudinary = CloudinaryService();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    // always at least one step field and one slot for image
    if (stepControllers.isEmpty) {
      stepControllers.add(TextEditingController());
      stepImageBytesList.add(null);
    }
  }

  // ---------------- image pickers ----------------
  Future<void> pickCoverImage() async {
    try {
      final XFile? xFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (xFile != null) {
        final bytes = await xFile.readAsBytes();
        setState(() => coverImageBytes = bytes);
      }
    } catch (e) {
      print('Error picking cover image: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  Future<void> pickStepImage(int index) async {
    try {
      final XFile? xFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (xFile != null) {
        final bytes = await xFile.readAsBytes();
        setState(() {
          if (index < stepImageBytesList.length) {
            stepImageBytesList[index] = bytes;
          } else {
            // If the list is not long enough, add null entries until we reach the index
            while (stepImageBytesList.length <= index) {
              stepImageBytesList.add(null);
            }
            stepImageBytesList[index] = bytes;
          }
        });
      }
    } catch (e) {
      print('Error picking step image: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  // ---------------- add/remove fields ----------------
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
      stepImageBytesList.add(null);
    });
  }

  void removeStepField(int index) {
    if (stepControllers.length <= 1) return;
    setState(() {
      stepControllers[index].dispose();
      stepControllers.removeAt(index);
      stepImageBytesList.removeAt(index);
    });
  }

  // ---------------- upload flow ----------------
  Future<void> _uploadRecipe() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to upload')),
      );
      return;
    }
    if (foodNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a food name')));
      return;
    }
    if (coverImageBytes == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please add a cover image')));
      return;
    }

    setState(() => _isUploading = true);

    try {
      // 1) Get user profile
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};
      final username =
          userData['username'] ?? user.email?.split('@')[0] ?? 'Unknown';
      final profileImageUrl = userData['profileImageUrl'] ?? '';

      // 2) Upload cover image using bytes
      final coverUrl = await _cloudinary.uploadImageBytes(
        coverImageBytes!,
        folder: 'recipes/covers',
      );

      // 3) Upload step images and build RecipeStep list
      final List<RecipeStep> steps = [];
      for (int i = 0; i < stepControllers.length; i++) {
        String imageUrl = '';
        if (i < stepImageBytesList.length && stepImageBytesList[i] != null) {
          imageUrl = await _cloudinary.uploadImageBytes(
            stepImageBytesList[i]!,
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

      // 4) Build ingredients list
      final ingredients = ingredientControllers
          .map((c) => c.text.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      // 5) Create recipe object
      final recipeId = FirebaseFirestore.instance
          .collection('recipes')
          .doc()
          .id;
      final recipe = Recipe(
        id: recipeId,
        authorId: user.uid,
        authorName: username,
        authorProfileImage: profileImageUrl,
        coverImageUrl: coverUrl,
        title: foodNameController.text.trim(),
        description: descriptionController.text.trim(),
        ingredients: ingredients,
        steps: steps,
        cookingDuration: cookingDuration.toInt(),
        category: selectedCategory,
        likedBy: [],
        createdAt: DateTime.now(),
      );

      // 6) Write to Firestore
      final batch = FirebaseFirestore.instance.batch();
      final recipeRef = FirebaseFirestore.instance
          .collection('recipes')
          .doc(recipeId);
      batch.set(recipeRef, recipe.toJson());

      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      batch.update(userRef, {
        'posts': FieldValue.arrayUnion([recipeId]),
      });

      await batch.commit();

      setState(() => _isUploading = false);
      _showSuccessDialog();
    } catch (e, st) {
      setState(() => _isUploading = false);
      debugPrint('Upload error: $e\n$st');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  // ---------------- UI building ----------------
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
              onPressed: () => Navigator.pushReplacementNamed(context, "/home"),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.black),
              ),
            ),
            Text("1/2", style: TextStyle(color: Colors.black.withOpacity(0.6))),
          ],
        ),
      ),
      body: Stack(
        children: [
          step == 1 ? _buildStep1() : _buildStep2(),
          if (_isUploading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
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
              child: coverImageBytes == null
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.image, size: 40),
                          Text("Add Cover Photo"),
                          Text(
                            "(up to 4 Mb)",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        coverImageBytes!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // Rest of your step 1 UI remains the same...
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

          // ... (keep the rest of your step 1 UI exactly as it was)
          // Only changed the image display part
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
                  if (cookingDuration > 1) {
                    setState(() => cookingDuration--);
                  }
                },
              ),
              Expanded(
                child: TextField(
                  controller: TextEditingController(
                    text: cookingDuration.round().toString(),
                  ),
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    final parsed = int.tryParse(val);
                    if (parsed != null && parsed > 0) {
                      setState(() => cookingDuration = parsed.toDouble());
                    }
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.green),
                onPressed: () {
                  if (cookingDuration < 300) {
                    setState(() => cookingDuration++);
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Text("Category", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: selectedCategory,
            items: ["Food", "Drink", "Dessert", "Snack"].map((cat) {
              return DropdownMenuItem(value: cat, child: Text(cat));
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedCategory = value ?? "Food";
              });
            },
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: () => setState(() => step = 2),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text("Next"),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
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

          const Text("Steps", style: TextStyle(fontWeight: FontWeight.bold)),
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
                    if (i < stepImageBytesList.length &&
                        stepImageBytesList[i] != null)
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: Image.memory(
                          stepImageBytesList[i]!,
                          fit: BoxFit.cover,
                        ),
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

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => step = 1),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text("Back"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _uploadRecipe,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text("Upload"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- success dialog ----------------
  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("🎉", style: TextStyle(fontSize: 50)),
            const SizedBox(height: 10),
            const Text(
              "Upload Success",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Your recipe has been uploaded,\nyou can see it on your profile",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/home');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text("Back to Home"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    foodNameController.dispose();
    descriptionController.dispose();
    for (final c in ingredientControllers) c.dispose();
    for (final c in stepControllers) c.dispose();
    super.dispose();
  }
}
