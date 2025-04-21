import 'package:flutter/material.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:del_pick/Views/SplashScreen/splash_screen.dart';
import 'package:del_pick/Models/driver.dart';
import 'package:del_pick/Services/auth_service.dart';
import 'package:del_pick/Services/image_service.dart';
import 'package:del_pick/Services/core/token_service.dart';

class ProfileDriverPage extends StatefulWidget {
  static const String route = "/Driver/Profile";

  const ProfileDriverPage({super.key});

  // Alternative constructor that uses the sample driver (for testing)
  factory ProfileDriverPage.sample() {
    return const ProfileDriverPage();
  }

  @override
  State<ProfileDriverPage> createState() => _ProfileDriverPageState();
}

class _ProfileDriverPageState extends State<ProfileDriverPage> {
  Driver? _driver;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get the user data from storage
      final userData = await AuthService.getUserData();

      if (userData == null) {
        // No user data found, redirect to login
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const SplashScreen()),
              (route) => false,
        );
        return;
      }

      // Check if the user is a driver
      final userRole = userData['role'];
      if (userRole != 'driver') {
        throw Exception('User is not a driver');
      }

      // Get the driver ID from the user data
      final userId = userData['id']?.toString();
      if (userId == null || userId.isEmpty) {
        throw Exception('Driver ID not found');
      }

      // Create a combined data structure that includes driver data
      Map<String, dynamic> combinedData = {...userData};

      // If driver data exists in the user data, merge it
      if (userData['driver'] != null) {
        // Add driver data to the root level for Driver.fromStoredData to process
        combinedData['vehicle_number'] = userData['driver']['vehicle_number'];
        combinedData['rating'] = userData['driver']['rating'] ?? 0.0;
        combinedData['reviews_count'] = userData['driver']['reviews_count'] ?? 0;
        combinedData['latitude'] = userData['driver']['latitude'];
        combinedData['longitude'] = userData['driver']['longitude'];
        combinedData['status'] = userData['driver']['status'] ?? 'inactive';

        // Add the driver ID if available
        if (userData['driver']['id'] != null) {
          combinedData['driver_id'] = userData['driver']['id'];
        }
      }

      // Create driver object from the combined data
      setState(() {
        _driver = Driver.fromStoredData(combinedData);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal memuat data driver: ${e.toString()}';
        _isLoading = false;
      });
      print('Error loading driver profile: $e');
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
                  // Logout from AuthService - this will clear all tokens and data
                  final result = await AuthService.logout();

                  // Close loading dialog
                  if (!mounted) return;
                  Navigator.pop(context);

                  if (result) {
                    // Navigate to SplashScreen after successful logout
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const SplashScreen()),
                          (route) => false, // Remove all previous routes
                    );
                  } else {
                    throw Exception('Logout failed');
                  }
                } catch (e) {
                  // Close loading dialog
                  if (!mounted) return;
                  Navigator.pop(context);

                  // Show error message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal logout: ${e.toString()}')),
                  );

                  // As a last resort, just clear tokens and navigate away
                  await TokenService.clearAll();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const SplashScreen()),
                        (route) => false,
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
    if (_driver == null ||
        _driver!.profileImageUrl == null ||
        _driver!.profileImageUrl!.isEmpty) {
      // If no image, don't show dialog
      return;
    }

    // Get processed image URL
    String processedImageUrl = _driver!.getProcessedImageUrl() ?? '';
    if (processedImageUrl.isEmpty) {
      return;
    }

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
                    imageSource: processedImageUrl,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.contain,
                    placeholder: const Center(child: CircularProgressIndicator()),
                    errorWidget: Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image, size: 80, color: Colors.grey),
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
            : _driver == null
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage ?? 'Data driver tidak ditemukan'),
              const SizedBox(height: 16),
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
                      'Profil Driver',
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
                child: _driver!.getProcessedImageUrl() != null && _driver!.getProcessedImageUrl()!.isNotEmpty
                    ? ImageService.displayImage(
                  imageSource: _driver!.getProcessedImageUrl()!,
                  width: double.infinity,
                  height: imageHeight,
                  fit: BoxFit.cover,
                  placeholder: const Center(child: CircularProgressIndicator()),
                  errorWidget: _buildDefaultProfileImage(imageHeight),
                )
                    : _buildDefaultProfileImage(imageHeight),
              ),
            ),

            // User name and badges
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  // Display driver name
                  Text(
                    _driver!.name,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: GlobalStyle.fontColor,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),

                  // Display driver role and rating badge
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Role badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: GlobalStyle.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: GlobalStyle.primaryColor.withOpacity(0.5),
                            ),
                          ),
                          child: Text(
                            _driver!.role.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: GlobalStyle.primaryColor,
                              fontFamily: GlobalStyle.fontFamily,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Rating badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.amber,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, color: Colors.amber[700], size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '${_driver!.rating}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber[800],
                                  fontFamily: GlobalStyle.fontFamily,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Reviews count
                  if (_driver!.reviewsCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${_driver!.reviewsCount} reviews',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  children: [
                    // Container informasi profil
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
                            title: 'Driver ID',
                            value: _driver!.id,
                          ),
                          const Divider(height: 1, indent: 60),
                          _buildInfoTile(
                            icon: FontAwesomeIcons.user,
                            title: 'Nama Driver',
                            value: _driver!.name,
                          ),
                          const Divider(height: 1, indent: 60),
                          _buildInfoTile(
                            icon: FontAwesomeIcons.star,
                            title: 'Penilaian',
                            value: '${_driver!.rating} dari 5',
                          ),
                          const Divider(height: 1, indent: 60),
                          _buildInfoTile(
                            icon: FontAwesomeIcons.phone,
                            title: 'Nomor Telepon',
                            value: _driver!.phoneNumber,
                          ),
                          const Divider(height: 1, indent: 60),
                          _buildInfoTile(
                            icon: FontAwesomeIcons.car,
                            title: 'Nomor Kendaraan',
                            value: _driver!.vehicleNumber,
                          ),
                          const Divider(height: 1, indent: 60),
                          _buildInfoTile(
                            icon: FontAwesomeIcons.envelope,
                            title: 'Email',
                            value: _driver!.email,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Tombol Logout
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
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build default profile image container
  Widget _buildDefaultProfileImage(double height) {
    return Container(
      color: Colors.grey[300],
      width: double.infinity,
      height: height,
      child: const Center(
        child: Icon(Icons.person, size: 80, color: Colors.grey),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
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
                    color: valueColor ?? GlobalStyle.fontColor,
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
}