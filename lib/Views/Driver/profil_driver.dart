import 'package:flutter/material.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:del_pick/Views/SplashScreen/splash_screen.dart';
import 'package:del_pick/Models/driver.dart';
import 'package:del_pick/Services/auth_service.dart';
import 'package:del_pick/Services/image_service.dart';

class ProfileDriverPage extends StatefulWidget {
  static const String route = "/Driver/Profile";

  final Driver? driver;

  const ProfileDriverPage({
    super.key,
    this.driver,
  });

  // Alternative constructor that uses the sample driver
  factory ProfileDriverPage.sample() {
    return const ProfileDriverPage();
  }

  @override
  State<ProfileDriverPage> createState() => _ProfileDriverPageState();
}

class _ProfileDriverPageState extends State<ProfileDriverPage> {
  Driver? _driver;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDriverData();
  }

  // Load driver data from cache or API
  Future<void> _loadDriverData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // First check if we already have driver data passed in
      if (widget.driver != null) {
        setState(() {
          _driver = widget.driver;
          _isLoading = false;
        });
        return;
      }

      // Try to get driver data from cached user data
      final userData = await AuthService.getUserData();
      if (userData != null) {
        // Check if user has driver data
        if (userData['driver'] != null) {
          // Merge user data with driver data for proper structure
          final driverData = {
            ...userData,
            'driver': userData['driver'],
          };

          setState(() {
            _driver = Driver.fromJson(driverData);
            _isLoading = false;
          });
          return;
        }
      }

      // If no cached data, try to fetch fresh profile data
      final profileData = await AuthService.getProfile();
      if (profileData['driver'] != null) {
        setState(() {
          _driver = Driver.fromJson(profileData);
          _isLoading = false;
        });
      } else {
        // If no driver data found in profile
        setState(() {
          _error = "Data driver tidak ditemukan";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Gagal memuat data: $e";
        _isLoading = false;
      });
      print('Error loading driver data: $e');
    }
  }

  void _handleLogout(BuildContext context) {
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
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  },
                );

                // Perform logout
                try {
                  final result = await AuthService.logout();

                  // Close loading indicator
                  Navigator.pop(context);

                  if (result) {
                    // Navigate to splash screen and clear all routes
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const SplashScreen()),
                          (route) => false,
                    );
                  } else {
                    // Show error if logout failed
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Gagal logout. Silakan coba lagi.')),
                    );
                  }
                } catch (e) {
                  // Close loading indicator and show error
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _buildErrorView()
            : _buildProfileContent(),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            _error ?? "Terjadi kesalahan",
            style: TextStyle(
              fontFamily: GlobalStyle.fontFamily,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadDriverData,
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Coba Lagi',
              style: TextStyle(
                fontFamily: GlobalStyle.fontFamily,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Stack(
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

          const SizedBox(height: 32),

          // Profile image
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: GlobalStyle.primaryColor,
                    width: 2,
                  ),
                ),
                child: _driver?.profileImageUrl != null
                    ? CircleAvatar(
                  radius: 60,
                  backgroundImage: NetworkImage(
                    ImageService.getImageUrl(_driver?.profileImageUrl),
                  ),
                )
                    : CircleAvatar(
                  radius: 60,
                  backgroundColor: GlobalStyle.lightColor,
                  child: Icon(
                    Icons.person,
                    size: 60,
                    color: GlobalStyle.primaryColor,
                  ),
                ),
              ),

              // Role badge
              Transform.translate(
                offset: const Offset(0, 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: GlobalStyle.primaryColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    _driver?.role?.toUpperCase() ?? 'DRIVER',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),

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
                  icon: FontAwesomeIcons.user,
                  title: 'Nama Driver',
                  value: _driver?.name ?? '-',
                ),
                const Divider(height: 1, indent: 20),
                _buildInfoTile(
                  icon: FontAwesomeIcons.star,
                  title: 'Penilaian',
                  value: '${_driver?.rating ?? 0} dari 5',
                ),
                const Divider(height: 1, indent: 20),
                _buildInfoTile(
                  icon: FontAwesomeIcons.phone,
                  title: 'Nomor Telepon',
                  value: _driver?.phoneNumber ?? '-',
                ),
                const Divider(height: 1, indent: 20),
                _buildInfoTile(
                  icon: FontAwesomeIcons.car,
                  title: 'Nomor Kendaraan',
                  value: _driver?.vehicleNumber ?? '-',
                ),
                const Divider(height: 1, indent: 20),
                _buildInfoTile(
                  icon: FontAwesomeIcons.envelope,
                  title: 'Email',
                  value: _driver?.email ?? '-',
                ),
                const Divider(height: 1, indent: 20),
                _buildInfoTile(
                  icon: FontAwesomeIcons.circleCheck,
                  title: 'Status',
                  value: _getStatusText(_driver?.status),
                  valueColor: _getStatusColor(_driver?.status),
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
        ],
      ),
    );
  }

  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return 'Aktif';
      case 'inactive':
        return 'Tidak Aktif';
      default:
        return 'Tidak Diketahui';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.red;
      default:
        return Colors.grey;
    }
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