import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
  final CloudinaryPublic cloudinary = CloudinaryPublic(
    'dhofbkveg',
    'INGRNTS',
    cache: false,
  );

  Future<String> uploadFile(File file, {String? folder}) async {
    try {
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          resourceType: CloudinaryResourceType.Image,
          folder: folder,
        ),
      );
      return response.secureUrl;
    } catch (e) {
      rethrow;
    }
  }
}
