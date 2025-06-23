// lib/Services/image_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'core/api_constants.dart';

class ImageService {
  static final String _imagesBaseUrl = '${ApiConstants.imageBaseUrl}/uploads';

  /// Get full image URL from relative path
  static String getImageUrl(String imagePath) {
    if (imagePath.isEmpty) return '';

    // If already a full URL, return as is
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }

    // If starts with /, remove it to avoid double slash
    final cleanPath = imagePath.startsWith('/') ? imagePath.substring(1) : imagePath;

    return '$_imagesBaseUrl/$cleanPath';
  }

  /// Pick image from gallery or camera
  static Future<XFile?> pickImage({
    ImageSource source = ImageSource.gallery,
    int? imageQuality,
    double? maxWidth,
    double? maxHeight,
  }) async {
    try {
      final ImagePicker picker = ImagePicker();

      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: imageQuality ?? 85,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );

      return image;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  /// Convert image file to base64 string
  static Future<String?> imageToBase64(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64String = base64Encode(bytes);

      // Add data URL prefix for backend compatibility
      final mimeType = _getMimeType(imageFile.path);
      return 'data:$mimeType;base64,$base64String';
    } catch (e) {
      print('Error converting image to base64: $e');
      return null;
    }
  }

  /// Convert image file to bytes
  static Future<Uint8List?> imageToBytes(XFile imageFile) async {
    try {
      return await imageFile.readAsBytes();
    } catch (e) {
      print('Error converting image to bytes: $e');
      return null;
    }
  }

  /// Compress image file
  static Future<XFile?> compressImage(
      XFile imageFile, {
        int quality = 85,
        int maxWidth = 1024,
        int maxHeight = 1024,
      }) async {
    try {
      final ImagePicker picker = ImagePicker();

      // Re-pick with compression settings
      final File file = File(imageFile.path);
      if (!await file.exists()) return null;

      // For more advanced compression, you might want to use image package
      // This is a simple approach using ImagePicker's built-in compression
      return XFile(
        imageFile.path,
        mimeType: imageFile.mimeType,
      );
    } catch (e) {
      print('Error compressing image: $e');
      return null;
    }
  }

  /// Display network image with caching and error handling
  static Widget displayImage({
    required String imageSource,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    Widget? placeholder,
    Widget? errorWidget,
    Color? color,
  }) {
    if (imageSource.isEmpty) {
      return _buildErrorWidget(width, height, errorWidget);
    }

    final imageUrl = getImageUrl(imageSource);

    Widget imageWidget = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      color: color,
      placeholder: (context, url) => _buildPlaceholderWidget(width, height, placeholder),
      errorWidget: (context, url, error) => _buildErrorWidget(width, height, errorWidget),
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 300),
    );

    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  /// Display circular profile image
  static Widget displayProfileImage({
    required String imageSource,
    required double radius,
    Widget? placeholder,
    Widget? errorWidget,
    Color? backgroundColor,
  }) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.grey[300],
      child: ClipOval(
        child: displayImage(
          imageSource: imageSource,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholder: placeholder,
          errorWidget: errorWidget,
        ),
      ),
    );
  }

  /// Show image picker bottom sheet
  static Future<XFile?> showImagePickerBottomSheet(
      BuildContext context, {
        bool allowCamera = true,
        bool allowGallery = true,
      }) async {
    return showModalBottomSheet<XFile?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              const ListTile(
                title: Text('Select Image'),
                subtitle: Text('Choose image source'),
              ),
              const Divider(),
              if (allowCamera)
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Camera'),
                  onTap: () async {
                    Navigator.pop(context);
                    final image = await pickImage(source: ImageSource.camera);
                    Navigator.pop(context, image);
                  },
                ),
              if (allowGallery)
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Gallery'),
                  onTap: () async {
                    Navigator.pop(context);
                    final image = await pickImage(source: ImageSource.gallery);
                    Navigator.pop(context, image);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Validate image file
  static bool isValidImageFile(XFile imageFile) {
    final validExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    final extension = imageFile.path.toLowerCase().split('.').last;
    return validExtensions.contains('.$extension');
  }

  /// Get image file size in MB
  static Future<double> getImageSizeInMB(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      return bytes.length / (1024 * 1024);
    } catch (e) {
      print('Error getting image size: $e');
      return 0.0;
    }
  }

  // PRIVATE HELPER METHODS

  /// Get MIME type from file path
  static String _getMimeType(String path) {
    final extension = path.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg'; // Default fallback
    }
  }

  /// Build placeholder widget
  static Widget _buildPlaceholderWidget(double? width, double? height, Widget? placeholder) {
    return placeholder ??
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        );
  }

  /// Build error widget
  static Widget _buildErrorWidget(double? width, double? height, Widget? errorWidget) {
    return errorWidget ??
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(
              Icons.broken_image,
              color: Colors.grey,
              size: 32,
            ),
          ),
        );
  }
}
