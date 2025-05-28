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

  /// Convert backend image path to displayable image URL
  static String getImageUrl(String? imageSource) {
    if (imageSource == null || imageSource.isEmpty) {
      print('getImageUrl: Empty or null image source');
      return '';
    }

    print('getImageUrl processing: $imageSource');

    // Handle data URLs (base64)
    if (imageSource.startsWith('data:image/')) {
      print('getImageUrl: Already a base64 data URL, returning as is');
      return imageSource;
    }

    // Handle raw base64 strings (without data:image prefix)
    if (_isBase64(imageSource)) {
      print('getImageUrl: Detected as raw base64, converting to data URL');
      return 'data:image/jpeg;base64,$imageSource';
    }

    // Handle absolute URLs
    if (imageSource.startsWith('http://') || imageSource.startsWith('https://')) {
      print('getImageUrl: Already a full URL, returning as is');
      return imageSource;
    }

    // Handle server paths (relative paths starting with /)
    if (imageSource.startsWith('/')) {
      // For uploads directory
      if (imageSource.contains('/uploads/')) {
        String fullUrl = ApiConstants.baseUrl + imageSource;
        print('getImageUrl: Uploads path converted to: $fullUrl');
        return fullUrl;
      }

      // Other relative paths
      String fullUrl = ApiConstants.baseUrl + imageSource;
      print('getImageUrl: Relative path converted to: $fullUrl');
      return fullUrl;
    }

    // Fallback for any other format
    String fullUrl = ApiConstants.baseUrl + '/' + imageSource;
    print('getImageUrl: Fallback path converted to: $fullUrl');
    return fullUrl;
  }

  /// Display image widget with proper handling of various image formats
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, color: Colors.grey[400]),
          Text('Error loading image', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );

    // Check if imageSource is empty
    if (imageSource.isEmpty) {
      print('Empty image source provided');
      return placeholder ?? defaultPlaceholder;
    }

    // Process URL using getImageUrl
    final processedSource = getImageUrl(imageSource);
    print('Processed to: $processedSource');

    if (processedSource.isEmpty) {
      print('Processing resulted in empty URL');
      return placeholder ?? defaultPlaceholder;
    }

    // For base64 images
    if (processedSource.startsWith('data:image/')) {
      try {
        final parts = processedSource.split(',');
        if (parts.length != 2) {
          print('Invalid data URL format');
          return errorWidget ?? defaultErrorWidget;
        }

        final base64Data = parts[1];
        try {
          final bytes = base64Decode(base64Data);
          print('Base64 image decoded, size: ${bytes.length} bytes');

          return ClipRRect(
            borderRadius: borderRadius ?? BorderRadius.zero,
            child: Image.memory(
              bytes,
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (_, error, stack) {
                print('Error displaying base64 image: $error');
                return errorWidget ?? defaultErrorWidget;
              },
            ),
          );
        } catch (e) {
          print('Error decoding base64: $e');
          return errorWidget ?? defaultErrorWidget;
        }
      } catch (e) {
        print('Error processing base64 image: $e');
        return errorWidget ?? defaultErrorWidget;
      }
    }

    // For network images
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Image.network(
        processedSource,
        width: width,
        height: height,
        fit: fit,
        headers: {
          'Accept': 'image/*',
        },
        loadingBuilder: (_, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Stack(
            alignment: Alignment.center,
            children: [
              placeholder ?? defaultPlaceholder,
              CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ],
          );
        },
        errorBuilder: (context, error, stackTrace) {
          print('Error loading network image: $error');
          print('URL: $processedSource');
          return errorWidget ?? defaultErrorWidget;
        },
      ),
    );
  }

  // Simple check if string is base64 encoded
  static bool _isBase64(String str) {
    // Check if string could potentially be base64
    if (str.length % 4 != 0 ||
        str.contains(RegExp(r'[^A-Za-z0-9+/=]'))) {
      return false;
    }

    try {
      base64Decode(str);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Pick and encode single image
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
        case 'bmp':
          mimeType = 'image/bmp';
          break;
        case 'webp':
          mimeType = 'image/webp';
          break;
        default:
          mimeType = 'image/jpeg';
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

  /// Pick and encode multiple images
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
            mimeType = 'image/jpeg';
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

  /// Compress image bytes
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

  /// Convert XFile to base64
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
        mimeType = 'image/jpeg';
    }

    return 'data:$mimeType;base64,$base64String';
  }

  /// Decode base64 image to bytes
  static Uint8List? decodeBase64Image(String base64String) {
    try {
      // Make sure we only take the base64 data part
      String pureBase64 = base64String;
      if (base64String.contains(';base64,')) {
        pureBase64 = base64String.split(';base64,')[1];
      }

      return base64Decode(pureBase64);
    } catch (e) {
      print('Error decoding base64: $e');
      return null;
    }
  }
}