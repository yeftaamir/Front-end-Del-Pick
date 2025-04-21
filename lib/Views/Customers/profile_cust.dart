import 'package:flutter/material.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:del_pick/Views/SplashScreen/splash_screen.dart';
import '../../Models/customer.dart';
import '../../Services/auth_service.dart';
import '../../Services/image_service.dart';

class ProfilePage extends StatefulWidget {
  static const String route = "/Customers/Profile";

  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Customer? _customer;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  String? _processedImageUrl; // Menyimpan URL gambar yang sudah diproses

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
      // Fetch full profile from API instead of using stored data
      final profile = await AuthService.getProfile();

      // Log the raw profile data for debugging
      print('Profile data received: $profile');

      if (profile != null) {
        // Create customer from profile data
        final customer = Customer.fromJson(profile);

        // Process image URL if available
        String? imageUrl;
        if (customer.profileImageUrl != null && customer.profileImageUrl!.isNotEmpty) {
          // Menggunakan ImageService untuk memproses URL gambar
          imageUrl = ImageService.getImageUrl(customer.profileImageUrl);
          print('Original image URL: ${customer.profileImageUrl}');
          print('Processed image URL: $imageUrl');
        }

        if (mounted) {
          setState(() {
            _customer = customer;
            _processedImageUrl = imageUrl;
          });
        }
      } else {
        // Fallback to stored data if API fails
        print('Profile API returned null, falling back to stored data');
        final userData = await AuthService.getUserData();

        if (userData != null) {
          print('User data from storage: $userData');

          // Check if there's an avatar/profileImageUrl field
          String? avatarUrl = userData['avatar'] as String?;
          print('Avatar URL from storage: $avatarUrl');

          final customer = Customer.fromStoredData(userData);

          // Process avatar URL if available
          String? imageUrl;
          if (customer.profileImageUrl != null && customer.profileImageUrl!.isNotEmpty) {
            imageUrl = ImageService.getImageUrl(customer.profileImageUrl);
            print('Processed stored avatar URL: $imageUrl');
          }

          if (mounted) {
            setState(() {
              _customer = customer;
              _processedImageUrl = imageUrl;
            });
          }
        } else {
          // No user data available, redirect to login
          print('No user data available, redirecting to login');
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const SplashScreen()),
                (route) => false,
          );
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _customer = Customer.empty(); // Use empty customer as fallback
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data pengguna: $_errorMessage')),
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

  void _handleLogout(BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Konfirmasi Logout',
            style: TextStyle(
              fontFamily: GlobalStyle.fontFamily,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Apakah Anda yakin ingin keluar?',
            style: TextStyle(
              fontFamily: GlobalStyle.fontFamily,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Batal',
                style: TextStyle(
                  fontFamily: GlobalStyle.fontFamily,
                  color: Colors.grey,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog

                // Show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext context) {
                    return const Center(child: CircularProgressIndicator());
                  },
                );

                try {
                  // Logout from AuthService
                  bool success = await AuthService.logout();
                  print('Logout result: $success');

                  // Close loading dialog
                  if (!mounted) return;
                  Navigator.pop(context);

                  // Navigate to SplashScreen
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const SplashScreen()),
                        (route) => false, // Remove all previous routes
                  );
                } catch (e) {
                  print('Logout error: $e');
                  // Close loading dialog
                  if (!mounted) return;
                  Navigator.pop(context);

                  // Show error message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal logout: ${e.toString()}')),
                  );
                }
              },
              child: Text(
                'Keluar',
                style: TextStyle(
                  fontFamily: GlobalStyle.fontFamily,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // View profile image full screen
  void _viewProfileImage() {
    // First check if we have a processed URL
    if (_processedImageUrl == null || _processedImageUrl!.isEmpty) {
      print('No processed image URL available for viewing');
      // If no processed URL, try to get it from customer
      if (_customer == null || _customer!.profileImageUrl == null || _customer!.profileImageUrl!.isEmpty) {
        print('No profile image URL available for viewing');
        return; // No image to show
      }

      // Try to process the URL if we have it
      _processedImageUrl = ImageService.getImageUrl(_customer!.profileImageUrl);
      if (_processedImageUrl!.isEmpty) {
        print('Could not process profile image URL: ${_customer!.profileImageUrl}');
        return; // Could not process the URL
      }
    }

    print('Showing fullscreen image: $_processedImageUrl');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.black, size: 20),
                  ),
                ),
              ),
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                  maxWidth: MediaQuery.of(context).size.width,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ImageService.displayImage(
                    imageSource: _processedImageUrl!,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.contain,
                    placeholder: const Center(child: CircularProgressIndicator()),
                    errorWidget: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.broken_image, size: 80, color: Colors.grey),
                        const SizedBox(height: 10),
                        Text('Failed to load image', style: TextStyle(color: Colors.grey[600])),
                        Text('URL: $_processedImageUrl',
                            style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                      ],
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

  @override
  Widget build(BuildContext context) {
    // Calculate 25% of screen height for the image
    final double imageHeight = MediaQuery.of(context).size.height * 0.25;

    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _customer == null
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Data pengguna tidak ditemukan'),
              ElevatedButton(
                onPressed: _loadUserData,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        )
            : Column(
          children: [
            // Fixed header with back button and title
            Padding(
              padding: const EdgeInsets.all(24),
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Center(
                    child: Text(
                      'Profil',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: GlobalStyle.fontColor,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(7.0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blue, width: 1.0),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, color: Colors.blue, size: 18),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Profile Image (25% of screen height)
            GestureDetector(
              onTap: _viewProfileImage,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(0),
                  bottom: Radius.circular(16),
                ),
                child: _processedImageUrl != null && _processedImageUrl!.isNotEmpty
                    ? SizedBox(
                  width: double.infinity,
                  height: imageHeight,
                  child: ImageService.displayImage(
                    imageSource: _processedImageUrl!,
                    width: double.infinity,
                    height: imageHeight,
                    fit: BoxFit.cover,
                    placeholder: const Center(child: CircularProgressIndicator()),
                    errorWidget: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          color: Colors.grey[300],
                          width: double.infinity,
                          height: imageHeight,
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.person, size: 80, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text(
                              'Error loading image',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
                    : Container(
                  color: Colors.grey[300],
                  width: double.infinity,
                  height: imageHeight,
                  child: const Center(
                    child: Icon(Icons.person, size: 80, color: Colors.grey),
                  ),
                ),
              ),
            ),

            // User name and role badge
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  // User name
                  Text(
                    _customer!.name,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: GlobalStyle.fontColor,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),

                  // User role badge
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: GlobalStyle.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: GlobalStyle.primaryColor.withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        _customer!.role.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: GlobalStyle.primaryColor,
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // User information card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 3,
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildInfoTile(
                            icon: FontAwesomeIcons.idCard,
                            title: 'User ID',
                            value: _customer!.id,
                          ),
                          const Divider(height: 1, indent: 60),
                          _buildInfoTile(
                            icon: FontAwesomeIcons.user,
                            title: 'Nama User',
                            value: _customer!.name,
                          ),
                          const Divider(height: 1, indent: 60),
                          _buildInfoTile(
                            icon: FontAwesomeIcons.phone,
                            title: 'Nomor Telepon',
                            value: _customer!.phoneNumber,
                          ),
                          const Divider(height: 1, indent: 60),
                          _buildInfoTile(
                            icon: FontAwesomeIcons.envelope,
                            title: 'Email Pengguna',
                            value: _customer!.email,
                          ),
                          // Debug info - untuk development, bisa dihapus nanti
                          // if (_processedImageUrl != null)
                          //   Column(
                          //     children: [
                          //       const Divider(height: 1, indent: 60),
                          //       _buildInfoTile(
                          //         icon: FontAwesomeIcons.image,
                          //         title: 'Image URL',
                          //         value: _processedImageUrl!.length > 50
                          //             ? '${_processedImageUrl!.substring(0, 50)}...'
                          //             : _processedImageUrl!,
                          //       ),
                          //     ],
                          //   ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Logout button
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ElevatedButton(
                        onPressed: () => _handleLogout(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.logout, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Keluar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
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
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FaIcon(
            icon,
            size: 20,
            color: GlobalStyle.primaryColor,
          ),
          const SizedBox(width: 20),
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
                    fontWeight: FontWeight.w500,
                    color: GlobalStyle.fontColor,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
              ],
            ),
          ),
        ]
      ),
    );
  }
}