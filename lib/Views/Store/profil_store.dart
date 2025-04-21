import 'package:flutter/material.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:del_pick/Views/SplashScreen/splash_screen.dart';
import 'package:del_pick/Models/store.dart';
import 'package:del_pick/services/auth_service.dart';

class ProfileStorePage extends StatefulWidget {
  static const String route = "/Store/Profile";

  const ProfileStorePage({
    super.key,
  });

  @override
  State<ProfileStorePage> createState() => _ProfileStorePageState();
}

class _ProfileStorePageState extends State<ProfileStorePage> {
  StoreModel? store;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStoreData();
  }

  Future<void> _loadStoreData() async {
    try {
      // Get user data from AuthService
      final userData = await AuthService.getUserData();

      if (userData != null && userData.containsKey('store')) {
        setState(() {
          store = StoreModel.fromJson(userData['store']);
          isLoading = false;
        });
      } else {
        // Attempt to get profile data if store not found in cached user data
        final profileData = await AuthService.getProfile();

        if (profileData.containsKey('store')) {
          setState(() {
            store = StoreModel.fromJson(profileData['store']);
            isLoading = false;
          });
        } else {
          setState(() {
            isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data toko tidak ditemukan')),
          );
        }
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat data: $e')),
      );
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
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );

                // Call logout service
                try {
                  final success = await AuthService.logout();

                  // Close loading indicator
                  Navigator.pop(context);

                  if (success) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const SplashScreen()),
                          (route) => false, // Remove all previous routes
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Gagal logout, silahkan coba lagi')),
                    );
                  }
                } catch (e) {
                  // Close loading indicator
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
    // Calculate 25% of screen height for the image
    final double imageHeight = MediaQuery.of(context).size.height * 0.25;

    return Scaffold(
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : store == null
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Data toko tidak tersedia'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadStoreData,
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

            // Fixed image (25% of screen height)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(0),
                bottom: Radius.circular(16),
              ),
              child: store!.imageUrl.isEmpty
                  ? Container(
                width: double.infinity,
                height: imageHeight,
                color: Colors.grey[300],
                child: const Icon(
                  Icons.store,
                  size: 64,
                  color: Colors.grey,
                ),
              )
                  : Image.network(
                store!.imageUrl,
                width: double.infinity,
                height: imageHeight,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    height: imageHeight,
                    color: Colors.grey[300],
                    child: const Icon(
                      Icons.error,
                      size: 64,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 32),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
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
                              icon: FontAwesomeIcons.store,
                              title: 'Nama Toko',
                              value: store!.name,
                            ),
                            const Divider(height: 1, indent: 20),
                            _buildInfoTile(
                              icon: FontAwesomeIcons.circleInfo,
                              title: 'Keterangan',
                              value: store!.description.isNotEmpty
                                  ? store!.description
                                  : 'Tidak ada keterangan',
                              isDescription: true,
                            ),
                            const Divider(height: 1, indent: 20),
                            _buildInfoTile(
                              icon: FontAwesomeIcons.locationDot,
                              title: 'Alamat',
                              value: store!.address,
                            ),
                            const Divider(height: 1, indent: 20),
                            _buildInfoTile(
                              icon: FontAwesomeIcons.clock,
                              title: 'Jam Buka',
                              value: store!.openHours,
                            ),
                            const Divider(height: 1, indent: 20),
                            _buildInfoTile(
                              icon: FontAwesomeIcons.star,
                              title: 'Penilaian',
                              value: store!.rating > 0
                                  ? store!.formattedRating
                                  : 'Belum ada penilaian',
                            ),
                            const Divider(height: 1, indent: 20),
                            _buildInfoTile(
                              icon: FontAwesomeIcons.phone,
                              title: 'Nomor Telepon',
                              value: store!.phoneNumber,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
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
                    ),
                    const SizedBox(height: 32),
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
    bool isDescription = false,
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
                  maxLines: isDescription ? 4 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}