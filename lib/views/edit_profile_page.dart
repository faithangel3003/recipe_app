import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../model/user.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../services/cloudinary_service.dart';

class EditProfilePage extends StatefulWidget {
  final AppUser user;

  const EditProfilePage({super.key, required this.user});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  final TextEditingController _bioController = TextEditingController();

  File? _imageFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.user.username);
    _emailController = TextEditingController(text: widget.user.email);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    String imageUrl = widget.user.profileImageUrl;

    if (_imageFile != null) {
      try {
        final cloudinary = CloudinaryService();
        imageUrl = await cloudinary.uploadFile(
          _imageFile!,
          folder: 'users/profile_images',
        );
      } catch (e) {
        debugPrint('Profile image upload failed: $e');
      }
    }

    final updatedUser = AppUser(
      uid: widget.user.uid,
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      profileImageUrl: imageUrl,
      posts: widget.user.posts,
      likedPosts: widget.user.likedPosts,
      followers: widget.user.followers,
      following: widget.user.following,
      isAdmin: widget.user.isAdmin,
    );

    try {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(widget.user.uid)
          .set(updatedUser.toJson());

      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser != null) {
        if (_emailController.text.trim().isNotEmpty &&
            _emailController.text.trim() != authUser.email) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Email change detected. You may need to re-authenticate to update your email.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        await authUser.updateDisplayName(updatedUser.username);
        if (imageUrl.isNotEmpty && imageUrl != authUser.photoURL) {
          await authUser.updatePhotoURL(imageUrl);
        }
      }

      if (mounted) Navigator.pop(context, updatedUser);
    } catch (e) {
      debugPrint('Failed to save profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: $e'),
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
    // Determine the correct ImageProvider: prefer the freshly picked File, else
    // use NetworkImage for remote URLs and FileImage for local file paths (only on non-web).
    ImageProvider<Object>? profileImageProvider;
    if (_imageFile != null) {
      profileImageProvider = FileImage(_imageFile!);
    } else if (widget.user.profileImageUrl.isNotEmpty) {
      final url = widget.user.profileImageUrl;
      final isNetwork =
          url.startsWith('http') ||
          url.startsWith('https') ||
          url.startsWith('data:');
      final isLocalPath = RegExp(
        r'^[A-Za-z]:\\|^[A-Za-z]:/|^/|^file://',
      ).hasMatch(url);

      if (isNetwork) {
        profileImageProvider = NetworkImage(url);
      } else if (!kIsWeb && isLocalPath) {
        // For Windows paths like C:\Users\... or POSIX /... use FileImage.
        final cleaned = url.replaceFirst('file://', '');
        try {
          profileImageProvider = FileImage(File(cleaned));
        } catch (e) {
          profileImageProvider = null;
        }
      } else {
        // As a last resort, try network (it may still fail and show placeholder)
        profileImageProvider = NetworkImage(url);
      }
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: const Text(
          "Edit Profile",
          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.orange),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle_outline, color: Colors.orange),
            onPressed: _saveProfile,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Profile Image
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 55,
                            backgroundColor: Colors.orange.withOpacity(0.2),
                            backgroundImage: profileImageProvider,
                            child: profileImageProvider == null
                                ? const Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Colors.orange,
                                  )
                                : null,
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Username Field
                    TextFormField(
                      controller: _usernameController,
                      decoration: _inputDecoration("Username"),
                      validator: (value) => value == null || value.isEmpty
                          ? "Enter a username"
                          : null,
                    ),
                    const SizedBox(height: 20),

                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      decoration: _inputDecoration("Email"),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) => value == null || value.isEmpty
                          ? "Enter an email"
                          : null,
                    ),
                    const SizedBox(height: 20),

                    // Bio Field
                    TextFormField(
                      controller: _bioController,
                      decoration: _inputDecoration("Bio (optional)"),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 40),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                        child: const Text(
                          "Save Changes",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.orange),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.orange),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.orangeAccent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.deepOrange, width: 2),
      ),
    );
  }
}
