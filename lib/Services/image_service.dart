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
      return '';
    }

    // Handle data URLs (base64)
    if (imageSource.startsWith('data:image/')) {
      return imageSource;
    }

    // Handle raw base64 strings
    if (_isBase64(imageSource)) {
      return 'data:image/jpeg;base64,$imageSource';
    }

    // Handle absolute URLs
    if (imageSource.startsWith('http://') || imageSource.startsWith('https://')) {
      return imageSource;
    }

    // Handle server paths (relative paths starting with /)
    if (imageSource.startsWith('/')) {
      return ApiConstants.imageBaseUrl + imageSource;
    }

    // Fallback for any other format
    return ApiConstants.imageBaseUrl + '/' + imageSource;
  }

  // Display image widget with proper handling
  static Widget displayImage({
    required String imageSource,
    double width = 100,
    double height = 100,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
    BorderRadius? borderRadius,
  }) {
    final imageUrl = getImageUrl(imageSource);

    if (imageUrl.isEmpty) {
      return errorWidget ?? _defaultErrorWidget(width, height);
    }

    Widget imageWidget;

    if (imageUrl.startsWith('data:image/')) {
      // Handle base64 images
      try {
        final base64String = imageUrl.split(',')[1];
        final bytes = base64Decode(base64String);
        imageWidget = Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            return errorWidget ?? _defaultErrorWidget(width, height);
          },
        );
      } catch (e) {
        return errorWidget ?? _defaultErrorWidget(width, height);
      }
    } else {
      // Handle network images
      imageWidget = Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return placeholder ?? _defaultPlaceholder(width, height);
        },
        errorBuilder: (context, error, stackTrace) {
          return errorWidget ?? _defaultErrorWidget(width, height);
        },
      );
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  // Pick image from gallery or camera
  static Future<XFile?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      return image;
    } catch (e) {
      debugPrint('Pick image error: $e');
      return null;
    }
  }

  // Compress image
  static Future<Uint8List?> compressImage(XFile imageFile, {int quality = 85}) async {
    try {
      final result = await FlutterImageCompress.compressWithFile(
        imageFile.path,
        quality: quality,
        minWidth: 800,
        minHeight: 600,
      );
      return result;
    } catch (e) {
      debugPrint('Compress image error: $e');
      return null;
    }
  }

  // Convert image to base64
  static Future<String?> imageToBase64(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64String = base64Encode(bytes);
      return 'data:image/jpeg;base64,$base64String';
    } catch (e) {
      debugPrint('Image to base64 error: $e');
      return null;
    }
  }

  // Upload image to server
  static Future<String?> uploadImage(XFile imageFile) async {
    try {
      final token = await TokenService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConstants.baseUrl}/upload/image'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(responseBody);
        return jsonData['data']?['imageUrl'];
      } else {
        throw Exception('Failed to upload image');
      }
    } catch (e) {
      debugPrint('Upload image error: $e');
      return null;
    }
  }

  // PRIVATE HELPER METHODS

  static bool _isBase64(String str) {
    try {
      base64Decode(str);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Widget _defaultPlaceholder(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  static Widget _defaultErrorWidget(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: Icon(
        Icons.error,
        color: Colors.grey[600],
        size: width * 0.3,
      ),
    );
  }
}
