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

  // Accent color chosen from liked version
  final Color accentColor = const Color(0xFFFFA726);

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
      debugPrint('Error picking cover image: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
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
      debugPrint('Error picking step image: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
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
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      final username = userData['username'] ?? user.email?.split('@')[0] ?? 'Unknown';
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
      final ingredients = ingredientControllers.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();

      // 5) Create recipe object
      final recipeId = FirebaseFirestore.instance.collection('recipes').doc().id;
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
      final recipeRef = FirebaseFirestore.instance.collection('recipes').doc(recipeId);
      batch.set(recipeRef, recipe.toJson());

      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      batch.update(userRef, {
        'posts': FieldValue.arrayUnion([recipeId]),
      });

      await batch.commit();

      setState(() => _isUploading = false);
      _showSuccessDialog();
    } catch (e, st) {
      setState(() => _isUploading = false);
      debugPrint('Upload error: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  // ---------------- UI building ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F1), // soft warm background
      // orange gradient AppBar for a cozy look
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accentColor, accentColor.withOpacity(0.85)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            boxShadow: [BoxShadow(color: accentColor.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, "/home"),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "Step $step/2",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // content
          step == 1 ? _buildStep1() : _buildStep2(),
          // upload overlay
          if (_isUploading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator(color: Colors.orange)),
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      );

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.10), blurRadius: 10, offset: const Offset(0, 6))],
      ),
      child: child,
    );
  }

  // ---------------- Step 1 ----------------
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle("Cover Photo"),
                GestureDetector(
                  onTap: pickCoverImage,
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accentColor.withOpacity(0.25)),
                      color: accentColor.withOpacity(0.06),
                    ),
                    child: coverImageBytes == null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.image_outlined, size: 48, color: Colors.orange),
                                SizedBox(height: 6),
                                Text("Add Cover Photo", style: TextStyle(color: Colors.black54)),
                              ],
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(coverImageBytes!, fit: BoxFit.cover, width: double.infinity),
                          ),
                  ),
                ),
              ],
            ),
          ),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle("Food Name"),
                TextField(
                  controller: foodNameController,
                  decoration: InputDecoration(
                    hintText: "Enter food name",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
                const SizedBox(height: 16),
                _sectionTitle("Description"),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: "Describe your dish",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          _buildCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionTitle("Cooking Duration (minutes)"),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () {
                      if (cookingDuration > 1) setState(() => cookingDuration--);
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(text: cookingDuration.round().toString()),
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (val) {
                        final parsed = int.tryParse(val);
                        if (parsed != null && parsed > 0) setState(() => cookingDuration = parsed.toDouble());
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.green),
                    onPressed: () {
                      if (cookingDuration < 300) setState(() => cookingDuration++);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _sectionTitle("Category"),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                items: ["Food", "Drink", "Dessert", "Snack"]
                    .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                    .toList(),
                onChanged: (val) => setState(() => selectedCategory = val ?? "Food"),
                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              onPressed: () => setState(() => step = 2),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text("Next", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ---------------- Step 2 ----------------
  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle("Ingredients"),
                ...List.generate(ingredientControllers.length, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: ingredientControllers[i],
                            decoration: InputDecoration(
                              hintText: "Enter ingredient",
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: addIngredient,
                    icon: const Icon(Icons.add),
                    label: const Text("Add Ingredient"),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: accentColor.withOpacity(0.6)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      foregroundColor: accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle("Steps"),
                ...List.generate(stepControllers.length, (i) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: stepControllers[i],
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: "Describe step ${i + 1}",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => pickStepImage(i),
                            icon: const Icon(Icons.camera_alt, color: Colors.orange),
                            label: const Text("Add Step Image"),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: accentColor.withOpacity(0.3)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (i < stepImageBytesList.length && stepImageBytesList[i] != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(stepImageBytesList[i]!, width: 60, height: 60, fit: BoxFit.cover),
                            ),
                          const Spacer(),
                          if (stepControllers.length > 1)
                            IconButton(
                              onPressed: () => removeStepField(i),
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                }),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: addStepField,
                    icon: const Icon(Icons.add),
                    label: const Text("Add More Steps"),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: accentColor.withOpacity(0.6)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      foregroundColor: accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => step = 1),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accentColor,
                      side: BorderSide(color: accentColor.withOpacity(0.9)),
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text("Back"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _uploadRecipe,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text("Upload", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
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
                backgroundColor: accentColor,
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
