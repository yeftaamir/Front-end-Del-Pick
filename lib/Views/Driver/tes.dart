// ✅ PERBAIKAN 6: Update detail button menjadi hijau (bukan abu-abu)

// ✅ PERBAIKAN 7: Enhanced filtering untuk status yang lebih sesuai
List<DriverRequestModel> getFilteredRequests(int tabIndex) {
  if (tabIndex == 0) return _driverRequests; // Semua

  final tabStatuses = _tabs[tabIndex]['statuses'] as List<String>?;
  if (tabStatuses == null) return _driverRequests;

  return _driverRequests.where((request) {
    final orderStatus = request.order?.orderStatus.value.toLowerCase() ?? '';
    return tabStatuses.contains(orderStatus);
  }).toList();
}

// ✅ PERBAIKAN 8: Clear cache when refreshing
Future<void> _fetchDriverRequests({bool isRefresh = false}) async {
  if (!_isAuthenticated) return;

  if (isRefresh) {
    _currentPage = 1;
    _storeNamesCache.clear(); // ✅ ADD: Clear store names cache on refresh
  }

  setState(() {
    if (isRefresh) {
      _isLoading = true;
    } else {
      _isLoadingMore = true;
    }
    _hasError = false;
  });

  try {
    print('🔄 HistoryDriver: Fetching driver requests - Page: $_currentPage');

    final response = await DriverRequestService.getDriverRequests(
      page: _currentPage,
      limit: 20,
      sortBy: 'created_at',
      sortOrder: 'desc',
    );

    final List<dynamic> requestsList = response['requests'] ?? [];
    _totalPages = response['totalPages'] ?? 1;

    List<DriverRequestModel> newRequests = [];
    for (var requestJson in requestsList) {
      try {
        final request = DriverRequestModel.fromJson(requestJson);
        newRequests.add(request);
      } catch (e) {
        print('Error processing request: $e');
      }
    }

    setState(() {
      if (isRefresh) {
        _driverRequests = newRequests;
      } else {
        _driverRequests.addAll(newRequests);
      }
      _isLoading = false;
      _isLoadingMore = false;
      _initializeAnimations();
    });

    print(
        '✅ HistoryDriver: Successfully loaded ${newRequests.length} requests');
  } catch (e) {
    print('❌ HistoryDriver: Error fetching requests: $e');
    setState(() {
      _isLoading = false;
      _isLoadingMore = false;
      _hasError = true;
      _errorMessage = 'Failed to load history: $e';
    });
  }
}

// ✅ PERBAIKAN 9: Store Service untuk mengambil data store
// Tambahkan method di StoreService jika belum ada:
/*
// lib/Services/store_service.dart

class StoreService {
  static const String _baseEndpoint = '/stores';

  /// Get store by ID
  static Future<Map<String, dynamic>> getStoreById(String storeId) async {
    try {
      final response = await BaseService.apiCall(
        method: 'GET',
        endpoint: '$_baseEndpoint/$storeId',
        requiresAuth: true,
      );

      if (response['data'] != null) {
        final storeData = response['data'];
        // Process store image
        if (storeData['image_url'] != null && storeData['image_url'].toString().isNotEmpty) {
          storeData['image_url'] = ImageService.getImageUrl(storeData['image_url']);
        }
        return storeData;
      }

      return {};
    } catch (e) {
      print('Get store by ID error: $e');
      throw Exception('Failed to get store: $e');
    }
  }
}
*/
