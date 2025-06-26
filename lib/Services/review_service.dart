// lib/Services/review_service.dart
import 'core/base_service.dart';
import 'image_service.dart';
import 'auth_service.dart';

class ReviewService {
  static const String _baseEndpoint = '/reviews';

  /// Create combined review for order (order + driver review)
  static Future<Map<String, dynamic>> createOrderReview({
    required String orderId,
    required int orderRating,
    required int driverRating,
    String? orderComment,
    String? driverComment,
  }) async {
    try {
      print('⭐ ReviewService: Creating order review for order: $orderId');

      // Validate customer access
      final hasAccess = await AuthService.validateCustomerAccess();
      if (!hasAccess) {
        throw Exception('Access denied: Customer authentication required');
      }

      if (orderRating < 1 || orderRating > 5) {
        throw Exception('Order rating must be between 1 and 5');
      }

      if (driverRating < 1 || driverRating > 5) {
        throw Exception('Driver rating must be between 1 and 5');
      }

      final body = {
        'order_review': {
          'rating': orderRating,
          if (orderComment != null && orderComment.isNotEmpty) 'comment': orderComment,
        },
        'driver_review': {
          'rating': driverRating,
          if (driverComment != null && driverComment.isNotEmpty) 'comment': driverComment,
        },
      };

      final response = await BaseService.apiCall(
        method: 'POST',
        endpoint: '/orders/$orderId/review',
        body: body,
        requiresAuth: true,
      );

      print('✅ ReviewService: Order review created successfully');
      return response['data'] ?? {};
    } catch (e) {
      print('❌ ReviewService: Create order review error: $e');
      throw Exception('Failed to create order review: $e');
    }
  }

  /// Create service order review
  static Future<Map<String, dynamic>> createServiceOrderReview({
    required String serviceOrderId,
    required int rating,
    String? comment,
    int? serviceQuality,
    int? punctuality,
    int? communication,
  }) async {
    try {
      print('⭐ ReviewService: Creating service order review for: $serviceOrderId');

      // Validate customer access
      final hasAccess = await AuthService.validateCustomerAccess();
      if (!hasAccess) {
        throw Exception('Access denied: Customer authentication required');
      }

      if (rating < 1 || rating > 5) {
        throw Exception('Rating must be between 1 and 5');
      }

      final body = {
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
        if (serviceQuality != null) 'service_quality': serviceQuality,
        if (punctuality != null) 'punctuality': punctuality,
        if (communication != null) 'communication': communication,
      };

      final response = await BaseService.apiCall(
        method: 'POST',
        endpoint: '/service-orders/$serviceOrderId/review',
        body: body,
        requiresAuth: true,
      );

      print('✅ ReviewService: Service order review created successfully');
      return response['data'] ?? {};
    } catch (e) {
      print('❌ ReviewService: Create service order review error: $e');
      throw Exception('Failed to create service order review: $e');
    }
  }

  /// Get reviews for a store
  static Future<Map<String, dynamic>> getStoreReviews({
    required String storeId,
    int page = 1,
    int limit = 10,
    String? sortBy = 'created_at',
    String? sortOrder = 'DESC',
  }) async {
    try {
      print('🏪 ReviewService: Getting store reviews for: $storeId');

      final isAuth = await AuthService.isAuthenticated();
      if (!isAuth) {
        throw Exception('Authentication required');
      }

      // Create queryParams with non-nullable values only
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      // Add optional parameters only if they're not null
      if (sortBy != null) {
        queryParams['sortBy'] = sortBy;
      }
      if (sortOrder != null) {
        queryParams['sortOrder'] = sortOrder;
      }

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '/stores/$storeId/reviews',
        queryParams: queryParams,
        requiresAuth: true,
      );

      if (response['data'] != null && response['data']['reviews'] != null) {
        final reviews = response['data']['reviews'] as List;
        for (var review in reviews) {
          _processReviewImages(review);
        }
        print('✅ ReviewService: Retrieved ${reviews.length} store reviews');
      }

      return response['data'] ?? {
        'reviews': [],
        'totalItems': 0,
        'totalPages': 0,
        'currentPage': 1,
        'averageRating': 0.0,
        'ratingDistribution': {
          '5': 0, '4': 0, '3': 0, '2': 0, '1': 0,
        },
      };
    } catch (e) {
      print('❌ ReviewService: Get store reviews error: $e');
      return {
        'reviews': [],
        'totalItems': 0,
        'totalPages': 0,
        'currentPage': 1,
        'averageRating': 0.0,
        'ratingDistribution': {
          '5': 0, '4': 0, '3': 0, '2': 0, '1': 0,
        },
      };
    }
  }

  /// Get reviews for a driver
  static Future<Map<String, dynamic>> getDriverReviews({
    required String driverId,
    int page = 1,
    int limit = 10,
    String? sortBy = 'created_at',
    String? sortOrder = 'DESC',
  }) async {
    try {
      print('🚗 ReviewService: Getting driver reviews for: $driverId');

      final isAuth = await AuthService.isAuthenticated();
      if (!isAuth) {
        throw Exception('Authentication required');
      }

      // Create queryParams with non-nullable values only
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      // Add optional parameters only if they're not null
      if (sortBy != null) {
        queryParams['sortBy'] = sortBy;
      }
      if (sortOrder != null) {
        queryParams['sortOrder'] = sortOrder;
      }

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '/drivers/$driverId/reviews',
        queryParams: queryParams,
        requiresAuth: true,
      );

      if (response['data'] != null && response['data']['reviews'] != null) {
        final reviews = response['data']['reviews'] as List;
        for (var review in reviews) {
          _processReviewImages(review);
        }
        print('✅ ReviewService: Retrieved ${reviews.length} driver reviews');
      }

      return response['data'] ?? {
        'reviews': [],
        'totalItems': 0,
        'totalPages': 0,
        'currentPage': 1,
        'averageRating': 0.0,
        'ratingDistribution': {
          '5': 0, '4': 0, '3': 0, '2': 0, '1': 0,
        },
      };
    } catch (e) {
      print('❌ ReviewService: Get driver reviews error: $e');
      return {
        'reviews': [],
        'totalItems': 0,
        'totalPages': 0,
        'currentPage': 1,
        'averageRating': 0.0,
        'ratingDistribution': {
          '5': 0, '4': 0, '3': 0, '2': 0, '1': 0,
        },
      };
    }
  }

  /// Get customer's reviews (reviews given by customer)
  static Future<Map<String, dynamic>> getCustomerReviews({
    int page = 1,
    int limit = 10,
    String? type, // 'order', 'driver', 'service_order'
  }) async {
    try {
      print('👤 ReviewService: Getting customer reviews...');

      final hasAccess = await AuthService.validateCustomerAccess();
      if (!hasAccess) {
        throw Exception('Access denied: Customer authentication required');
      }

      // Create queryParams with non-nullable values only
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      // Add optional parameters only if they're not null
      if (type != null) {
        queryParams['type'] = type;
      }

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/customer',
        queryParams: queryParams,
        requiresAuth: true,
      );

      if (response['data'] != null && response['data']['reviews'] != null) {
        final reviews = response['data']['reviews'] as List;
        for (var review in reviews) {
          _processReviewImages(review);
        }
        print('✅ ReviewService: Retrieved ${reviews.length} customer reviews');
      }

      return response['data'] ?? {
        'reviews': [],
        'totalItems': 0,
        'totalPages': 0,
        'currentPage': 1,
      };
    } catch (e) {
      print('❌ ReviewService: Get customer reviews error: $e');
      return {
        'reviews': [],
        'totalItems': 0,
        'totalPages': 0,
        'currentPage': 1,
      };
    }
  }

  /// Update existing review
  static Future<Map<String, dynamic>> updateReview({
    required String reviewId,
    required String reviewType, // 'order', 'driver', 'service_order'
    int? rating,
    String? comment,
  }) async {
    try {
      print('📝 ReviewService: Updating review: $reviewId');

      final hasAccess = await AuthService.validateCustomerAccess();
      if (!hasAccess) {
        throw Exception('Access denied: Customer authentication required');
      }

      if (rating != null && (rating < 1 || rating > 5)) {
        throw Exception('Rating must be between 1 and 5');
      }

      final body = <String, dynamic>{};
      if (rating != null) body['rating'] = rating;
      if (comment != null) body['comment'] = comment;

      if (body.isEmpty) {
        throw Exception('No update data provided');
      }

      final response = await BaseService.apiCall(
        method: 'PUT',
        endpoint: '$_baseEndpoint/$reviewType/$reviewId',
        body: body,
        requiresAuth: true,
      );

      print('✅ ReviewService: Review updated successfully');
      return response['data'] ?? {};
    } catch (e) {
      print('❌ ReviewService: Update review error: $e');
      throw Exception('Failed to update review: $e');
    }
  }

  /// Delete review
  static Future<bool> deleteReview({
    required String reviewId,
    required String reviewType, // 'order', 'driver', 'service_order'
  }) async {
    try {
      print('🗑️ ReviewService: Deleting review: $reviewId');

      final hasAccess = await AuthService.validateCustomerAccess();
      if (!hasAccess) {
        throw Exception('Access denied: Customer authentication required');
      }

      await BaseService.apiCall(
        method: 'DELETE',
        endpoint: '$_baseEndpoint/$reviewType/$reviewId',
        requiresAuth: true,
      );

      print('✅ ReviewService: Review deleted successfully');
      return true;
    } catch (e) {
      print('❌ ReviewService: Delete review error: $e');
      return false;
    }
  }

  /// Get review statistics for store/driver
  static Future<Map<String, dynamic>> getReviewStatistics({
    required String entityId,
    required String entityType, // 'store', 'driver'
  }) async {
    try {
      print('📊 ReviewService: Getting review statistics for $entityType: $entityId');

      final isAuth = await AuthService.isAuthenticated();
      if (!isAuth) {
        throw Exception('Authentication required');
      }

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/statistics/$entityType/$entityId',
        requiresAuth: true,
      );

      return response['data'] ?? {
        'averageRating': 0.0,
        'totalReviews': 0,
        'ratingDistribution': {
          '5': 0, '4': 0, '3': 0, '2': 0, '1': 0,
        },
        'recentReviews': [],
      };
    } catch (e) {
      print('❌ ReviewService: Get review statistics error: $e');
      return {
        'averageRating': 0.0,
        'totalReviews': 0,
        'ratingDistribution': {
          '5': 0, '4': 0, '3': 0, '2': 0, '1': 0,
        },
        'recentReviews': [],
      };
    }
  }

  /// Check if user can review order
  static Future<bool> canReviewOrder(String orderId) async {
    try {
      final hasAccess = await AuthService.validateCustomerAccess();
      if (!hasAccess) return false;

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '/orders/$orderId/can-review',
        requiresAuth: true,
      );

      return response['data']?['can_review'] == true;
    } catch (e) {
      print('❌ ReviewService: Check can review order error: $e');
      return false;
    }
  }

  /// Check if user can review service order
  static Future<bool> canReviewServiceOrder(String serviceOrderId) async {
    try {
      final hasAccess = await AuthService.validateCustomerAccess();
      if (!hasAccess) return false;

      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '/service-orders/$serviceOrderId/can-review',
        requiresAuth: true,
      );

      return response['data']?['can_review'] == true;
    } catch (e) {
      print('❌ ReviewService: Check can review service order error: $e');
      return false;
    }
  }

  /// Get rating distribution for display
  static Map<String, double> calculateRatingPercentages(Map<String, dynamic> ratingDistribution, int totalReviews) {
    try {
      if (totalReviews == 0) {
        return {'5': 0.0, '4': 0.0, '3': 0.0, '2': 0.0, '1': 0.0};
      }

      final percentages = <String, double>{};
      for (int i = 5; i >= 1; i--) {
        final count = ratingDistribution[i.toString()] ?? 0;
        percentages[i.toString()] = (count / totalReviews) * 100;
      }

      return percentages;
    } catch (e) {
      return {'5': 0.0, '4': 0.0, '3': 0.0, '2': 0.0, '1': 0.0};
    }
  }

  /// Format rating for display
  static String formatRating(double rating, {int decimals = 1}) {
    try {
      return rating.toStringAsFixed(decimals);
    } catch (e) {
      return '0.0';
    }
  }

  /// Get rating text description
  static String getRatingText(int rating) {
    switch (rating) {
      case 5:
        return 'Sangat Bagus';
      case 4:
        return 'Bagus';
      case 3:
        return 'Cukup';
      case 2:
        return 'Kurang';
      case 1:
        return 'Sangat Kurang';
      default:
        return 'Tidak Ada Rating';
    }
  }

  /// Get star icons based on rating
  static List<bool> getStarStates(double rating) {
    final stars = <bool>[];
    for (int i = 1; i <= 5; i++) {
      stars.add(i <= rating.round());
    }
    return stars;
  }

  /// Validate review content
  static Map<String, String> validateReviewInput({
    required int rating,
    String? comment,
  }) {
    final errors = <String, String>{};

    if (rating < 1 || rating > 5) {
      errors['rating'] = 'Rating harus antara 1 dan 5';
    }

    if (comment != null) {
      if (comment.length > 500) {
        errors['comment'] = 'Komentar maksimal 500 karakter';
      }

      // Check for inappropriate content (basic check)
      final inappropriateWords = ['spam', 'fake', 'bodo', 'bangsat'];
      final lowerComment = comment.toLowerCase();
      for (final word in inappropriateWords) {
        if (lowerComment.contains(word)) {
          errors['comment'] = 'Komentar mengandung kata yang tidak pantas';
          break;
        }
      }
    }

    return errors;
  }
  /// Get review summary for entity
  static String getReviewSummary(double averageRating, int totalReviews) {
    try {
      if (totalReviews == 0) {
        return 'Belum ada review';
      }

      final ratingText = getRatingText(averageRating.round());
      return '${formatRating(averageRating)} ($totalReviews review) • $ratingText';
    } catch (e) {
      return 'Belum ada review';
    }
  }

  // PRIVATE HELPER METHODS

  /// Process review images
  static void _processReviewImages(Map<String, dynamic> review) {
    try {
      // Process customer avatar
      if (review['customer'] != null && review['customer']['avatar'] != null) {
        review['customer']['avatar'] = ImageService.getImageUrl(review['customer']['avatar']);
      }

      // Process order images if present
      if (review['order'] != null) {
        // Process store image
        if (review['order']['store'] != null && review['order']['store']['image_url'] != null) {
          review['order']['store']['image_url'] = ImageService.getImageUrl(review['order']['store']['image_url']);
        }

        // Process order items images
        if (review['order']['items'] != null) {
          final items = review['order']['items'] as List;
          for (var item in items) {
            if (item['image_url'] != null) {
              item['image_url'] = ImageService.getImageUrl(item['image_url']);
            }
          }
        }
      }

      // Process driver images if present
      if (review['driver'] != null) {
        if (review['driver']['user'] != null && review['driver']['user']['avatar'] != null) {
          review['driver']['user']['avatar'] = ImageService.getImageUrl(review['driver']['user']['avatar']);
        } else if (review['driver']['avatar'] != null) {
          review['driver']['avatar'] = ImageService.getImageUrl(review['driver']['avatar']);
        }
      }
    } catch (e) {
      print('❌ ReviewService: Error processing review images: $e');
    }
  }
}