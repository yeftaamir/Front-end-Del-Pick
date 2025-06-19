// lib/pages/customers/profile_page.dart
import 'package:del_pick/Models/Extensions/menu_item_extensions.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// Import common
import '../../../Common/global_style.dart';
import '../../../Models/Entities/user.dart';
import '../../../Models/Exceptions/api_exception.dart';
import '../../../Services/User/profile_service.dart';
import '../../../Services/Utils/error_handler.dart';

// Import models and services
import '../../LogApp/login_page.dart';

// Import local services and widgets
import 'widgets/profile_widgets.dart';

class ProfilePage extends StatefulWidget {
  static const String route = "/Customers/Profile";

  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with TickerProviderStateMixin {
  // State variables
  User? _user;
  bool _isLoading = true;
  bool _isUpdatingImage = false;
  String? _errorMessage;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // Initialize animations
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

  // Load user profile data
  Future<void> _loadUserProfile() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await ProfileService.getUserProfile();

      if (mounted) {
        setState(() {
          _user = user;
          _isLoading = false;
        });

        // Start animations
        _fadeController.forward();
        _slideController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = ErrorHandler.handleError(e);
        });

        // If unauthorized, redirect to login
        if (e is UnauthorizedException) {
          _redirectToLogin();
        }
      }
    }
  }

  // Handle logout
  Future<void> _handleLogout() async {
    ProfileWidgets.showLoadingDialog(context, 'Logging out...');

    try {
      await ProfileService.handleLogout();

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        _redirectToLogin();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ProfileWidgets.showErrorMessage(
          context,
          'Logout failed: ${ErrorHandler.handleError(e)}',
        );

        // Still redirect to login even if logout failed
        _redirectToLogin();
      }
    }
  }

  // Redirect to login page
  void _redirectToLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
    );
  }

  // Update profile image (placeholder - implement image picker if needed)
  Future<void> _updateProfileImage() async {
    if (_user == null) return;

    setState(() {
      _isUpdatingImage = true;
    });

    try {
      // Placeholder - implement image picker and upload logic
      // For now, just show a message
      ProfileWidgets.showErrorMessage(
        context,
        'Image upload feature not implemented yet',
      );

      // Example implementation:
      // final success = await ProfileService.updateProfileImage(base64Image);
      // if (success) {
      //   await _loadUserProfile();
      //   ProfileWidgets.showSuccessMessage(context, 'Profile image updated successfully');
      // }
    } catch (e) {
      ProfileWidgets.showErrorMessage(
        context,
        'Failed to update profile image: ${ErrorHandler.handleError(e)}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingImage = false;
        });
      }
    }
  }

  // View profile image in full screen
  void _viewProfileImage() {
    if (_user?.avatar == null || _user!.avatar!.isEmpty) {
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
                  child: Image.network(
                    _user!.avatar!,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
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
                      );
                    },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _buildBody(),
    );
  }

  // Build main body content
  Widget _buildBody() {
    if (_isLoading) {
      return ProfileWidgets.buildLoadingState();
    }

    if (_errorMessage != null) {
      return ProfileWidgets.buildErrorState(
        message: _errorMessage!,
        onRetry: _loadUserProfile,
      );
    }

    if (_user == null) {
      return ProfileWidgets.buildErrorState(
        message: 'User data not available',
        onRetry: _loadUserProfile,
      );
    }

    return CustomScrollView(
      slivers: [
        _buildAppBar(),
        _buildProfileContent(),
      ],
    );
  }

  // Build app bar with profile header
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

          return FlexibleSpaceBar(
            title: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isCollapsed ? 1.0 : 0.0,
              child: Text(
                _user!.displayName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            background: ProfileWidgets.buildProfileHeader(
              user: _user!,
              imageUrl: _user!.avatar,
              isUpdatingImage: _isUpdatingImage,
              onImageTap: _viewProfileImage,
              onUpdateImage: _updateProfileImage,
              fadeAnimation: _fadeAnimation,
              slideAnimation: _slideAnimation,
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

  // Build profile content section
  Widget _buildProfileContent() {
    final userInfo = ProfileService.getUserDisplayInfo(_user!);

    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Personal Information Section
              ProfileWidgets.buildSectionHeader(
                icon: Icons.person_pin,
                title: 'Personal Information',
                color: GlobalStyle.primaryColor,
              ),
              const SizedBox(height: 16),

              // User Info Card
              ProfileWidgets.buildInfoCard(
                children: [
                  ProfileWidgets.buildInfoItem(
                    icon: FontAwesomeIcons.idCard,
                    title: 'User ID',
                    value: userInfo['id']!,
                    iconColor: Colors.blue[600]!,
                  ),
                  ProfileWidgets.buildDivider(),
                  ProfileWidgets.buildInfoItem(
                    icon: FontAwesomeIcons.userAlt,
                    title: 'Full Name',
                    value: userInfo['name']!,
                    iconColor: Colors.green[600]!,
                  ),
                  ProfileWidgets.buildDivider(),
                  ProfileWidgets.buildInfoItem(
                    icon: FontAwesomeIcons.phone,
                    title: 'Phone Number',
                    value: userInfo['phone']!,
                    iconColor: Colors.orange[600]!,
                  ),
                  ProfileWidgets.buildDivider(),
                  ProfileWidgets.buildInfoItem(
                    icon: FontAwesomeIcons.envelope,
                    title: 'Email Address',
                    value: userInfo['email']!,
                    iconColor: Colors.purple[600]!,
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Logout Button
              ProfileWidgets.buildLogoutButton(
                onPressed: _handleLogout,
              ),

              // App Version
              ProfileWidgets.buildAppVersion(),
            ],
          ),
        ),
      ),
    );
  }
}