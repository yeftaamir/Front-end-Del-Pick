import 'dart:convert';
import 'dart:isolate';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';

// Import proper services based on project architecture
import '../../Services/auth_service.dart';
import '../../Services/user_service.dart';
import '../../Services/image_service.dart';
import '../../Services/Core/token_service.dart';
import '../Controls/login_page.dart';

// Ultra-Optimized Cache System for Profile
class _ProfileCacheManager {
  static Map<String, dynamic>? _cachedProfile;
  static DateTime? _cacheTimestamp;
  static String? _cachedAvatarUrl;
  static const Duration _cacheExpiry = Duration(minutes: 5);
  static const Duration _avatarCacheExpiry = Duration(minutes: 15);

  static bool _isProfileCacheValid() {
    return _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheExpiry;
  }

  static void cacheProfile(Map<String, dynamic> profile) {
    _cachedProfile = Map<String, dynamic>.from(profile);
    _cacheTimestamp = DateTime.now();
  }

  static Map<String, dynamic>? getCachedProfile() {
    return _isProfileCacheValid() ? _cachedProfile : null;
  }

  static void cacheAvatarUrl(String avatarUrl) {
    _cachedAvatarUrl = avatarUrl;
  }

  static String? getCachedAvatarUrl() {
    return _cachedAvatarUrl;
  }

  static void clearCache() {
    _cachedProfile = null;
    _cacheTimestamp = null;
    _cachedAvatarUrl = null;
  }

  static void updateProfileField(String key, dynamic value) {
    if (_cachedProfile != null) {
      _cachedProfile![key] = value;
    }
  }
}

// Background Processing for Profile Operations
class _ProfileBackgroundProcessor {
  static Future<String?> processImageInBackground(XFile imageFile) async {
    return await Isolate.run(() async {
      try {
        // Validate image file
        if (!ImageService.isValidImageFile(imageFile)) {
          return null;
        }

        // Check image size
        final imageSizeMB = await ImageService.getImageSizeInMB(imageFile);
        if (imageSizeMB > 5) {
          throw Exception('Image size too large');
        }

        // Convert to base64
        return await ImageService.imageToBase64(imageFile);
      } catch (e) {
        return null;
      }
    });
  }

  static Future<Map<String, dynamic>?> loadProfileInBackground() async {
    try {
      // Check cache first
      final cachedProfile = _ProfileCacheManager.getCachedProfile();
      if (cachedProfile != null) {
        return cachedProfile;
      }

      // Load from service
      final profileData = await AuthService.getProfile();
      if (profileData != null && profileData.isNotEmpty) {
        _ProfileCacheManager.cacheProfile(profileData);
        return profileData;
      }

      // Fallback to cached user data
      final cachedData = await AuthService.getUserData();
      if (cachedData != null && cachedData['user'] != null) {
        return cachedData['user'];
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> updateProfileInBackground({
    required Map<String, dynamic> updateData,
  }) async {
    try {
      final updatedProfile = await AuthService.updateProfile(updateData: updateData);
      if (updatedProfile.isNotEmpty) {
        _ProfileCacheManager.cacheProfile(updatedProfile);
        return updatedProfile;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

class ProfilePage extends StatefulWidget {
  static const String route = "/Customers/Profile";

  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {

  static const bool _debugMode = false;

  void _log(String message) {
    if (_debugMode) print(message);
  }

  @override
  bool get wantKeepAlive => true;

  // Performance-Optimized State with ValueNotifiers
  final ValueNotifier<Map<String, dynamic>?> _userProfileNotifier = ValueNotifier(null);
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(true);
  final ValueNotifier<bool> _isUpdatingImageNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _hasErrorNotifier = ValueNotifier(false);
  final ValueNotifier<String> _errorMessageNotifier = ValueNotifier('');

  // Optimized Animation Controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Performance flags
  bool _disposed = false;
  bool _initialLoadComplete = false;

  @override
  void initState() {
    super.initState();
    _initializeControllersOptimized();
    _loadUserProfileOptimized();
  }

  void _initializeControllersOptimized() {
    // Lighter, faster animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400), // Reduced from 800ms
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300), // Reduced from 600ms
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut, // Faster curve
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05), // Reduced movement
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut, // Faster curve
    ));
  }

  // Ultra-Fast Profile Loading with Caching
  Future<void> _loadUserProfileOptimized() async {
    if (_disposed) return;

    _isLoadingNotifier.value = true;
    _hasErrorNotifier.value = false;
    _errorMessageNotifier.value = '';

    try {
      _log('Starting profile load...');

      // Check authentication first
      final isAuthenticated = await AuthService.isAuthenticated();
      if (!isAuthenticated) {
        _navigateToLogin();
        return;
      }

      // Try cache first for instant loading
      final cachedProfile = _ProfileCacheManager.getCachedProfile();
      if (cachedProfile != null && !_initialLoadComplete) {
        _log('Using cached profile');
        _userProfileNotifier.value = cachedProfile;
        _startAnimationsOptimized();
        _isLoadingNotifier.value = false;
        _initialLoadComplete = true;

        // Load fresh data in background
        _refreshProfileInBackground();
        return;
      }

      // Load profile in background
      final profileData = await _ProfileBackgroundProcessor.loadProfileInBackground();

      if (profileData != null && profileData.isNotEmpty) {
        if (!_disposed) {
          _userProfileNotifier.value = profileData;
          _startAnimationsOptimized();
          _initialLoadComplete = true;
        }
      } else {
        throw Exception('Profile data is empty');
      }

    } catch (e) {
      _log('Profile loading error: $e');

      // Try cached data as final fallback
      final cachedProfile = _ProfileCacheManager.getCachedProfile();
      if (cachedProfile != null) {
        _userProfileNotifier.value = cachedProfile;
        _startAnimationsOptimized();
      } else {
        _hasErrorNotifier.value = true;
        _errorMessageNotifier.value = e.toString();
      }
    } finally {
      if (!_disposed) {
        _isLoadingNotifier.value = false;
      }
    }
  }

  // Background Profile Refresh
  Future<void> _refreshProfileInBackground() async {
    try {
      _log('Refreshing profile in background...');
      final freshProfile = await AuthService.getProfile();

      if (freshProfile != null && freshProfile.isNotEmpty && !_disposed) {
        _ProfileCacheManager.cacheProfile(freshProfile);
        _userProfileNotifier.value = freshProfile;
        _log('Profile refreshed successfully');
      }
    } catch (e) {
      _log('Background refresh failed: $e');
      // Silent fail for background refresh
    }
  }

  // Ultra-Optimized Image Update
  Future<void> _updateProfileImageOptimized() async {
    if (_userProfileNotifier.value == null || _isUpdatingImageNotifier.value) return;

    _isUpdatingImageNotifier.value = true;

    try {
      _log('Starting image update...');

      // Show image picker
      final imageFile = await ImageService.showImagePickerBottomSheet(
        context,
        allowCamera: true,
        allowGallery: true,
      );

      if (imageFile == null) {
        _isUpdatingImageNotifier.value = false;
        return;
      }

      // Process image in background
      final base64Image = await _ProfileBackgroundProcessor.processImageInBackground(imageFile);

      if (base64Image == null) {
        _showErrorSnackBar('Failed to process image');
        _isUpdatingImageNotifier.value = false;
        return;
      }

      // Update profile optimistically in UI first
      final currentProfile = Map<String, dynamic>.from(_userProfileNotifier.value!);
      currentProfile['avatar'] = base64Image;
      _userProfileNotifier.value = currentProfile;
      _ProfileCacheManager.updateProfileField('avatar', base64Image);

      // Update on server in background
      final updateData = {'avatar': base64Image};
      final updatedProfile = await _ProfileBackgroundProcessor.updateProfileInBackground(
        updateData: updateData,
      );

      if (updatedProfile != null) {
        _log('Profile image updated successfully');
        _showSuccessSnackBar('Profile image updated successfully');
      } else {
        // Revert optimistic update on failure
        final originalProfile = _ProfileCacheManager.getCachedProfile();
        if (originalProfile != null) {
          _userProfileNotifier.value = originalProfile;
        }
        _showErrorSnackBar('Failed to update profile image');
      }

    } catch (e) {
      _log('Error updating profile image: $e');
      _showErrorSnackBar('Error updating profile image: ${e.toString()}');

      // Revert optimistic update
      final originalProfile = _ProfileCacheManager.getCachedProfile();
      if (originalProfile != null) {
        _userProfileNotifier.value = originalProfile;
      }
    } finally {
      if (!_disposed) {
        _isUpdatingImageNotifier.value = false;
      }
    }
  }

  // Optimized Profile Refresh
  Future<void> _refreshProfileOptimized() async {
    try {
      final refreshedProfile = await AuthService.refreshUserData();
      if (refreshedProfile != null && !_disposed) {
        _ProfileCacheManager.cacheProfile(refreshedProfile);
        _userProfileNotifier.value = refreshedProfile;
      }
    } catch (e) {
      _log('Error refreshing profile: $e');
    }
  }

  // Optimized Logout
  void _handleLogoutOptimized() async {
    _showLoadingDialog('Logging out...');

    try {
      // Clear cache immediately for instant feedback
      _ProfileCacheManager.clearCache();

      // Parallel logout operations
      final logoutFuture = AuthService.logout();
      final clearTokensFuture = TokenService.clearAll();

      await Future.wait([logoutFuture, clearTokensFuture]);

      _navigateToLogin();
    } catch (e) {
      _log('Logout error: $e');
      // Force logout even on error
      await TokenService.clearAll();
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    if (!_disposed && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
      );
    }
  }

  // Optimized Image Viewer
  void _viewProfileImageOptimized() {
    final profile = _userProfileNotifier.value;
    final avatar = profile?['avatar'];

    if (avatar == null || avatar.toString().isEmpty) return;

    // Use cached URL if available
    String imageUrl = _ProfileCacheManager.getCachedAvatarUrl() ??
        ImageService.getImageUrl(avatar);

    if (imageUrl.isEmpty) return;

    // Cache the URL for future use
    _ProfileCacheManager.cacheAvatarUrl(imageUrl);

    showDialog(
      context: context,
      builder: (BuildContext context) => _buildImageViewerDialog(imageUrl),
    );
  }

  Widget _buildImageViewerDialog(String imageUrl) {
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
                imageSource: imageUrl,
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
  }

  // Optimized Animation Start
  void _startAnimationsOptimized() {
    if (_disposed) return;

    // Start animations immediately without delay
    _fadeController.forward();
    _slideController.forward();
  }

  // Optimized Getters with Null Safety
  String get userName => _userProfileNotifier.value?['name'] ?? 'User';
  String get userEmail => _userProfileNotifier.value?['email'] ?? '';
  String get userPhone => _userProfileNotifier.value?['phone'] ?? '';
  String get userId => _userProfileNotifier.value?['id']?.toString() ?? '';
  String get userRole => _userProfileNotifier.value?['role'] ?? 'customer';
  String? get userAvatar => _userProfileNotifier.value?['avatar'];

  @override
  void dispose() {
    _disposed = true;

    // Dispose controllers
    _fadeController.dispose();
    _slideController.dispose();

    // Dispose ValueNotifiers
    _userProfileNotifier.dispose();
    _isLoadingNotifier.dispose();
    _isUpdatingImageNotifier.dispose();
    _hasErrorNotifier.dispose();
    _errorMessageNotifier.dispose();

    super.dispose();
  }

  // Helper methods optimized
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return ValueListenableBuilder<bool>(
      valueListenable: _isLoadingNotifier,
      builder: (context, isLoading, _) {
        return Scaffold(
          backgroundColor: Colors.grey[50],
          body: isLoading
              ? _buildLoadingWidget()
              : _buildMainContent(),
        );
      },
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
            'Loading your profile...',
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

  Widget _buildMainContent() {
    return ValueListenableBuilder<bool>(
      valueListenable: _hasErrorNotifier,
      builder: (context, hasError, _) {
        if (hasError) {
          return _buildErrorWidget();
        }

        return ValueListenableBuilder<Map<String, dynamic>?>(
          valueListenable: _userProfileNotifier,
          builder: (context, userProfile, _) {
            if (userProfile == null) {
              return _buildNoDataWidget();
            }

            return _buildProfileContent();
          },
        );
      },
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
            'Unable to load profile',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<String>(
            valueListenable: _errorMessageNotifier,
            builder: (context, errorMessage, _) {
              return Text(
                errorMessage.isNotEmpty ? errorMessage : 'Please check your connection',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontFamily: GlobalStyle.fontFamily,
                ),
                textAlign: TextAlign.center,
              );
            },
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _loadUserProfileOptimized,
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
          Icon(Icons.account_circle_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text(
            'No profile data available',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _loadUserProfileOptimized,
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
      onRefresh: _refreshProfileOptimized,
      color: GlobalStyle.primaryColor,
      child: CustomScrollView(
        slivers: [
          _buildModernAppBar(),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPersonalInfoSection(),
                    const SizedBox(height: 32),
                    _buildLogoutButton(),
                    _buildAppVersionInfo(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 280,
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
                  userName,
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
        // Background Pattern (Simplified for performance)
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

        // Profile Content
        FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                _buildProfileImageOptimized(),
                const SizedBox(height: 20),
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                _buildRoleBadge(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileImageOptimized() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 130,
          height: 130,
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
          onTap: _viewProfileImageOptimized,
          child: Hero(
            tag: 'profileImage',
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipOval(
                child: _buildAvatarImage(),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: _buildCameraButton(),
        ),
      ],
    );
  }

  Widget _buildAvatarImage() {
    final avatar = userAvatar;

    if (avatar != null && avatar.isNotEmpty) {
      // Use cached URL if available
      final cachedUrl = _ProfileCacheManager.getCachedAvatarUrl();
      final imageUrl = cachedUrl ?? ImageService.getImageUrl(avatar);

      // Cache the URL for future use
      if (cachedUrl == null) {
        _ProfileCacheManager.cacheAvatarUrl(imageUrl);
      }

      return ImageService.displayImage(
        imageSource: imageUrl,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
        placeholder: Container(
          color: Colors.white,
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(GlobalStyle.primaryColor),
            ),
          ),
        ),
        errorWidget: Container(
          color: Colors.white,
          child: Icon(Icons.person, size: 60, color: GlobalStyle.primaryColor),
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: Icon(Icons.person, size: 60, color: GlobalStyle.primaryColor),
    );
  }

  Widget _buildCameraButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: _isUpdatingImageNotifier,
      builder: (context, isUpdating, _) {
        return GestureDetector(
          onTap: isUpdating ? null : _updateProfileImageOptimized,
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
            child: isUpdating
                ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(GlobalStyle.primaryColor),
              ),
            )
                : Icon(Icons.camera_alt, color: GlobalStyle.primaryColor, size: 22),
          ),
        );
      },
    );
  }

  Widget _buildRoleBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_user, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            userRole.toUpperCase(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          icon: Icons.person_pin,
          title: 'Personal Information',
          color: GlobalStyle.primaryColor,
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          children: [
            _buildInfoItem(
              icon: FontAwesomeIcons.idCard,
              title: 'User ID',
              value: userId,
              iconColor: Colors.blue[600]!,
            ),
            _buildDivider(),
            _buildInfoItem(
              icon: FontAwesomeIcons.userAlt,
              title: 'Full Name',
              value: userName,
              iconColor: Colors.green[600]!,
            ),
            _buildDivider(),
            _buildInfoItem(
              icon: FontAwesomeIcons.phone,
              title: 'Phone Number',
              value: userPhone.isNotEmpty ? userPhone : 'Not provided',
              iconColor: Colors.orange[600]!,
            ),
            _buildDivider(),
            _buildInfoItem(
              icon: FontAwesomeIcons.envelope,
              title: 'Email Address',
              value: userEmail,
              iconColor: Colors.purple[600]!,
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
          onTap: _handleLogoutOptimized,
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
            Image.asset(
              'assets/images/delpick_image.png',
              width: 80,
              height: 80,
              color: Colors.grey[400],
              colorBlendMode: BlendMode.modulate,
            ),
            const SizedBox(height: 12),
            Text(
              'DelPick v1.0.0',
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
  }) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
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
                  ),
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