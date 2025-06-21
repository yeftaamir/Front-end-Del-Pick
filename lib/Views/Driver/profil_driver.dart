import 'package:flutter/material.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:del_pick/Models/driver.dart';
import 'package:del_pick/Models/user.dart';
import 'package:del_pick/Services/auth_service.dart';
import 'package:del_pick/Services/core/token_service.dart';
import 'package:del_pick/Services/driver_service.dart';
import 'package:del_pick/Services/image_service.dart';
import '../Controls/login_page.dart';

class ProfileDriverPage extends StatefulWidget {
  static const String route = "/Driver/Profile";

  final Driver? driver;

  const ProfileDriverPage({
    super.key,
    this.driver,
  });

  factory ProfileDriverPage.sample() {
    return const ProfileDriverPage();
  }

  @override
  State<ProfileDriverPage> createState() => _ProfileDriverPageState();
}

class _ProfileDriverPageState extends State<ProfileDriverPage> with TickerProviderStateMixin {
  Driver? _driver;
  User? _user;
  bool _isLoading = true;
  String? _error;

  // Service data
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
    _loadDriverData();
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

  Future<void> _loadDriverData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print("=== Loading Driver Data with Service Implementation ===");

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

      // If passed driver data directly, use it
      if (widget.driver != null) {
        print("Using passed driver data");
        setState(() {
          _driver = widget.driver;
          _isLoading = false;
        });
        _fadeController.forward();
        _slideController.forward();
        return;
      }

      // 5. Try to get driver profile using DriverService
      Driver? driver;
      try {
        print("Fetching driver profile from DriverService...");
        final driverProfileData = await DriverService.getCurrentDriverProfile();

        if (driverProfileData.isNotEmpty) {
          driver = Driver.fromJson(driverProfileData);
          print("Driver profile loaded successfully from DriverService");
          print("Driver Name: ${driver.name}");
          print("Driver Status: ${driver.status}");
          print("Vehicle Plate: ${driver.vehiclePlate}");
        } else {
          print("DriverService.getCurrentDriverProfile() returned empty data");
        }
      } catch (e) {
        print("Error fetching driver profile from DriverService: $e");
      }

      // Fallback 1: Get profile using AuthService.getProfile()
      if (driver == null) {
        try {
          print("Fallback 1: Fetching profile from AuthService.getProfile()...");
          final profileData = await AuthService.getProfile();

          if (profileData.isNotEmpty) {
            // Check if profile contains driver data
            if (profileData.containsKey('driver') && profileData['driver'] != null) {
              driver = Driver.fromJson(profileData['driver']);
              print("Driver profile loaded from AuthService profile data");
            } else {
              // Create driver from user data with defaults
              _user = User.fromJson(profileData);
              driver = Driver(
                id: int.tryParse(_userId ?? '0') ?? 0,
                userId: _user!.id,
                licenseNumber: 'DRV-${_user!.id.toString().padLeft(6, '0')}',
                vehiclePlate: 'B 1234 ABC', // Default plate
                status: 'active',
                rating: 5.0,
                reviewsCount: 0,
                user: _user,
              );
              print("Created driver from user profile data");
            }
          } else {
            print("AuthService.getProfile() returned empty data");
          }
        } catch (e) {
          print("Error fetching profile from AuthService: $e");
        }
      }

      // Fallback 2: Try to get cached user data
      if (driver == null) {
        try {
          print("Fallback 2: Getting cached user data...");
          final userData = await AuthService.getUserData();

          if (userData != null) {
            if (userData.containsKey('driver') && userData['driver'] != null) {
              driver = Driver.fromJson(userData['driver']);
              print("Driver loaded from cached user data");
            } else {
              // Create driver from cached user data
              _user = User.fromJson(userData);
              driver = Driver(
                id: int.tryParse(_userId ?? '0') ?? 0,
                userId: _user!.id,
                licenseNumber: 'DRV-${_user!.id.toString().padLeft(6, '0')}',
                vehiclePlate: 'B 1234 ABC',
                status: 'active',
                rating: 5.0,
                reviewsCount: 0,
                user: _user,
              );
              print("Created driver from cached user data");
            }
          } else {
            print("No cached user data available");
          }
        } catch (e) {
          print("Error loading cached user data: $e");
        }
      }

      // Final fallback: Create empty driver with TokenService data
      if (driver == null) {
        print("All driver loading methods failed, creating empty driver");
        driver = Driver.empty();
        driver = driver.copyWith(
          id: int.tryParse(_userId ?? '0') ?? 0,
          userId: int.tryParse(_userId ?? '0') ?? 0,
          user: User(
            id: int.tryParse(_userId ?? '0') ?? 0,
            name: 'Driver User',
            email: 'driver@example.com',
            role: _userRole ?? 'driver',
          ),
        );
      }

      // Verify that token service data matches driver data
      print("\n=== Data Verification ===");
      print("TokenService User ID: $_userId");
      print("Driver User ID: ${driver.userId}");
      print("TokenService Role: $_userRole");
      print("Driver User Role: ${driver.user?.role}");

      // Update driver with TokenService data if there's mismatch
      if (_userId != null && driver.userId.toString() != _userId) {
        print("User ID mismatch detected, updating with TokenService data");
        driver = driver.copyWith(userId: int.tryParse(_userId!) ?? driver.userId);
      }

      if (_userRole != null && driver.user?.role != _userRole) {
        print("Role mismatch detected, updating user data with TokenService data");
        if (driver.user != null) {
          final updatedUser = driver.user!.copyWith(role: _userRole!);
          driver = driver.copyWith(user: updatedUser);
        }
      }

      if (mounted) {
        setState(() {
          _driver = driver;
        });
        _fadeController.forward();
        _slideController.forward();

        print("=== Driver Profile Loading Complete ===");
        print("Final Driver Name: ${_driver!.name}");
        print("Final Driver Status: ${_driver!.status}");
        print("Final Driver Vehicle: ${_driver!.vehiclePlate}");
        print("Final Driver Rating: ${_driver!.rating}");
        print("Has Profile Image: ${_driver!.profileImageUrl != null}");
      }
    } catch (e) {
      print('Error loading driver data: $e');
      if (mounted) {
        setState(() {
          _error = "Gagal memuat data: $e";
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
      print("=== Starting Driver Logout Process ===");

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

      print("=== Driver Logout Verification ===");
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

      print("=== Driver Logout Process Complete ===");
    } catch (e) {
      print('Driver logout error: $e');

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
    if (_driver?.profileImageUrl == null || _driver!.profileImageUrl!.isEmpty) {
      return;
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
                    imageSource: ImageService.getImageUrl(_driver!.profileImageUrl!),
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
      print("\n=== DEBUG: Current Driver Service Data ===");

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
        print("Has Driver Data: ${userData['driver'] != null}");
      }

      print("Current Driver Name: ${_driver?.name}");
      print("Current Driver Status: ${_driver?.status}");
      print("Current Driver Vehicle: ${_driver?.vehiclePlate}");

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
          : _error != null
          ? _buildErrorView()
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
                        _driver?.name ?? 'Driver',
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
                                      onTap: _driver?.profileImageUrl != null
                                          ? _viewProfileImage
                                          : null,
                                      child: Hero(
                                        tag: 'driverProfileImage',
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
                                            child: _driver?.profileImageUrl != null &&
                                                _driver!.profileImageUrl!.isNotEmpty
                                                ? ImageService.displayImage(
                                              imageSource: ImageService.getImageUrl(
                                                _driver!.profileImageUrl!,
                                              ),
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
                                    // Rating Badge
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.amber[600]!,
                                              Colors.amber[800]!,
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
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.star,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              '${_driver?.rating ?? 0}',
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
                                ),
                                const SizedBox(height: 20),
                                // Name
                                Text(
                                  _driver?.name ?? 'Driver Name',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Role and Status Badge
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
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
                                            Icons.directions_car,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'DRIVER',
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
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(_driver?.status)
                                            .withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _getStatusText(_driver?.status),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
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
                          icon: FontAwesomeIcons.user,
                          title: 'Driver Name',
                          value: _driver?.name ?? '-',
                          iconColor: Colors.blue[600]!,
                        ),
                        _buildDivider(),
                        _buildInfoItem(
                          icon: FontAwesomeIcons.phone,
                          title: 'Phone Number',
                          value: _driver?.phoneNumber ?? '-',
                          iconColor: Colors.green[600]!,
                        ),
                        _buildDivider(),
                        _buildInfoItem(
                          icon: FontAwesomeIcons.envelope,
                          title: 'Email Address',
                          value: _driver?.email ?? '-',
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

                    // Vehicle Information Section
                    _buildSectionHeader(
                      icon: Icons.directions_car,
                      title: 'Vehicle Information',
                      color: Colors.orange[700]!,
                    ),
                    const SizedBox(height: 16),
                    _buildInfoCard(
                      children: [
                        _buildInfoItem(
                          icon: FontAwesomeIcons.car,
                          title: 'Vehicle Number',
                          value: _driver?.vehiclePlate ?? '-',
                          iconColor: Colors.orange[600]!,
                        ),
                        _buildDivider(),
                        _buildInfoItem(
                          icon: FontAwesomeIcons.idCard,
                          title: 'License Number',
                          value: _driver?.licenseNumber ?? '-',
                          iconColor: Colors.blue[600]!,
                        ),
                        _buildDivider(),
                        _buildInfoItem(
                          icon: FontAwesomeIcons.circleCheck,
                          title: 'Driver Status',
                          value: _getStatusText(_driver?.status),
                          iconColor: _getStatusColor(_driver?.status),
                        ),
                        _buildDivider(),
                        _buildInfoItem(
                          icon: FontAwesomeIcons.star,
                          title: 'Rating',
                          value: '${_driver?.rating ?? 0}/5.0 (${_driver?.reviewsCount ?? 0} reviews)',
                          iconColor: Colors.amber[600]!,
                        ),
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

  Widget _buildErrorView() {
    return Center(
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
            _error ?? 'Please check your connection',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontFamily: GlobalStyle.fontFamily,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _loadDriverData,
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

  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return 'Active';
      case 'inactive':
        return 'Inactive';
      case 'busy':
        return 'Busy';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
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
}