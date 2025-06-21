import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;

import '../../Models/user.dart';
import '../../Services/auth_service.dart';
import '../../Services/core/token_service.dart';
import '../../Services/image_service.dart';
import '../../Services/user_service.dart';
import '../Controls/login_page.dart';

class ProfilePage extends StatefulWidget {
  static const String route = "/Customers/Profile";

  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with TickerProviderStateMixin {
  User? _customer;
  bool _isLoading = true;
  bool _isUpdatingImage = false;
  bool _hasError = false;
  String _errorMessage = '';
  String? _processedImageUrl;

  // Additional data from TokenService
  String? _authToken;
  String? _userRole;
  String? _userId;
  bool _isAuthenticated = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserData();
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

  Future<void> _loadUserData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
      _processedImageUrl = null;
    });

    try {
      print("=== Loading User Data with Service Implementation ===");

      // 1. Get Token
      _authToken = await TokenService.getToken();
      print("Auth Token: ${_authToken != null ? 'Present (${_authToken!.substring(0, 20)}...)' : 'Not found'}");

      // 2. Get User Role
      _userRole = await TokenService.getUserRole();
      print("User Role: ${_userRole ?? 'Not found'}");

      // 3. Get User ID
      _userId = await TokenService.getUserId();
      print("User ID: ${_userId ?? 'Not found'}");

      // 4. Check Authentication Status
      _isAuthenticated = await TokenService.isAuthenticated();
      print("Is Authenticated: $_isAuthenticated");

      // If not authenticated, redirect to login
      if (!_isAuthenticated || _authToken == null) {
        print("User not authenticated, redirecting to login");
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
              (route) => false,
        );
        return;
      }

      // 5. Get Profile Data using AuthService.getProfile()
      User? customer;
      try {
        print("Fetching profile from AuthService.getProfile()...");
        final profileData = await AuthService.getProfile();

        if (profileData.isNotEmpty) {
          customer = User.fromJson(profileData);
          print("Profile loaded successfully from AuthService");
          print("User Name: ${customer.name}");
          print("User Email: ${customer.email}");
          print("User Role: ${customer.role}");
        } else {
          print("AuthService.getProfile() returned empty data");
        }
      } catch (e) {
        print("Error fetching profile from AuthService: $e");
      }

      // Fallback: Try to get cached user data if profile fetch failed
      if (customer == null) {
        try {
          print("Trying fallback: getting cached user data...");
          final userData = await AuthService.getUserData();

          if (userData != null) {
            customer = User.fromJson(userData);
            print("Profile loaded from cached user data");
          } else {
            print("No cached user data available");
          }
        } catch (e) {
          print("Error loading cached user data: $e");
        }
      }

      // Final fallback: Try UserService if available
      if (customer == null) {
        try {
          print("Trying UserService.getProfile() as final fallback...");
          final userProfileData = await UserService.getProfile();

          if (userProfileData.isNotEmpty) {
            customer = User.fromJson(userProfileData);
            print("Profile loaded from UserService");
          }
        } catch (e) {
          print("UserService fallback failed: $e");
        }
      }

      // If all methods failed, create empty user but don't redirect
      if (customer == null) {
        print("All profile loading methods failed, using empty user");
        customer = User.empty();
        customer = customer.copyWith(
          id: int.tryParse(_userId ?? '0') ?? 0,
          role: _userRole ?? 'customer',
          name: 'User',
          email: 'user@example.com',
        );
      }

      // Verify that token service data matches profile data
      print("\n=== Data Verification ===");
      print("TokenService User ID: $_userId");
      print("Profile User ID: ${customer.id}");
      print("TokenService Role: $_userRole");
      print("Profile Role: ${customer.role}");

      // Update customer with TokenService data if there's mismatch
      if (_userId != null && customer.id.toString() != _userId) {
        print("ID mismatch detected, updating with TokenService data");
        customer = customer.copyWith(id: int.tryParse(_userId!) ?? customer.id);
      }

      if (_userRole != null && customer.role != _userRole) {
        print("Role mismatch detected, updating with TokenService data");
        customer = customer.copyWith(role: _userRole!);
      }

      // Process image URL if available
      String? imageUrl;
      if (customer.avatar != null && customer.avatar!.isNotEmpty) {
        print('Processing avatar: ${customer.avatar}');

        if (customer.avatar!.startsWith('data:image/')) {
          print('Avatar is in data URL format');
          imageUrl = customer.avatar;
        } else if (_isBase64String(customer.avatar!)) {
          print('Avatar appears to be a raw base64 string');
          String formattedBase64 = 'data:image/jpeg;base64,${customer.avatar}';
          imageUrl = formattedBase64;
        } else {
          print('Avatar is a server path or URL');
          imageUrl = ImageService.getImageUrl(customer.avatar!);
          print('Processed image URL: $imageUrl');
        }
      } else {
        print('No avatar found for customer');
      }

      if (mounted) {
        setState(() {
          _customer = customer;
          _processedImageUrl = imageUrl;
        });
        _fadeController.forward();
        _slideController.forward();

        print("=== Profile Loading Complete ===");
        print("Final Customer Name: ${_customer!.name}");
        print("Final Customer Email: ${_customer!.email}");
        print("Final Customer Role: ${_customer!.role}");
        print("Final Customer ID: ${_customer!.id}");
        print("Has Avatar: ${_processedImageUrl != null}");
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _customer = User.empty();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load user data: $_errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _isBase64String(String str) {
    try {
      if (str.length % 4 != 0 || str.contains(RegExp(r'[^A-Za-z0-9+/=]'))) {
        return false;
      }
      base64Decode(str);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _updateProfileImage() async {
    if (_customer == null) return;

    setState(() {
      _isUpdatingImage = true;
    });

    try {
      final imageFile = await ImageService.pickImage();
      if (imageFile == null) {
        setState(() {
          _isUpdatingImage = false;
        });
        return;
      }

      // Convert image to base64
      final base64Image = await ImageService.imageToBase64(imageFile);
      if (base64Image == null) {
        throw Exception('Failed to convert image to base64');
      }

      // Update profile using AuthService
      final updatedProfile = await AuthService.updateProfile({
        'avatar': base64Image,
      });

      if (updatedProfile.isNotEmpty) {
        await _loadUserData(); // Reload data to get updated image

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile image updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to update profile image');
      }
    } catch (e) {
      print('Error updating profile image: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingImage = false;
        });
      }
    }
  }

  // Updated logout implementation using proper service methods
  void _handleLogout() async {
    // Show loading dialog
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
                  valueColor: AlwaysStoppedAnimation<Color>(
                    GlobalStyle.primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Logging out...',
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

    try {
      print("=== Starting Logout Process ===");

      // 1. Call AuthService.logout() first (this may call server-side logout)
      try {
        print("Calling AuthService.logout()...");
        final logoutResult = await AuthService.logout();
        print("AuthService.logout() completed: $logoutResult");
      } catch (e) {
        print("AuthService.logout() failed (continuing with local cleanup): $e");
        // Continue with local cleanup even if server logout fails
      }

      // 2. Clear all local data using TokenService.clearAll()
      print("Clearing all local data with TokenService.clearAll()...");
      await TokenService.clearAll();
      print("All local data cleared successfully");

      // 3. Verify data is cleared
      final verifyToken = await TokenService.getToken();
      final verifyRole = await TokenService.getUserRole();
      final verifyUserId = await TokenService.getUserId();
      final verifyAuth = await TokenService.isAuthenticated();

      print("=== Logout Verification ===");
      print("Token after clear: ${verifyToken ?? 'null (✓)'}");
      print("Role after clear: ${verifyRole ?? 'null (✓)'}");
      print("User ID after clear: ${verifyUserId ?? 'null (✓)'}");
      print("Is authenticated after clear: $verifyAuth (should be false)");

      // Navigate to login page
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
      );

      print("=== Logout Process Complete ===");
    } catch (e) {
      print('Logout error: $e');

      // Even if logout fails, try to clear local data and navigate
      try {
        await TokenService.clearAll();
        print("Force cleared local data after logout error");
      } catch (clearError) {
        print("Force clear also failed: $clearError");
      }

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
      );
    }
  }

  void _viewProfileImage() {
    if (_processedImageUrl == null || _processedImageUrl!.isEmpty) {
      if (_customer == null || _customer!.avatar == null || _customer!.avatar!.isEmpty) {
        return;
      }
      _processedImageUrl = ImageService.getImageUrl(_customer!.avatar!);
      if (_processedImageUrl!.isEmpty) {
        return;
      }
    }

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
                    imageSource: _processedImageUrl!,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.contain,
                    placeholder: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    ),
                    errorWidget: Container(
                      color: Colors.grey[900],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.broken_image,
                            size: 80,
                            color: Colors.white54,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load image',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 16,
                            ),
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
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Debug method untuk check service data
  Future<void> _debugCheckServiceData() async {
    try {
      print("\n=== DEBUG: Current Service Data ===");

      final token = await TokenService.getToken();
      final role = await TokenService.getUserRole();
      final userId = await TokenService.getUserId();
      final isAuth = await TokenService.isAuthenticated();
      final userData = await AuthService.getUserData();

      print("Token: ${token != null ? 'Present' : 'Not found'}");
      print("Role: ${role ?? 'Not found'}");
      print("User ID: ${userId ?? 'Not found'}");
      print("Is Authenticated: $isAuth");
      print("Cached User Data: ${userData != null ? 'Present' : 'Not found'}");

      if (userData != null) {
        print("Cached User Name: ${userData['name']}");
        print("Cached User Email: ${userData['email']}");
      }

      print("=== END DEBUG ===\n");

      // Show in UI
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Debug info logged to console'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      print("Debug check error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                GlobalStyle.primaryColor,
              ),
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
      )
          : _customer == null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red[400],
            ),
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
              'Please check your connection',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _loadUserData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: GlobalStyle.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      )
          : CustomScrollView(
        slivers: [
          // Modern App Bar with Gradient
          SliverAppBar(
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
                        _customer!.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    background: Stack(
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
                                // Profile Image
                                Stack(
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
                                        tag: 'profileImage',
                                        child: Container(
                                          width: 120,
                                          height: 120,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 3,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.2),
                                                blurRadius: 15,
                                                offset: const Offset(0, 5),
                                              ),
                                            ],
                                          ),
                                          child: ClipOval(
                                            child: _processedImageUrl != null &&
                                                _processedImageUrl!.isNotEmpty
                                                ? ImageService.displayImage(
                                              imageSource: _processedImageUrl!,
                                              width: 120,
                                              height: 120,
                                              fit: BoxFit.cover,
                                              placeholder: Container(
                                                color: Colors.white,
                                                child: Center(
                                                  child: CircularProgressIndicator(
                                                    valueColor:
                                                    AlwaysStoppedAnimation<Color>(
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
                                              colors: [
                                                Colors.white,
                                                Colors.grey[100]!,
                                              ],
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
                                  ],
                                ),
                                const SizedBox(height: 20),
                                // Name
                                Text(
                                  _customer!.name,
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Role Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.verified_user,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _customer!.role.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 1.2,
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
                    ),
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
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            // Debug button for development
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.info_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: _debugCheckServiceData,
                ),
              ),
            ],
          ),

          // Profile Content
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Personal Information Section
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
                          value: _customer!.id.toString(),
                          iconColor: Colors.blue[600]!,
                        ),
                        _buildDivider(),
                        _buildInfoItem(
                          icon: FontAwesomeIcons.userAlt,
                          title: 'Full Name',
                          value: _customer!.name,
                          iconColor: Colors.green[600]!,
                        ),
                        _buildDivider(),
                        _buildInfoItem(
                          icon: FontAwesomeIcons.phone,
                          title: 'Phone Number',
                          value: _customer!.phone ?? 'Not provided',
                          iconColor: Colors.orange[600]!,
                        ),
                        _buildDivider(),
                        _buildInfoItem(
                          icon: FontAwesomeIcons.envelope,
                          title: 'Email Address',
                          value: _customer!.email,
                          iconColor: Colors.purple[600]!,
                        ),
                        // Additional Service Info
                        if (_userRole != null) ...[
                          _buildDivider(),
                          _buildInfoItem(
                            icon: FontAwesomeIcons.userTag,
                            title: 'Account Role',
                            value: _userRole!,
                            iconColor: Colors.indigo[600]!,
                          ),
                        ],
                        if (_isAuthenticated) ...[
                          _buildDivider(),
                          _buildInfoItem(
                            icon: FontAwesomeIcons.checkCircle,
                            title: 'Authentication Status',
                            value: 'Authenticated',
                            iconColor: Colors.green[600]!,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Logout Button
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.red[400]!,
                            Colors.red[600]!,
                          ],
                        ),
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
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.logout,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                const Text(
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
                    ),

                    // App Version
                    Center(
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
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      // Add debug floating action button (only in development)
      floatingActionButton: FloatingActionButton.small(
        onPressed: _debugCheckServiceData,
        backgroundColor: GlobalStyle.primaryColor,
        child: const Icon(Icons.bug_report, color: Colors.white),
        tooltip: 'Debug Service Data',
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
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
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
            child: FaIcon(
              icon,
              size: 20,
              color: iconColor,
            ),
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