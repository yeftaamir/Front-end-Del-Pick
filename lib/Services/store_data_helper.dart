// lib/Services/store_data_helper.dart
import 'dart:convert';
import 'auth_service.dart';
import 'Core/token_service.dart';

/// Helper service to manage store data and resolve store ID issues
class StoreDataHelper {

  /// Get store ID with comprehensive fallback methods
  static Future<String?> getStoreId() async {
    try {
      print('🏪 StoreDataHelper: Starting store ID resolution...');

      // Method 1: Try getRoleSpecificData() first
      final roleSpecificData = await AuthService.getRoleSpecificData();
      if (roleSpecificData != null) {
        final storeId = _extractStoreId(roleSpecificData, 'getRoleSpecificData');
        if (storeId != null) return storeId;
      }

      // Method 2: Try getUserData()
      final userData = await AuthService.getUserData();
      if (userData != null) {
        final storeId = _extractStoreId(userData, 'getUserData');
        if (storeId != null) return storeId;
      }

      // Method 3: Try getProfile()
      final profile = await AuthService.getProfile();
      if (profile != null) {
        final storeId = _extractStoreId(profile, 'getProfile');
        if (storeId != null) return storeId;
      }

      // Method 4: Try refreshUserData()
      final refreshedData = await AuthService.refreshUserData();
      if (refreshedData != null) {
        final storeId = _extractStoreId(refreshedData, 'refreshUserData');
        if (storeId != null) return storeId;
      }

      print('❌ StoreDataHelper: Store ID not found in any data source');
      return null;

    } catch (e) {
      print('❌ StoreDataHelper: Error getting store ID: $e');
      return null;
    }
  }

  /// Extract store ID from various data structures
  static String? _extractStoreId(Map<String, dynamic> data, String source) {
    try {
      // Direct store access
      if (data['store'] != null && data['store']['id'] != null) {
        final storeId = data['store']['id'].toString();
        print('✅ StoreDataHelper: Store ID found in $source[store]: $storeId');
        return storeId;
      }

      // User nested store access
      if (data['user'] != null && data['user']['store'] != null && data['user']['store']['id'] != null) {
        final storeId = data['user']['store']['id'].toString();
        print('✅ StoreDataHelper: Store ID found in $source[user][store]: $storeId');
        return storeId;
      }

      // Direct user store ID
      if (data['user'] != null && data['user']['store_id'] != null) {
        final storeId = data['user']['store_id'].toString();
        print('✅ StoreDataHelper: Store ID found in $source[user][store_id]: $storeId');
        return storeId;
      }

      // Root level store_id
      if (data['store_id'] != null) {
        final storeId = data['store_id'].toString();
        print('✅ StoreDataHelper: Store ID found in $source[store_id]: $storeId');
        return storeId;
      }

      print('⚠️ StoreDataHelper: No store ID found in $source');
      return null;

    } catch (e) {
      print('❌ StoreDataHelper: Error extracting store ID from $source: $e');
      return null;
    }
  }

  /// Get complete store information
  static Future<Map<String, dynamic>?> getStoreInfo() async {
    try {
      print('🏪 StoreDataHelper: Getting complete store info...');

      // Try role-specific data first
      final roleSpecificData = await AuthService.getRoleSpecificData();
      if (roleSpecificData != null && roleSpecificData['store'] != null) {
        print('✅ StoreDataHelper: Store info found in role-specific data');
        return roleSpecificData['store'];
      }

      // Try user data
      final userData = await AuthService.getUserData();
      if (userData != null) {
        if (userData['store'] != null) {
          print('✅ StoreDataHelper: Store info found in user data');
          return userData['store'];
        }
        if (userData['user'] != null && userData['user']['store'] != null) {
          print('✅ StoreDataHelper: Store info found in nested user data');
          return userData['user']['store'];
        }
      }

      // Try profile
      final profile = await AuthService.getProfile();
      if (profile != null && profile['store'] != null) {
        print('✅ StoreDataHelper: Store info found in profile');
        return profile['store'];
      }

      print('❌ StoreDataHelper: No store info found');
      return null;

    } catch (e) {
      print('❌ StoreDataHelper: Error getting store info: $e');
      return null;
    }
  }

  /// Validate if user is a store owner
  static Future<bool> isStoreOwner() async {
    try {
      final userRole = await AuthService.getUserRole();
      final storeId = await getStoreId();

      final isOwner = userRole?.toLowerCase() == 'store' && storeId != null;
      print('🏪 StoreDataHelper: Is store owner: $isOwner (role: $userRole, storeId: $storeId)');

      return isOwner;
    } catch (e) {
      print('❌ StoreDataHelper: Error checking store owner status: $e');
      return false;
    }
  }

  /// Debug method to print all available data
  static Future<void> debugStoreData() async {
    try {
      print('🔍 ====== STORE DATA DEBUG ======');

      final userRole = await AuthService.getUserRole();
      print('👤 User Role: $userRole');

      final userData = await AuthService.getUserData();
      print('📁 User Data: ${_formatJson(userData)}');

      final roleSpecificData = await AuthService.getRoleSpecificData();
      print('🎯 Role Specific Data: ${_formatJson(roleSpecificData)}');

      final storeId = await getStoreId();
      print('🏪 Resolved Store ID: $storeId');

      final storeInfo = await getStoreInfo();
      print('📋 Store Info: ${_formatJson(storeInfo)}');

      final isOwner = await isStoreOwner();
      print('✅ Is Store Owner: $isOwner');

      print('🔍 ====== END DEBUG ======');

    } catch (e) {
      print('❌ StoreDataHelper: Debug error: $e');
    }
  }

  /// Format JSON for better readability
  static String _formatJson(dynamic data) {
    if (data == null) return 'null';
    try {
      return JsonEncoder.withIndent('  ').convert(data);
    } catch (e) {
      return data.toString();
    }
  }

  /// Force refresh store data
  static Future<bool> refreshStoreData() async {
    try {
      print('🔄 StoreDataHelper: Forcing store data refresh...');

      // Clear cached data first
      await TokenService.clearToken();

      // Get fresh profile data
      final freshProfile = await AuthService.refreshUserData();

      if (freshProfile != null) {
        print('✅ StoreDataHelper: Store data refreshed successfully');
        return true;
      } else {
        print('❌ StoreDataHelper: Failed to refresh store data');
        return false;
      }

    } catch (e) {
      print('❌ StoreDataHelper: Error refreshing store data: $e');
      return false;
    }
  }

  /// Create store data summary for UI display
  static Future<Map<String, dynamic>> getStoreDataSummary() async {
    try {
      final storeId = await getStoreId();
      final storeInfo = await getStoreInfo();
      final isOwner = await isStoreOwner();
      final userRole = await AuthService.getUserRole();

      return {
        'storeId': storeId,
        'hasStoreData': storeInfo != null,
        'isStoreOwner': isOwner,
        'userRole': userRole,
        'storeName': storeInfo?['name'],
        'storeStatus': storeInfo?['status'],
        'canManageItems': isOwner && storeId != null,
        'dataSource': _getDataSource(storeInfo),
      };
    } catch (e) {
      print('❌ StoreDataHelper: Error creating store summary: $e');
      return {
        'storeId': null,
        'hasStoreData': false,
        'isStoreOwner': false,
        'userRole': null,
        'storeName': null,
        'storeStatus': null,
        'canManageItems': false,
        'dataSource': 'error',
        'error': e.toString(),
      };
    }
  }

  /// Determine which data source provided the store info
  static String _getDataSource(Map<String, dynamic>? storeInfo) {
    if (storeInfo == null) return 'none';
    // This is a simplified version - in practice, you'd track where the data came from
    return 'resolved';
  }

  /// Fix common store data issues
  static Future<Map<String, dynamic>> diagnoseAndFix() async {
    try {
      print('🔧 StoreDataHelper: Diagnosing store data issues...');

      final diagnosis = <String, dynamic>{
        'issues': <String>[],
        'fixes': <String>[],
        'status': 'unknown',
      };

      // Check user role
      final userRole = await AuthService.getUserRole();
      if (userRole != 'store') {
        diagnosis['issues'].add('User role is not "store" (current: $userRole)');
        diagnosis['status'] = 'role_mismatch';
        return diagnosis;
      }

      // Check store ID
      final storeId = await getStoreId();
      if (storeId == null) {
        diagnosis['issues'].add('Store ID not found in any data source');

        // Try to fix by refreshing data
        final refreshed = await refreshStoreData();
        if (refreshed) {
          diagnosis['fixes'].add('Attempted to refresh user data from server');

          // Check again
          final newStoreId = await getStoreId();
          if (newStoreId != null) {
            diagnosis['fixes'].add('Store ID resolved after refresh: $newStoreId');
            diagnosis['status'] = 'fixed';
          } else {
            diagnosis['status'] = 'unfixable';
          }
        } else {
          diagnosis['status'] = 'refresh_failed';
        }
      } else {
        diagnosis['status'] = 'healthy';
        diagnosis['fixes'].add('Store ID found: $storeId');
      }

      return diagnosis;

    } catch (e) {
      print('❌ StoreDataHelper: Error during diagnosis: $e');
      return {
        'issues': ['Diagnosis failed: $e'],
        'fixes': [],
        'status': 'error',
      };
    }
  }
}