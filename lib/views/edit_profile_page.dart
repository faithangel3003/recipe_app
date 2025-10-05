import 'dart:io';
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
    // If you add bio in AppUser later, you can also init it here
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
      setState(() {
        _imageFile = File(pickedFile.path);
      });
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
        // proceed without failing the whole save
      }
    }

    // Construct updated user
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
      // Save to Firestore
      await FirebaseFirestore.instance
          .collection("users")
          .doc(widget.user.uid)
          .set(updatedUser.toJson());

      // Update Firebase Auth profile (displayName / photoURL) if available.
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser != null) {
        // Note: changing email may require re-authentication depending on
        // the Firebase Auth version and security rules. To avoid calling an
        // unsupported API in this environment, we only update displayName
        // and photoURL here and surface a message if the email changed.
        if (_emailController.text.trim().isNotEmpty &&
            _emailController.text.trim() != authUser.email) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Email change detected. You may need to re-authenticate to update your email.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }

        try {
          await authUser.updateDisplayName(updatedUser.username);
          if (imageUrl.isNotEmpty && imageUrl != authUser.photoURL) {
            await authUser.updatePhotoURL(imageUrl);
          }
        } catch (e) {
          debugPrint('Auth profile update failed: $e');
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _saveProfile),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 50,
                          backgroundImage: _imageFile != null
                              ? FileImage(_imageFile!)
                              : (widget.user.profileImageUrl.isNotEmpty
                                        ? NetworkImage(
                                            widget.user.profileImageUrl,
                                          )
                                        : null)
                                    as ImageProvider<Object>?,
                          child:
                              (_imageFile == null &&
                                  widget.user.profileImageUrl.isEmpty)
                              ? const Icon(Icons.camera_alt, size: 40)
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: "Username",
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? "Enter a username"
                          : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: "Email",
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) => value == null || value.isEmpty
                          ? "Enter an email"
                          : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _bioController,
                      decoration: const InputDecoration(
                        labelText: "Bio (optional)",
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
