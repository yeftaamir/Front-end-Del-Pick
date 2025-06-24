import 'package:flutter/material.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';

// Import proper services based on project architecture
import '../../Services/auth_service.dart';
import '../../Services/driver_service.dart';
import '../../Services/user_service.dart';
import '../../Services/image_service.dart';
import '../../Services/Core/token_service.dart';
import '../Controls/login_page.dart';

class ProfileDriverPage extends StatefulWidget {
  static const String route = "/Driver/Profile";

  const ProfileDriverPage({super.key});

  @override
  State<ProfileDriverPage> createState() => _ProfileDriverPageState();
}

class _ProfileDriverPageState extends State<ProfileDriverPage> with TickerProviderStateMixin {
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _driverData;
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
    _loadDriverProfile();
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

  /// Load driver profile using AuthService.getProfile()
  Future<void> _loadDriverProfile() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      // Check authentication first
      final isAuthenticated = await AuthService.isAuthenticated();
      if (!isAuthenticated) {
        _navigateToLogin();
        return;
      }

      // Get profile using AuthService (this should return role-specific data)
      final profileData = await AuthService.getProfile();

      if (profileData != null && profileData.isNotEmpty) {
        // For driver, the structure should be different - check for driver data
        if (profileData.containsKey('driver') || _safeToString(profileData['role']).toLowerCase() == 'driver') {
          if (mounted) {
            setState(() {
              _userProfile = profileData;
              _driverData = profileData['driver'] ?? profileData;
            });
            _fadeController.forward();
            _slideController.forward();
          }
        } else {
          throw Exception('Driver profile data not found');
        }
      } else {
        throw Exception('Profile data is empty');
      }
    } catch (e) {
      print('Error loading driver profile: $e');

      // Try to get cached user data as fallback
      try {
        final cachedData = await AuthService.getUserData();
        if (cachedData != null) {
          // Check if cached data has driver info
          if (cachedData.containsKey('driver') || _safeToString(cachedData['user']?['role']).toLowerCase() == 'driver') {
            if (mounted) {
              setState(() {
                _userProfile = cachedData['user'] ?? cachedData;
                _driverData = cachedData['driver'] ?? cachedData;
              });
              _fadeController.forward();
              _slideController.forward();
            }
          } else {
            throw Exception('No cached driver data available');
          }
        } else {
          throw Exception('No cached profile data available');
        }
      } catch (fallbackError) {
        print('Fallback also failed: $fallbackError');
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = e.toString();
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Update profile image using ImageService and AuthService
  Future<void> _updateProfileImage() async {
    if (_userProfile == null) return;

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

      // Update profile using AuthService
      final updateData = {
        'avatar': base64Image,
      };

      final updatedProfile = await AuthService.updateProfile(
        updateData: updateData,
      );

      if (updatedProfile.isNotEmpty) {
        // Reload profile to get updated data
        await _loadDriverProfile();

        if (!mounted) return;
        _showSuccessSnackBar('Profile image updated successfully');
      } else {
        _showErrorSnackBar('Failed to update profile image');
      }
    } catch (e) {
      print('Error updating profile image: $e');
      _showErrorSnackBar('Error updating profile image: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingImage = false;
        });
      }
    }
  }

  /// Update driver status using DriverService
  Future<void> _updateDriverStatus(String newStatus) async {
    if (_driverData == null) return;

    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      final driverId = _safeToString(_driverData!['id']);
      if (driverId.isEmpty) {
        throw Exception('Driver ID not found');
      }

      // Update status using DriverService
      final result = await DriverService.updateDriverStatus(
        driverId: driverId,
        status: newStatus,
      );

      if (result.isNotEmpty) {
        // Reload profile to get updated data
        await _loadDriverProfile();

        if (!mounted) return;
        _showSuccessSnackBar('Driver status updated to ${_getStatusText(newStatus)}');
      } else {
        _showErrorSnackBar('Failed to update driver status');
      }
    } catch (e) {
      print('Error updating driver status: $e');
      _showErrorSnackBar('Error updating status: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
  }

  /// Refresh profile data
  Future<void> _refreshProfile() async {
    try {
      final refreshedProfile = await AuthService.refreshUserData();
      if (refreshedProfile != null && mounted) {
        setState(() {
          _userProfile = refreshedProfile;
          _driverData = refreshedProfile['driver'] ?? refreshedProfile;
        });
      }
    } catch (e) {
      print('Error refreshing profile: $e');
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

  /// View profile image in full screen
  void _viewProfileImage() {
    final avatar = _userProfile?['avatar'];
    if (avatar == null || _safeToString(avatar).isEmpty) return;

    final imageUrl = ImageService.getImageUrl(_safeToString(avatar));
    if (imageUrl.isEmpty) return;

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
      },
    );
  }

  /// Show status update dialog
  void _showStatusUpdateDialog() {
    final currentStatus = _safeToString(_driverData?['status']).isNotEmpty
        ? _safeToString(_driverData?['status'])
        : 'inactive';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Update Driver Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusOption('active', 'Active - Available for deliveries', currentStatus),
              _buildStatusOption('inactive', 'Inactive - Not available', currentStatus),
              _buildStatusOption('busy', 'Busy - Currently on delivery', currentStatus),
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
        _updateDriverStatus(status);
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
      : 'Driver';
  String get userEmail => _safeToString(_userProfile?['email']);
  String get userPhone => _safeToString(_userProfile?['phone']);
  String get userId => _safeToString(_userProfile?['id']);
  String? get userAvatar => _userProfile?['avatar'];

  // Safe getters for driver data
  String get driverStatus => _safeToString(_driverData?['status']).isNotEmpty
      ? _safeToString(_driverData?['status'])
      : 'inactive';
  double get driverRating => _safeToDouble(_driverData?['rating']);
  int get reviewsCount => _safeToInt(_driverData?['reviews_count']);
  String get licenseNumber => _safeToString(_driverData?['license_number']);
  String get vehiclePlate => _safeToString(_driverData?['vehicle_plate']);

  String _getStatusText(String? status) {
    switch (_safeToString(status).toLowerCase()) {
      case 'active':
        return 'Available';
      case 'inactive':
        return 'Offline';
      case 'busy':
        return 'On Delivery';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor(String? status) {
    switch (_safeToString(status).toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.red;
      case 'busy':
        return Colors.orange;
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
            onPressed: _loadDriverProfile,
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
            'No driver profile data available',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _loadDriverProfile,
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

        // Profile Content
        FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                _buildProfileImage(),
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
                _buildRoleAndStatusBadges(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileImage() {
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
          onTap: _viewProfileImage,
          child: Hero(
            tag: 'driverProfileImage',
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
                child: userAvatar != null && _safeToString(userAvatar).isNotEmpty
                    ? ImageService.displayImage(
                  imageSource: _safeToString(userAvatar),
                  width: 120,
                  height: 120,
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
                      Icons.person,
                      size: 60,
                      color: GlobalStyle.primaryColor,
                    ),
                  ),
                )
                    : Container(
                  color: Colors.white,
                  child: Icon(
                    Icons.person,
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
            onTap: _isUpdatingImage ? null : _updateProfileImage,
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
        if (driverRating > 0)
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber[600]!, Colors.amber[800]!],
                ),
                borderRadius: BorderRadius.circular(12),
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
                  const Icon(Icons.star, color: Colors.white, size: 14),
                  const SizedBox(width: 2),
                  Text(
                    driverRating.toStringAsFixed(1),
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
              Icon(Icons.directions_car, color: Colors.white, size: 16),
              SizedBox(width: 6),
              Text(
                'DRIVER',
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
              color: _getStatusColor(driverStatus).withOpacity(0.2),
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
                  _getStatusText(driverStatus),
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
              _buildPersonalInfoSection(),
              const SizedBox(height: 32),
              _buildDriverInfoSection(),
              const SizedBox(height: 32),
              _buildLogoutButton(),
              _buildAppVersionInfo(),
            ],
          ),
        ),
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
              icon: FontAwesomeIcons.user,
              title: 'Driver Name',
              value: userName,
              iconColor: Colors.blue[600]!,
            ),
            _buildDivider(),
            _buildInfoItem(
              icon: FontAwesomeIcons.phone,
              title: 'Phone Number',
              value: userPhone.isNotEmpty ? userPhone : 'Not provided',
              iconColor: Colors.green[600]!,
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

  Widget _buildDriverInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          icon: Icons.directions_car,
          title: 'Driver Information',
          color: Colors.orange[700]!,
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          children: [
            _buildInfoItem(
              icon: FontAwesomeIcons.idCard,
              title: 'License Number',
              value: licenseNumber.isNotEmpty ? licenseNumber : 'Not provided',
              iconColor: Colors.blue[600]!,
            ),
            _buildDivider(),
            _buildInfoItem(
              icon: FontAwesomeIcons.car,
              title: 'Vehicle Plate',
              value: vehiclePlate.isNotEmpty ? vehiclePlate : 'Not provided',
              iconColor: Colors.orange[600]!,
            ),
            _buildDivider(),
            _buildInfoItem(
              icon: FontAwesomeIcons.star,
              title: 'Rating',
              value: driverRating > 0 ? '${driverRating.toStringAsFixed(1)} ($reviewsCount reviews)' : 'No ratings yet',
              iconColor: Colors.amber[600]!,
            ),
            _buildDivider(),
            _buildInfoItem(
              icon: FontAwesomeIcons.circleCheck,
              title: 'Current Status',
              value: _getStatusText(driverStatus),
              iconColor: _getStatusColor(driverStatus),
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
                Icons.delivery_dining,
                size: 40,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'DelPick Driver v1.0.0',
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