import 'package:flutter/material.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';

// Import proper services based on project architecture
import '../../Services/auth_service.dart';
import '../../Services/store_service.dart';
import '../../Services/user_service.dart';
import '../../Services/image_service.dart';
import '../../Services/Core/token_service.dart';
import '../Controls/login_page.dart';

class ProfileStorePage extends StatefulWidget {
  static const String route = "/Store/Profile";

  const ProfileStorePage({super.key});

  @override
  State<ProfileStorePage> createState() => _ProfileStorePageState();
}

class _ProfileStorePageState extends State<ProfileStorePage> with TickerProviderStateMixin {
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _storeData;
  bool _isLoading = true;
  bool _isUpdatingImage = false;
  bool _isUpdatingStatus = false;
  bool _hasError = false;
  String _errorMessage = '';

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadStoreProfile();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutQuart,
    ));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // Helper methods for safe type conversion
  double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  int _safeToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  String _safeToString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  /// Load store profile using updated service architecture
  /// Uses: getRoleSpecificData() -> getProfile() -> _processStoreSpecificData -> _processStoreData
  Future<void> _loadStoreProfile() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      print('🏪 ProfileStore: Starting profile load...');

      // Check authentication first
      final isAuthenticated = await AuthService.isAuthenticated();
      if (!isAuthenticated) {
        print('❌ ProfileStore: User not authenticated');
        _navigateToLogin();
        return;
      }

      // STEP 1: Use getRoleSpecificData() to get role-specific structured data
      Map<String, dynamic>? profileData = await AuthService.getRoleSpecificData();

      if (profileData != null && profileData.isNotEmpty) {
        print('✅ ProfileStore: Got data from getRoleSpecificData()');
        await _processStoreSpecificData(profileData);
      } else {
        // STEP 2: Fallback to getProfile() if getRoleSpecificData() fails
        print('⚠️ ProfileStore: getRoleSpecificData() failed, trying getProfile()...');
        profileData = await AuthService.getProfile();

        if (profileData != null && profileData.isNotEmpty) {
          print('✅ ProfileStore: Got data from getProfile()');
          await _processStoreSpecificData(profileData);
        } else {
          // STEP 3: Last resort - use cached data
          print('⚠️ ProfileStore: getProfile() failed, trying cached data...');
          final cachedData = await AuthService.getUserData();
          if (cachedData != null) {
            print('✅ ProfileStore: Got cached data');
            await _processStoreSpecificData(cachedData);
          } else {
            throw Exception('No profile data available from any source');
          }
        }
      }

      // Start animations if data was loaded successfully
      if (mounted && _userProfile != null) {
        _fadeController.forward();
        _slideController.forward();
      }

    } catch (e) {
      print('❌ ProfileStore: Error loading profile: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Process store-specific data using the service architecture pattern
  /// This method handles the data structure based on different response formats
  Future<void> _processStoreSpecificData(Map<String, dynamic> data) async {
    try {
      print('🏪 ProfileStore: Processing store-specific data...');
      print('🔍 ProfileStore: Input data structure: ${data.keys.toList()}');

      Map<String, dynamic>? userData;
      Map<String, dynamic>? storeData;

      // Handle different data structures from different service calls
      if (data.containsKey('user') && data.containsKey('store')) {
        // Structure from getRoleSpecificData() or processed data
        userData = data['user'];
        storeData = data['store'];
        print('✅ ProfileStore: Found user and store data structure');
      } else if (data.containsKey('user') && data['user'] != null) {
        // Structure where store data might be nested in user
        userData = data['user'];
        storeData = userData?['store'] ?? userData;
        print('✅ ProfileStore: Found user data, extracting store data');
      } else if (data.containsKey('store')) {
        // Structure where store data is at root level
        userData = data;
        storeData = data['store'];
        print('✅ ProfileStore: Found store data at root level');
      } else {
        // Assume the data is the user data itself with store info
        userData = data;
        storeData = data;
        print('✅ ProfileStore: Using data as user data');
      }

      // Validate that this is actually store data
      final userRole = _safeToString(userData?['role']).toLowerCase();
      if (userRole != 'store' && storeData?['name'] == null && storeData?['address'] == null) {
        throw Exception('Invalid store data - role: $userRole');
      }

      // Process the store data using the pattern from AuthService._processStoreData
      await _processStoreData(storeData ?? {});

      // Update state with processed data
      if (mounted) {
        setState(() {
          _userProfile = userData;
          _storeData = storeData;
        });
      }

      print('✅ ProfileStore: Store-specific data processed successfully');
      print('   - Store ID: ${_safeToString(storeData?['id'])}');
      print('   - Store Name: ${_safeToString(storeData?['name'])}');
      print('   - Store Status: ${_safeToString(storeData?['status'])}');

    } catch (e) {
      print('❌ ProfileStore: Error processing store-specific data: $e');
      throw Exception('Failed to process store data: $e');
    }
  }

  /// Process store data following the service pattern from AuthService._processStoreData
  /// Ensures all required store fields have defaults and proper processing
  Future<void> _processStoreData(Map<String, dynamic> storeData) async {
    try {
      print('🏪 ProfileStore: Processing store data fields...');

      // Process store image first (following AuthService pattern)
      if (storeData['image_url'] != null && storeData['image_url'].toString().isNotEmpty) {
        storeData['image_url'] = ImageService.getImageUrl(storeData['image_url']);
      }

      // Ensure all required store fields with defaults (following AuthService pattern)
      storeData['id'] = storeData['id'] ?? 0;
      storeData['name'] = _safeToString(storeData['name']).isNotEmpty
          ? _safeToString(storeData['name'])
          : 'Store';
      storeData['description'] = _safeToString(storeData['description']);
      storeData['address'] = _safeToString(storeData['address']);
      storeData['phone'] = _safeToString(storeData['phone']);
      storeData['rating'] = _safeToDouble(storeData['rating']);
      storeData['review_count'] = _safeToInt(storeData['review_count']);
      storeData['total_products'] = _safeToInt(storeData['total_products']);
      storeData['status'] = _safeToString(storeData['status']).isNotEmpty
          ? _safeToString(storeData['status'])
          : 'active';

      // Process time fields
      storeData['open_time'] = _safeToString(storeData['open_time']);
      storeData['close_time'] = _safeToString(storeData['close_time']);

      // Process location fields
      storeData['latitude'] = storeData['latitude'];
      storeData['longitude'] = storeData['longitude'];

      // Process categories if available
      if (storeData['categories'] != null) {
        // Ensure categories is a list
        if (storeData['categories'] is! List) {
          storeData['categories'] = [];
        }
      } else {
        storeData['categories'] = [];
      }

      // Ensure store ID is available (critical check from helper)
      if (storeData['id'] == null || _safeToString(storeData['id']).isEmpty) {
        print('⚠️ ProfileStore: Store ID is null or empty!');
        storeData['id'] = 0; // Set default but this might cause issues
      }

      print('✅ ProfileStore: Store data fields processed');
      print('   - Name: ${storeData['name']}');
      print('   - Status: ${storeData['status']}');
      print('   - Rating: ${storeData['rating']}');
      print('   - Products: ${storeData['total_products']}');

    } catch (e) {
      print('❌ ProfileStore: Error processing store data fields: $e');
      throw e;
    }
  }

  /// Update store image using ImageService and StoreService
  Future<void> _updateStoreImage() async {
    if (_storeData == null) return;

    setState(() {
      _isUpdatingImage = true;
    });

    try {
      // Show image picker bottom sheet
      final imageFile = await ImageService.showImagePickerBottomSheet(
        context,
        allowCamera: true,
        allowGallery: true,
      );

      if (imageFile == null) {
        setState(() {
          _isUpdatingImage = false;
        });
        return;
      }

      // Validate image file
      if (!ImageService.isValidImageFile(imageFile)) {
        _showErrorSnackBar('Please select a valid image file');
        setState(() {
          _isUpdatingImage = false;
        });
        return;
      }

      // Check image size (limit to 5MB)
      final imageSizeMB = await ImageService.getImageSizeInMB(imageFile);
      if (imageSizeMB > 5) {
        _showErrorSnackBar('Image size should be less than 5MB');
        setState(() {
          _isUpdatingImage = false;
        });
        return;
      }

      // Convert image to base64
      final base64Image = await ImageService.imageToBase64(imageFile);
      if (base64Image == null) {
        _showErrorSnackBar('Failed to process image');
        setState(() {
          _isUpdatingImage = false;
        });
        return;
      }

      // Update store profile using StoreService
      final storeId = _safeToString(_storeData!['id']);
      if (storeId.isEmpty || storeId == '0') {
        throw Exception('Store ID not found');
      }

      final updateData = {
        'image': base64Image,
      };

      final updatedStore = await StoreService.updateStoreProfile(
        storeId: storeId,
        updateData: updateData,
      );

      if (updatedStore.isNotEmpty) {
        // Reload profile to get updated data using the new service architecture
        await _loadStoreProfile();

        if (!mounted) return;
        _showSuccessSnackBar('Store image updated successfully');
      } else {
        _showErrorSnackBar('Failed to update store image');
      }
    } catch (e) {
      print('Error updating store image: $e');
      _showErrorSnackBar('Error updating store image: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingImage = false;
        });
      }
    }
  }

  /// Update store status using StoreService
  Future<void> _updateStoreStatus(String newStatus) async {
    if (_storeData == null) return;

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      final storeId = _safeToString(_storeData!['id']);
      if (storeId.isEmpty || storeId == '0') {
        throw Exception('Store ID not found');
      }

      // Update status using StoreService
      final result = await StoreService.updateStoreProfile(
        storeId: storeId,
        updateData: {'status': newStatus},
      );

      if (result.isNotEmpty) {
        // Reload profile to get updated data using the new service architecture
        await _loadStoreProfile();

        if (!mounted) return;
        _showSuccessSnackBar('Store status updated to ${_getStatusText(newStatus)}');
      } else {
        _showErrorSnackBar('Failed to update store status');
      }
    } catch (e) {
      print('Error updating store status: $e');
      _showErrorSnackBar('Error updating status: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
  }

  /// Refresh profile data using the service architecture
  Future<void> _refreshProfile() async {
    try {
      print('🔄 ProfileStore: Refreshing profile data...');

      // Use AuthService.refreshUserData() to get fresh data from server
      final refreshedProfile = await AuthService.refreshUserData();

      if (refreshedProfile != null && mounted) {
        print('✅ ProfileStore: Profile refreshed, processing data...');
        await _processStoreSpecificData(refreshedProfile);
      } else {
        // If refresh fails, try reloading with full process
        print('⚠️ ProfileStore: Refresh failed, doing full reload...');
        await _loadStoreProfile();
      }
    } catch (e) {
      print('❌ ProfileStore: Error refreshing profile: $e');
      // If refresh fails, try full reload
      await _loadStoreProfile();
    }
  }

  /// Handle logout using AuthService
  void _handleLogout() async {
    _showLoadingDialog('Logging out...');

    try {
      final success = await AuthService.logout();
      if (success) {
        _navigateToLogin();
      } else {
        // Even if logout fails on server, clear local data and navigate
        await TokenService.clearAll();
        _navigateToLogin();
      }
    } catch (e) {
      print('Logout error: $e');
      // Force logout by clearing local data
      await TokenService.clearAll();
      _navigateToLogin();
    }
  }

  /// Navigate to login page
  void _navigateToLogin() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
    );
  }

  /// View store image in full screen
  void _viewStoreImage() {
    final imageUrl = _storeData?['image_url'];
    if (imageUrl == null || _safeToString(imageUrl).isEmpty) return;

    final processedImageUrl = ImageService.getImageUrl(_safeToString(imageUrl));
    if (processedImageUrl.isEmpty) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: ImageService.displayImage(
                    imageSource: processedImageUrl,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.contain,
                    placeholder: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    errorWidget: Container(
                      color: Colors.grey[900],
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, size: 80, color: Colors.white54),
                          SizedBox(height: 16),
                          Text(
                            'Failed to load image',
                            style: TextStyle(color: Colors.white54, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Show status update dialog
  void _showStatusUpdateDialog() {
    final currentStatus = _safeToString(_storeData?['status']).isNotEmpty
        ? _safeToString(_storeData?['status'])
        : 'active';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Update Store Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusOption('active', 'Open - Store is accepting orders', currentStatus),
              _buildStatusOption('inactive', 'Temporarily Closed - Not taking orders', currentStatus),
              _buildStatusOption('closed', 'Permanently Closed', currentStatus),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusOption(String status, String description, String currentStatus) {
    final isSelected = status == currentStatus;

    return ListTile(
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: _getStatusColor(status),
          shape: BoxShape.circle,
        ),
      ),
      title: Text(_getStatusText(status)),
      subtitle: Text(description),
      trailing: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
      onTap: isSelected ? null : () {
        Navigator.pop(context);
        _updateStoreStatus(status);
      },
    );
  }

  // Helper methods
  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(GlobalStyle.primaryColor),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: TextStyle(
                    fontFamily: GlobalStyle.fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Safe getters for user data
  String get userName => _safeToString(_userProfile?['name']).isNotEmpty
      ? _safeToString(_userProfile?['name'])
      : 'Store Owner';
  String get userEmail => _safeToString(_userProfile?['email']);
  String get userPhone => _safeToString(_userProfile?['phone']);
  String get userId => _safeToString(_userProfile?['id']);

  // Safe getters for store data
  String get storeName => _safeToString(_storeData?['name']).isNotEmpty
      ? _safeToString(_storeData?['name'])
      : 'Store';
  String get storeDescription => _safeToString(_storeData?['description']);
  String get storeAddress => _safeToString(_storeData?['address']);
  String get storePhone => _safeToString(_storeData?['phone']);
  String get storeStatus => _safeToString(_storeData?['status']).isNotEmpty
      ? _safeToString(_storeData?['status'])
      : 'active';
  double get storeRating => _safeToDouble(_storeData?['rating']);
  int get reviewCount => _safeToInt(_storeData?['review_count']);
  int get totalProducts => _safeToInt(_storeData?['total_products']);
  String get openTime => _safeToString(_storeData?['open_time']);
  String get closeTime => _safeToString(_storeData?['close_time']);
  String? get storeImageUrl => _storeData?['image_url'];

  String get openHours {
    if (openTime.isNotEmpty && closeTime.isNotEmpty) {
      return '$openTime - $closeTime';
    }
    return 'Not specified';
  }

  String _getStatusText(String? status) {
    switch (_safeToString(status).toLowerCase()) {
      case 'active':
        return 'Open';
      case 'inactive':
        return 'Temporarily Closed';
      case 'closed':
        return 'Closed';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor(String? status) {
    switch (_safeToString(status).toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.orange;
      case 'closed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? _buildLoadingWidget()
          : _hasError
          ? _buildErrorWidget()
          : _userProfile == null
          ? _buildNoDataWidget()
          : _buildProfileContent(),
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(GlobalStyle.primaryColor),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading store profile...',
            style: TextStyle(
              fontFamily: GlobalStyle.fontFamily,
              fontSize: 16,
              color: GlobalStyle.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.red[400]),
          const SizedBox(height: 24),
          Text(
            'Unable to load store profile',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage.isNotEmpty ? _errorMessage : 'Please check your connection',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontFamily: GlobalStyle.fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _loadStoreProfile,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.store_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text(
            'No store profile data available',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _loadStoreProfile,
            icon: const Icon(Icons.refresh),
            label: const Text('Reload'),
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent() {
    return RefreshIndicator(
      onRefresh: _refreshProfile,
      color: GlobalStyle.primaryColor,
      child: CustomScrollView(
        slivers: [
          _buildAppBar(),
          _buildProfileSections(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 320,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double top = constraints.biggest.height;
          final bool isCollapsed = top <= kToolbarHeight + 50;

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  GlobalStyle.primaryColor,
                  GlobalStyle.primaryColor.withOpacity(0.8),
                ],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: GlobalStyle.primaryColor.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: FlexibleSpaceBar(
              title: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isCollapsed ? 1.0 : 0.0,
                child: Text(
                  storeName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              background: _buildProfileHeader(),
            ),
          );
        },
      ),
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Background Pattern
        Positioned(
          right: -50,
          top: -50,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
        ),
        Positioned(
          left: -30,
          bottom: -30,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
            ),
          ),
        ),

        // Store Image Background
        if (storeImageUrl != null && storeImageUrl!.isNotEmpty)
          Positioned.fill(
            child: Opacity(
              opacity: 0.3,
              child: ImageService.displayImage(
                imageSource: storeImageUrl!,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),

        // Profile Content
        FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                _buildStoreImage(),
                const SizedBox(height: 20),
                Text(
                  storeName,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                _buildRoleAndStatusBadges(),
                const SizedBox(height: 12),
                if (openHours != 'Not specified')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time,
                          color: Colors.white.withOpacity(0.9),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          openHours,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                            fontFamily: GlobalStyle.fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStoreImage() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.3),
                Colors.white.withOpacity(0.1),
              ],
            ),
          ),
        ),
        GestureDetector(
          onTap: _viewStoreImage,
          child: Hero(
            tag: 'storeImage',
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: storeImageUrl != null && storeImageUrl!.isNotEmpty
                    ? ImageService.displayImage(
                  imageSource: storeImageUrl!,
                  width: 130,
                  height: 130,
                  fit: BoxFit.cover,
                  placeholder: Container(
                    color: Colors.white,
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          GlobalStyle.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  errorWidget: Container(
                    color: Colors.white,
                    child: Icon(
                      Icons.store,
                      size: 60,
                      color: GlobalStyle.primaryColor,
                    ),
                  ),
                )
                    : Container(
                  color: Colors.white,
                  child: Icon(
                    Icons.store,
                    size: 60,
                    color: GlobalStyle.primaryColor,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _isUpdatingImage ? null : _updateStoreImage,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, Colors.grey[100]!],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _isUpdatingImage
                  ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    GlobalStyle.primaryColor,
                  ),
                ),
              )
                  : Icon(
                Icons.camera_alt,
                color: GlobalStyle.primaryColor,
                size: 22,
              ),
            ),
          ),
        ),
        // Rating Badge
        if (storeRating > 0)
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber[600]!, Colors.amber[800]!],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '$storeRating ($reviewCount)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRoleAndStatusBadges() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.store, color: Colors.white, size: 16),
              SizedBox(width: 6),
              Text(
                'STORE',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _isUpdatingStatus ? null : _showStatusUpdateDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _getStatusColor(storeStatus).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isUpdatingStatus)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                const SizedBox(width: 6),
                Text(
                  _getStatusText(storeStatus),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.edit, color: Colors.white, size: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileSections() {
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStoreInfoSection(),
              const SizedBox(height: 32),
              _buildLocationAndHoursSection(),
              const SizedBox(height: 32),
              _buildLogoutButton(),
              _buildAppVersionInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoreInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          icon: Icons.store_mall_directory,
          title: 'Store Information',
          color: GlobalStyle.primaryColor,
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          children: [
            _buildInfoItem(
              icon: FontAwesomeIcons.store,
              title: 'Store Name',
              value: storeName,
              iconColor: Colors.blue[600]!,
            ),
            _buildDivider(),
            _buildInfoItem(
              icon: FontAwesomeIcons.circleInfo,
              title: 'Description',
              value: storeDescription.isNotEmpty
                  ? storeDescription
                  : 'No description available',
              iconColor: Colors.purple[600]!,
              isDescription: true,
            ),
            _buildDivider(),
            _buildInfoItem(
              icon: FontAwesomeIcons.phone,
              title: 'Store Phone',
              value: storePhone.isNotEmpty ? storePhone : 'Not provided',
              iconColor: Colors.green[600]!,
            ),
            _buildDivider(),
            _buildInfoItem(
              icon: FontAwesomeIcons.user,
              title: 'Owner',
              value: userName,
              iconColor: Colors.orange[600]!,
            ),
            _buildDivider(),
            _buildInfoItem(
              icon: FontAwesomeIcons.boxOpen,
              title: 'Total Products',
              value: totalProducts > 0 ? '$totalProducts products' : 'No products yet',
              iconColor: Colors.indigo[600]!,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationAndHoursSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          icon: Icons.location_on,
          title: 'Location & Hours',
          color: Colors.red[700]!,
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          children: [
            _buildInfoItem(
              icon: FontAwesomeIcons.locationDot,
              title: 'Address',
              value: storeAddress.isNotEmpty ? storeAddress : 'Not provided',
              iconColor: Colors.red[600]!,
              isDescription: true,
            ),
            _buildDivider(),
            _buildInfoItem(
              icon: FontAwesomeIcons.clock,
              title: 'Opening Hours',
              value: openHours,
              iconColor: Colors.orange[600]!,
            ),
            _buildDivider(),
            _buildInfoItem(
              icon: FontAwesomeIcons.circleCheck,
              title: 'Current Status',
              value: _getStatusText(storeStatus),
              iconColor: _getStatusColor(storeStatus),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.red[400]!, Colors.red[600]!]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleLogout,
          borderRadius: BorderRadius.circular(16),
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout, color: Colors.white, size: 24),
                SizedBox(width: 12),
                Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppVersionInfo() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.store,
                size: 40,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'DelPick Store v1.0.0',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: GlobalStyle.fontColor,
            fontFamily: GlobalStyle.fontFamily,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String value,
    required Color iconColor,
    bool isDescription = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: isDescription
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: FaIcon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: GlobalStyle.fontColor,
                    fontFamily: GlobalStyle.fontFamily,
                    height: isDescription ? 1.4 : null,
                  ),
                  maxLines: isDescription ? null : 2,
                  overflow: isDescription ? null : TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey[100],
      indent: 80,
    );
  }
}