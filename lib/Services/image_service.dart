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
  // Use consistent base URL
  static final String baseUrl = ApiConstants.baseUrl;
  static final String imageBaseUrl = ApiConstants.prodBaseUrl;

  // Convert backend image path to displayable image URL
  //region GetImage v1
  static String getImageUrlV1(String? imageSource) {
    if (imageSource == null || imageSource.isEmpty) {
      print('getImageUrl: Empty or null image source');
      return ''; // Return empty string for null/empty images
    }

    print('getImageUrl processing: $imageSource');

    // If it's already a full URL including your domain
    if (imageSource.startsWith('https://delpick.horas-code.my.id/api/v1')) {
      // Try adding /api/v1 if it's an uploads path
      if (imageSource.contains('/uploads/')) {
        // Check if /api/v1 is already in the path
        // if (!imageSource.contains('/api/v1/')) {
        //   // Insert /api/v1 before /uploads
        //   final correctedUrl = imageSource.replaceFirst('/uploads/', '/api/v1/uploads/');
        //   print('Corrected URL: $correctedUrl');
        //   return correctedUrl;
        // }
        // final correctedUrl = imageSource.replaceFirst('/uploads/', '/api/v1/uploads/');
        final correctedUrl = imageSource;
        print('Corrected URL: $correctedUrl');
        return correctedUrl;
      }
      return imageSource;
    }

    // Handle data URLs (base64)
    if (imageSource.startsWith('data:image/')) {
      print('getImageUrl: Already a full URL, returning as is');
      return imageSource;
    }

    // Handle raw base64 strings (without data:image prefix)
    if (_isBase64(imageSource)) {
      print('getImageUrl: Detected as raw base64, converting to data URL');
      return 'data:image/jpeg;base64,$imageSource'; // Assume JPEG if not specified
    }


    // Handle server paths
    // if (imageSource.startsWith('/')) {
    //   final result = 'https://delpick.horas-code.my.id/api/v1/$imageSource';
    //   print('getImageUrl: Server path converted to: $result');
    //   return result;
    // }
    // Jika path relatif (dimulai dengan /)
    if (imageSource.startsWith('/')) {
      String fullUrl = ApiConstants.productionApiUrl+ imageSource;
      print('Converted relative path to full URL: $fullUrl');
      return fullUrl;
    }

    // In your getImageUrl method
    if (imageSource.startsWith('/uploads/')) {
      String fullUrl = 'https://delpick.horas-code.my.id/api/v1' + imageSource;
      print('getImageUrl: Detected /uploads/ path, converted to: $fullUrl');
      return fullUrl;
    }

    // Handle full URLs
    // Jika sudah berupa URL lengkap (http/https)
    if (imageSource.startsWith('http://') || imageSource.startsWith('https://')) {
      print('Image is already a full URL, returning as is');
      return imageSource;
    }

    /// Fallback: assume it's a relative path
    // final result = '$baseUrl/$imageSource';
    final result = '$baseUrl/$imageSource';
    print('getImageUrl: Relative path converted to: $result');
    return result;
  }
  //endregion

  //region GetImage V2
  static String getImageUrl2(String? imageSource) {
    if (imageSource == null || imageSource.isEmpty) {
      print('getImageUrl: Empty or null image source');
      return ''; // Return empty string for null/empty images
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
      return 'data:image/jpeg;base64,$imageSource'; // Assume JPEG if not specified
    }

    // Handle absolute URLs
    if (imageSource.startsWith('http://') || imageSource.startsWith('https://')) {
      print('getImageUrl: Already a full URL, returning as is');
      return imageSource;
    }

    // Handle server paths (relative paths starting with /)
    if (imageSource.startsWith('/')) {
      // Jika path mengandung /uploads/
      if (imageSource.contains('/uploads/')) {
        String fullUrl = ApiConstants.imageBaseUrl + imageSource;
        print('getImageUrl: Uploads path converted to: $fullUrl');
        return fullUrl;
      }

      // Path relatif lainnya
      String fullUrl = ApiConstants.imageBaseUrl + imageSource;
      print('getImageUrl: Relative path converted to: $fullUrl');
      return fullUrl;
    }

    // Fallback for any other format
    String fullUrl = ApiConstants.imageBaseUrl + '/' + imageSource;
    print('getImageUrl: Fallback path converted to: $fullUrl');
    return fullUrl;
  }
  //endregion

  // Perbaikan fungsi getImageUrl
  static String getImageUrl(String? imageSource) {
    if (imageSource == null || imageSource.isEmpty) {
      print('getImageUrl: Empty or null image source');
      return '';
    }

    print('getImageUrl processing: $imageSource');

    // Jika sudah berupa data URL (base64)
    if (imageSource.startsWith('data:image/')) {
      print('getImageUrl: Already a base64 data URL, returning as is');
      return imageSource;
    }

    // Jika sudah berupa base64 tanpa prefix
    if (_isBase64(imageSource)) {
      print('getImageUrl: Detected as raw base64, converting to data URL');
      return 'data:image/jpeg;base64,$imageSource';
    }

    // Jika sudah URL lengkap dengan domain
    if (imageSource.startsWith('http://') || imageSource.startsWith('https://')) {
      print('getImageUrl: Already a full URL, returning as is');
      return imageSource;
    }

    // Jika dimulai dengan "/uploads/"
    if (imageSource.startsWith('/uploads/')) {
      String fullUrl = 'https://delpick.horas-code.my.id' + imageSource;
      print('getImageUrl: Detected /uploads/ path, converted to: $fullUrl');
      return fullUrl;
    }

    // Jika path relatif lainnya yang dimulai dengan "/"
    if (imageSource.startsWith('/')) {
      String fullUrl = 'https://delpick.horas-code.my.id' + imageSource;
      print('getImageUrl: Relative path converted to: $fullUrl');
      return fullUrl;
    }

    // Jika berisi "uploads/" tanpa slash di awal
    if (imageSource.contains('uploads/')) {
      String fullUrl = 'https://delpick.horas-code.my.id/' + imageSource;
      print('getImageUrl: Partial uploads path converted to: $fullUrl');
      return fullUrl;
    }

    // Fallback untuk format lainnya
    String fullUrl = 'https://delpick.horas-code.my.id/' + imageSource;
    print('getImageUrl: Fallback path converted to: $fullUrl');
    return fullUrl;
  }

// Perbaikan fungsi displayImage
  static Widget displayImage({
    required String imageSource,
    double width = 100,
    double height = 100,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
    BorderRadius? borderRadius,
  }) {
    // Default placeholder dan error widgets
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
          // Untuk debug
          Text(imageSource,
              style: TextStyle(fontSize: 8, color: Colors.grey[500]),
              overflow: TextOverflow.ellipsis,
              maxLines: 2),
        ],
      ),
    );

    // Cek jika imageSource kosong
    if (imageSource.isEmpty) {
      print('Empty image source provided');
      return placeholder ?? defaultPlaceholder;
    }

    print('displayImage processing: $imageSource');

    // Proses URL menggunakan getImageUrl
    final processedSource = getImageUrl(imageSource);
    print('Processed to: $processedSource');

    if (processedSource.isEmpty) {
      print('Processing resulted in empty URL');
      return placeholder ?? defaultPlaceholder;
    }

    // Untuk gambar base64
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

    // Untuk gambar URL
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Image.network(
        processedSource,
        width: width,
        height: height,
        fit: fit,
        headers: {
          'Accept': 'image/*',
          // Tambahkan header lain jika diperlukan
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
          // Coba alternatif URL jika gagal
          if (processedSource.contains('/api/v1/uploads/')) {
            // Coba versi URL tanpa /api/v1/
            final alternativeUrl = processedSource.replaceFirst('/api/v1/uploads/', '/uploads/');
            print('Trying alternative URL: $alternativeUrl');

            // Jika kita gagal memuat URL dengan /api/v1/, coba tanpa itu
            return Image.network(
              alternativeUrl,
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (_, __, ___) => errorWidget ?? defaultErrorWidget,
            );
          }
          return errorWidget ?? defaultErrorWidget;
        },
      ),
    );
  }

  // Simple check if string is base64 encoded
  // Improved base64 detection
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
        case 'bmp':
          mimeType = 'image/bmp';
          break;
        case 'webp':
          mimeType = 'image/webp';
          break;
        default:
          mimeType = 'image/jpeg'; // Default ke JPEG
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


  //region Display Image versi 2
  //
  // static Widget displayImage({
  //   required String imageSource,
  //   double width = 100,
  //   double height = 100,
  //   BoxFit fit = BoxFit.cover,
  //   Widget? placeholder,
  //   Widget? errorWidget,
  //   BorderRadius? borderRadius,
  // })
  // {
  //   // Default placeholder and error widgets
  //   final defaultPlaceholder = Container(
  //     width: width,
  //     height: height,
  //     color: Colors.grey[300],
  //     child: Icon(Icons.image, color: Colors.grey[600]),
  //   );
  //
  //   final defaultErrorWidget = Container(
  //     width: width,
  //     height: height,
  //     color: Colors.grey[200],
  //     child: Column(
  //       mainAxisAlignment: MainAxisAlignment.center,
  //       children: [
  //         Icon(Icons.broken_image, color: Colors.grey[400]),
  //         Text('Error loading image', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
  //         // Add this to debug
  //         Text(imageSource, style: TextStyle(fontSize: 8, color: Colors.grey[500]), overflow: TextOverflow.ellipsis),
  //       ],
  //     ),
  //   );
  //
  //   // Check if imageSource is empty
  //   if (imageSource.isEmpty) {
  //     print('Empty image source provided to displayImage');
  //     return placeholder ?? defaultPlaceholder;
  //   }
  //
  //   print('displayImage processing: $imageSource');
  //
  //   // Process the URL - important for non-base64 images too!
  //   final processedSource = getImageUrl(imageSource);
  //   print('Processed to: $processedSource');
  //
  //   if (processedSource.isEmpty) {
  //     print('Processing resulted in empty URL');
  //     return placeholder ?? defaultPlaceholder;
  //   }
  //
  //   // For base64 images
  //   if (processedSource.startsWith('data:image/')) {
  //     try {
  //       final base64Data = processedSource.split(',')[1];
  //       final bytes = base64Decode(base64Data);
  //       print('Base64 image decoded, size: ${bytes.length} bytes');
  //
  //       return ClipRRect(
  //         borderRadius: borderRadius ?? BorderRadius.zero,
  //         child: Image.memory(
  //           bytes,
  //           width: width,
  //           height: height,
  //           fit: fit,
  //           errorBuilder: (_, error, stack) {
  //             print('Error loading base64 image: $error');
  //             return errorWidget ?? defaultErrorWidget;
  //           },
  //         ),
  //       );
  //     } catch (e) {
  //       print('Error decoding base64: $e');
  //       return errorWidget ?? defaultErrorWidget;
  //     }
  //   }
  //
  //   // For network images
  //   print('Loading network image: $processedSource');
  //   return ClipRRect(
  //     borderRadius: borderRadius ?? BorderRadius.zero,
  //     child: Image.network(
  //       processedSource,
  //       width: width,
  //       height: height,
  //       fit: fit,
  //       // Add HTTP headers if needed for authentication
  //       headers: {
  //         'Accept': 'image/*',
  //         // Add any other headers your server might require
  //       },
  //       loadingBuilder: (_, child, loadingProgress) {
  //         if (loadingProgress == null) return child;
  //         print('Loading progress: ${loadingProgress.cumulativeBytesLoaded}/${loadingProgress.expectedTotalBytes}');
  //         return placeholder ?? defaultPlaceholder;
  //       },
  //       errorBuilder: (_, error, stack) {
  //         print('Error loading network image: $error');
  //         return errorWidget ?? defaultErrorWidget;
  //       },
  //     ),
  //   );
  // }
  // static Widget displayImage({
  //   required String imageSource,
  //   double width = 100,
  //   double height = 100,
  //   BoxFit fit = BoxFit.cover,
  //   Widget? placeholder,
  //   Widget? errorWidget,
  //   BorderRadius? borderRadius,
  // }) {
  //   // Default placeholder and error widgets
  //   final defaultPlaceholder = Container(
  //     width: width,
  //     height: height,
  //     color: Colors.grey[300],
  //     child: Icon(Icons.image, color: Colors.grey[600]),
  //   );
  //
  //   final defaultErrorWidget = Container(
  //     width: width,
  //     height: height,
  //     color: Colors.grey[200],
  //     child: Icon(Icons.broken_image, color: Colors.grey[400]),
  //   );
  //
  //   // Check if imageSource is empty
  //   if (imageSource.isEmpty) {
  //     return placeholder ?? defaultPlaceholder;
  //   }
  //
  //   // Process the URL using getImageUrl
  //   final processedSource = getImageUrl(imageSource);
  //   if (processedSource.isEmpty) {
  //     return placeholder ?? defaultPlaceholder;
  //   }
  //
  //   Widget imageWidget;
  //
  //   try {
  //     if (processedSource.startsWith('data:image/')) {
  //       // Handle base64 images
  //       try {
  //         // Extract base64 data (remove data URL prefix)
  //         final base64Data = processedSource.split(',')[1];
  //         // Decode the base64 string into bytes
  //         final bytes = base64Decode(base64Data);
  //
  //         imageWidget = Image.memory(
  //           bytes,
  //           width: width,
  //           height: height,
  //           fit: fit,
  //           errorBuilder: (_, __, ___) => errorWidget ?? defaultErrorWidget,
  //         );
  //       } catch (e) {
  //         print('Error decoding base64 image: $e');
  //         return errorWidget ?? defaultErrorWidget;
  //       }
  //     } else {
  //       // Handle network or asset images
  //       imageWidget = Image.network(
  //         processedSource,
  //         width: width,
  //         height: height,
  //         fit: fit,
  //         loadingBuilder: (_, child, loadingProgress) {
  //           if (loadingProgress == null) return child;
  //           return placeholder ?? defaultPlaceholder;
  //         },
  //         errorBuilder: (_, __, ___) => errorWidget ?? defaultErrorWidget,
  //       );
  //     }
  //   } catch (e) {
  //     print('Error creating image widget: $e');
  //     return errorWidget ?? defaultErrorWidget;
  //   }
  //
  //   // Apply border radius if provided
  //   if (borderRadius != null) {
  //     return ClipRRect(
  //       borderRadius: borderRadius,
  //       child: imageWidget,
  //     );
  //   }
  //
  //   return imageWidget;
  // }
  //endregion

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

  // Helper method untuk decode string base64 ke bytes
  static Uint8List? decodeBase64Image(String base64String) {
    try {
      // Pastikan kita hanya mengambil data base64-nya saja
      String pureBase64 = base64String;
      if (base64String.contains(';base64,')) {
        pureBase64 = base64String.split(';base64,')[1];
      }

      // Decode base64 ke bytes
      return base64Decode(pureBase64);
    } catch (e) {
      print('Error decoding base64: $e');
      return null;
    }
  }
}