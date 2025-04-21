// lib/services/image_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'core/api_constants.dart';
import 'core/token_service.dart';

class ImageService {
  static final ImagePicker _picker = ImagePicker();

  // Convert backend image path to displayable image URL
  static String getImageUrl(String? imageSource) {
    if (imageSource == null || imageSource.isEmpty) {
      return ''; // Return empty string for null/empty images
    }

    // Handle data URLs (base64)
    if (imageSource.startsWith('data:image/')) {
      return imageSource;
    }

    // Handle raw base64 strings (without data:image prefix)
    if (_isBase64(imageSource)) {
      return 'data:image/jpeg;base64,$imageSource'; // Assume JPEG if not specified
    }

    // Handle server paths
    if (imageSource.startsWith('/')) {
      return '${ApiConstants.baseUrl}$imageSource';
    }

    // Handle full URLs
    if (imageSource.startsWith('http')) {
      return imageSource;
    }

    // Fallback: assume it's a relative path
    return '${ApiConstants.baseUrl}/$imageSource';
  }

  // Simple check if string is base64 encoded
  static bool _isBase64(String str) {
    try {
      base64Decode(str);
      return true;
    } catch (_) {
      return false;
    }
  }

  // Pick and encode single image
  static Future<Map<String, dynamic>?> pickAndEncodeImage({
    ImageSource source = ImageSource.gallery,
  }) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (pickedFile == null) {
        return null;
      }

      // Get file info
      File imageFile = File(pickedFile.path);
      String extension = pickedFile.path.split('.').last.toLowerCase();
      Uint8List imageBytes = await imageFile.readAsBytes();

      // Compress if too large (over 1MB)
      if (imageBytes.length > 1 * 1024 * 1024) {
        imageBytes = await compressImage(imageBytes);
      }

      // Determine MIME type from extension
      String mimeType;
      switch (extension) {
        case 'jpg':
        case 'jpeg':
          mimeType = 'image/jpeg';
          break;
        case 'png':
          mimeType = 'image/png';
          break;
        case 'gif':
          mimeType = 'image/gif';
          break;
        default:
          mimeType = 'image/jpeg'; // Default to JPEG
      }

      // Encode to base64
      String base64String = base64Encode(imageBytes);
      String dataUrl = 'data:$mimeType;base64,$base64String';

      return {
        'bytes': imageBytes,
        'base64': dataUrl,
        'mimeType': mimeType,
        'fileName': pickedFile.path.split('/').last,
        'fileSize': imageBytes.length,
      };
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  // Pick and encode multiple images
  static Future<List<Map<String, dynamic>>> pickAndEncodeMultipleImages() async {
    try {
      final List<XFile> pickedFiles = await _picker.pickMultiImage(
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (pickedFiles.isEmpty) {
        return [];
      }

      List<Map<String, dynamic>> results = [];

      for (XFile file in pickedFiles) {
        File imageFile = File(file.path);
        String extension = file.path.split('.').last.toLowerCase();
        Uint8List imageBytes = await imageFile.readAsBytes();

        // Compress if too large
        if (imageBytes.length > 1 * 1024 * 1024) {
          imageBytes = await compressImage(imageBytes);
        }

        // Determine MIME type from extension
        String mimeType;
        switch (extension) {
          case 'jpg':
          case 'jpeg':
            mimeType = 'image/jpeg';
            break;
          case 'png':
            mimeType = 'image/png';
            break;
          case 'gif':
            mimeType = 'image/gif';
            break;
          default:
            mimeType = 'image/jpeg'; // Default to JPEG
        }

        // Encode to base64
        String base64String = base64Encode(imageBytes);
        String dataUrl = 'data:$mimeType;base64,$base64String';

        results.add({
          'bytes': imageBytes,
          'base64': dataUrl,
          'mimeType': mimeType,
          'fileName': file.path.split('/').last,
          'fileSize': imageBytes.length,
        });
      }

      return results;
    } catch (e) {
      print('Error picking multiple images: $e');
      return [];
    }
  }

  // Compress image bytes
  static Future<Uint8List> compressImage(Uint8List bytes) async {
    try {
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        minHeight: 600,
        minWidth: 600,
        quality: 70,
        format: CompressFormat.jpeg,
      );

      print('Image compressed: ${bytes.length} bytes -> ${result.length} bytes');
      return result;
    } catch (e) {
      print('Error compressing image: $e');
      // Return original if compression fails
      return bytes;
    }
  }

  // Upload user profile image
  static Future<bool> uploadUserProfileImage(String userId, String base64Image) async {
    try {
      // Ensure base64Image has proper format
      String formattedBase64 = base64Image;
      if (!base64Image.startsWith('data:image/')) {
        formattedBase64 = 'data:image/jpeg;base64,$base64Image';
      }

      final String? token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/users/$userId/image'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'image': formattedBase64,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error uploading profile image: $e');
      return false;
    }
  }

  // Upload store image
  static Future<bool> uploadStoreImage(int storeId, String base64Image) async {
    try {
      // Ensure base64Image has proper format
      String formattedBase64 = base64Image;
      if (!base64Image.startsWith('data:image/')) {
        formattedBase64 = 'data:image/jpeg;base64,$base64Image';
      }

      final String? token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/stores/$storeId/image'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'image': formattedBase64,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error uploading store image: $e');
      return false;
    }
  }

  // Upload menu item image
  static Future<bool> uploadMenuItemImage(int itemId, String base64Image) async {
    try {
      // Ensure base64Image has proper format
      String formattedBase64 = base64Image;
      if (!base64Image.startsWith('data:image/')) {
        formattedBase64 = 'data:image/jpeg;base64,$base64Image';
      }

      final String? token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/menu-items/$itemId/image'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'image': formattedBase64,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error uploading menu item image: $e');
      return false;
    }
  }

  // Display image widget with proper handling for different formats
  static Widget displayImage({
    required String imageSource,
    double width = 100,
    double height = 100,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
    BorderRadius? borderRadius,
  }) {
    // Default placeholder and error widgets
    final defaultPlaceholder = Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: Icon(Icons.image, color: Colors.grey[600]),
    );

    final defaultErrorWidget = Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Icon(Icons.broken_image, color: Colors.grey[400]),
    );

    // Process the image source
    String processedSource = getImageUrl(imageSource);
    if (processedSource.isEmpty) {
      return placeholder ?? defaultPlaceholder;
    }

    // Create appropriate image widget based on source type
    Widget imageWidget;

    try {
      if (processedSource.startsWith('data:image/')) {
        // Handle base64 images
        String base64Data = processedSource.split(',')[1];
        imageWidget = Image.memory(
          base64Decode(base64Data),
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => errorWidget ?? defaultErrorWidget,
        );
      } else {
        // Handle network/asset images
        imageWidget = Image.network(
          processedSource,
          width: width,
          height: height,
          fit: fit,
          loadingBuilder: (_, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return placeholder ?? defaultPlaceholder;
          },
          errorBuilder: (_, __, ___) => errorWidget ?? defaultErrorWidget,
        );
      }
    } catch (e) {
      print('Error creating image widget: $e');
      return errorWidget ?? defaultErrorWidget;
    }

    // Apply border radius if provided
    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  // Utility method to convert XFile to base64
  static Future<String> xFileToBase64(XFile file) async {
    final bytes = await file.readAsBytes();
    final String extension = file.path.split('.').last.toLowerCase();
    final String base64String = base64Encode(bytes);

    // Determine MIME type from extension
    String mimeType;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        mimeType = 'image/jpeg';
        break;
      case 'png':
        mimeType = 'image/png';
        break;
      default:
        mimeType = 'image/jpeg'; // Default
    }

    return 'data:$mimeType;base64,$base64String';
  }
}