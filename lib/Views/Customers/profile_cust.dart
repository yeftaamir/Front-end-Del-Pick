import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:del_pick/Views/SplashScreen/splash_screen.dart';
import 'package:http/http.dart' as http;
import '../../Models/customer.dart';

import '../../Services/auth_service.dart';
import '../../Services/image_service.dart';
import '../../Services/customer_service.dart';

class ProfilePage extends StatefulWidget {
  static const String route = "/Customers/Profile";

  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Customer? _customer;
  bool _isLoading = true;
  bool _isUpdatingImage = false;
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
      // Try to get customer profile using the new CustomerService
      Customer? customer;
      try {
        customer = await CustomerService.getCustomerProfile();
        print('Customer profile loaded successfully from API');
      } catch (e) {
        print('Error loading customer profile from API: $e');
        // Fall back to getProfile from AuthService
        customer = null;
      }

      // If CustomerService failed, try using existing AuthService
      if (customer == null) {
        final profile = await AuthService.getProfile();
        print('Profile data received from AuthService: $profile');

        if (profile != null) {
          customer = Customer.fromJson(profile);
        } else {
          print('AuthService profile API returned null, fallback to stored data');
          final userData = await AuthService.getUserData();

          if (userData != null) {
            customer = Customer.fromStoredData(userData);
          } else {
            print('No user data available, redirecting to login');
            if (!mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const SplashScreen()),
                  (route) => false,
            );
            return;
          }
        }
      }

      // Process image URL if available
      String? imageUrl;
      if (customer.avatar != null && customer.avatar!.isNotEmpty) {
        print('Original avatar value: ${customer.avatar}');

        // Debug data URL jika dalam format base64
        if (customer.avatar!.startsWith('data:image/')) {
          print('Avatar is in data URL format');
          _debugBase64DataUrl(customer.avatar!, source: 'Customer Avatar');
          imageUrl = customer.avatar;
        }
        // Jika avatar mungkin raw base64 string tanpa prefix
        else if (_isBase64String(customer.avatar!)) {
          print('Avatar appears to be a raw base64 string');
          String formattedBase64 = 'data:image/jpeg;base64,${customer.avatar}';
          _debugBase64DataUrl(formattedBase64, source: 'Formatted Avatar Base64');
          imageUrl = formattedBase64;
        }
        // Jika avatar adalah URL server atau path lainnya
        else {
          print('Avatar is a server path or URL');
          // Menggunakan ImageService untuk memproses URL gambar
          imageUrl = ImageService.getImageUrl(customer.avatar!);
          print('Processed image URL: $imageUrl');

          // Verifikasi URL dengan membuat request test
          _testImageUrl(imageUrl);
        }
      } else {
        print('No avatar found for customer');
      }

      if (mounted) {
        setState(() {
          _customer = customer;
          _processedImageUrl = imageUrl;
        });
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
          SnackBar(content: Text('Failed to load user data: $_errorMessage')),
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

// Fungsi untuk memeriksa apakah string adalah base64 valid
  bool _isBase64String(String str) {
    try {
      // Memeriksa jika string bisa menjadi base64 yang valid
      if (str.length % 4 != 0 || str.contains(RegExp(r'[^A-Za-z0-9+/=]'))) {
        return false;
      }

      // Coba decode untuk memverifikasi
      base64Decode(str);
      return true;
    } catch (_) {
      return false;
    }
  }

// Fungsi untuk men-debug format data URL base64
  void _debugBase64DataUrl(String dataUrl, {String source = 'unknown'}) {
    print('======= DEBUG BASE64 DATA URL (Source: $source) =======');

    // Periksa apakah format umum adalah data URL
    if (!dataUrl.startsWith('data:')) {
      print('❌ BUKAN DATA URL: String tidak dimulai dengan "data:"');
      print('🔍 Awal string: ${dataUrl.substring(0, min(20, dataUrl.length))}...');
      return;
    }

    // Coba pisahkan header dan content
    final parts = dataUrl.split(',');
    if (parts.length != 2) {
      print('❌ FORMAT TIDAK VALID: Data URL harus memiliki format "data:[mediatype][;base64],<data>"');
      print('🔍 Jumlah bagian yang ditemukan: ${parts.length}');
      return;
    }

    final header = parts[0];
    final base64Content = parts[1];

    // Periksa header
    print('📋 HEADER: $header');
    if (!header.contains(';base64')) {
      print('⚠️ PERINGATAN: Header tidak mengandung ";base64", mungkin bukan encoding base64');
    }

    // Periksa tipe media (MIME type)
    final mimeMatch = RegExp(r'data:([\w\/\-\.+]+);').firstMatch(header);
    if (mimeMatch != null) {
      final mimeType = mimeMatch.group(1);
      print('📄 MIME Type: $mimeType');

      if (!mimeType!.startsWith('image/')) {
        print('⚠️ PERINGATAN: MIME Type bukan tipe gambar');
      }
    } else {
      print('⚠️ PERINGATAN: MIME Type tidak ditemukan dalam header');
    }

    // Periksa konten base64
    print('📊 PANJANG CONTENT: ${base64Content.length} karakter');
    print('🔍 AWAL CONTENT: ${base64Content.substring(0, min(30, base64Content.length))}...');
    print('🔍 AKHIR CONTENT: ...${base64Content.substring(max(0, base64Content.length - 30))}');

    // Periksa karakter yang tidak valid dalam base64
    final invalidChars = RegExp(r'[^A-Za-z0-9+/=]').allMatches(base64Content).map((m) => m.group(0)).toSet();
    if (invalidChars.isNotEmpty) {
      print('❌ KARAKTER TIDAK VALID TERDETEKSI: $invalidChars');
    } else {
      print('✅ FORMAT BASE64 VALID: Tidak ada karakter ilegal');
    }

    // Periksa panjang (harus kelipatan 4 untuk base64 yang valid)
    if (base64Content.length % 4 != 0) {
      print('❌ PANJANG TIDAK VALID: Panjang (${base64Content.length}) bukan kelipatan 4');
    } else {
      print('✅ PANJANG VALID: Panjang adalah kelipatan 4');
    }

    // Periksa padding
    if (base64Content.endsWith('=')) {
      final paddingCount = base64Content.split('').reversed.takeWhile((char) => char == '=').length;
      print('ℹ️ PADDING: $paddingCount karakter "="');
    } else if (base64Content.length % 4 != 0) {
      print('⚠️ PADDING HILANG: Tidak ada "=" di akhir tapi panjang bukan kelipatan 4');
    }

    // Coba decode untuk memvalidasi
    try {
      final decoded = base64Decode(base64Content);
      print('✅ DECODE BERHASIL: ${decoded.length} bytes');

      // Deteksi format gambar dari bytes jika tersedia
      if (decoded.length > 4) {
        String detectedFormat = "unknown";
        if (decoded[0] == 0xFF && decoded[1] == 0xD8 && decoded[2] == 0xFF) {
          detectedFormat = "JPEG/JPG";
        } else if (decoded[0] == 0x89 && decoded[1] == 0x50 && decoded[2] == 0x4E && decoded[3] == 0x47) {
          detectedFormat = "PNG";
        } else if (decoded[0] == 0x47 && decoded[1] == 0x49 && decoded[2] == 0x46) {
          detectedFormat = "GIF";
        } else if (decoded[0] == 0x42 && decoded[1] == 0x4D) {
          detectedFormat = "BMP";
        }
        print('🖼️ FORMAT GAMBAR TERDETEKSI: $detectedFormat');
      }
    } catch (e) {
      print('❌ DECODE GAGAL: $e');

      // Coba perbaiki padding dan decode ulang
      String fixedContent = base64Content;
      if (fixedContent.length % 4 != 0) {
        final paddingNeeded = 4 - (fixedContent.length % 4);
        fixedContent = fixedContent.padRight(fixedContent.length + paddingNeeded, '=');
        print('🔧 MENCOBA PERBAIKI PADDING: Menambahkan $paddingNeeded karakter "="');

        try {
          final decoded = base64Decode(fixedContent);
          print('✅ DECODE BERHASIL SETELAH PERBAIKAN: ${decoded.length} bytes');
        } catch (e) {
          print('❌ DECODE MASIH GAGAL SETELAH PERBAIKAN: $e');
        }
      }
    }

    print('======= AKHIR DEBUG =======\n');
  }

// Fungsi untuk menguji URL gambar
  Future<void> _testImageUrl(String url) async {
    try {
      print('======= TESTING IMAGE URL =======');
      print('URL yang diuji: $url');

      final response = await http.head(Uri.parse(url));

      print('Status code: ${response.statusCode}');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('✅ URL VALID: Status ${response.statusCode}');
        print('Content-Type: ${response.headers['content-type']}');
        print('Content-Length: ${response.headers['content-length']}');
      } else {
        print('❌ URL TIDAK VALID: Status ${response.statusCode}');

        // Jika URL mengandung /api/v1/, coba versi tanpa itu
        if (url.contains('/api/v1/')) {
          final alternativeUrl = url.replaceFirst('/api/v1/', '/');
          print('🔄 Mencoba URL alternatif: $alternativeUrl');
          await _testImageUrl(alternativeUrl);
        }

        // Jika URL tidak dimulai dengan domain penuh
        if (!url.startsWith('http')) {
          final fullUrl = 'https://delpick.horas-code.my.id$url';
          print('🔄 Mencoba URL dengan domain lengkap: $fullUrl');
          await _testImageUrl(fullUrl);
        }
      }

      print('======= AKHIR TESTING URL =======\n');
    } catch (e) {
      print('❌ ERROR TESTING URL: $e');
      print('======= AKHIR TESTING URL =======\n');
    }
  }
  // Update profile image
  Future<void> _updateProfileImage() async {
    if (_customer == null) return;

    setState(() {
      _isUpdatingImage = true;
    });

    try {
      // Get image from image picker and encode to base64
      final imageData = await ImageService.pickAndEncodeImage();
      if (imageData == null) {
        setState(() {
          _isUpdatingImage = false;
        });
        return;
      }

      // Upload profile image
      final success = await CustomerService.updateProfileImage(_customer!, imageData['base64']);

      if (success) {
        // Refresh user data to get updated profile image
        await _loadUserData();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile image updated successfully')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile image')),
        );
      }
    } catch (e) {
      print('Error updating profile image: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile image: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingImage = false;
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
      if (_customer == null || _customer!.avatar == null || _customer!.avatar!.isEmpty) {
        print('No profile image URL available for viewing');
        return; // No image to show
      }

      // Try to process the URL if we have it
      _processedImageUrl = ImageService.getImageUrl(_customer!.avatar!);
      if (_processedImageUrl!.isEmpty) {
        print('Could not process profile image URL: ${_customer!.avatar}');
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

  Future<void> _testHttpRequest() async {
    try {
      // Test the base URL
      final baseResponse = await http.get(Uri.parse('https://delpick.horas-code.my.id/'));
      print('Base URL response status: ${baseResponse.statusCode}');

      // Test with API path
      final apiResponse = await http.get(Uri.parse('https://delpick.horas-code.my.id/api/v1/'));
      print('API URL response status: ${apiResponse.statusCode}');

      // Test the specific image path
      final imageResponse = await http.get(Uri.parse('https://delpick.horas-code.my.id/uploads/users/avatar_1745315575533.jpeg'));
      print('Image URL response status: ${imageResponse.statusCode}');

      // Test with API prefix for image path
      final apiImageResponse = await http.get(Uri.parse('https://delpick.horas-code.my.id/uploads/users/avatar_1745315575533.jpeg'));
      print('API Image URL response status: ${apiImageResponse.statusCode}');
    } catch (e) {
      print('HTTP request error: $e');
    }
  }

  void testImageLoading() {
    // URL gambar normal
    final imageUrl = 'https://delpick.horas-code.my.id/uploads/users/avatar-1745403326107.png';

    // Contoh data URL dengan encoding base64
    // Format: data:image/[format];base64,[data]
    final String dataUrlImage = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg==';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Test Image Loading'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tampilan gambar dari URL biasa
            const Text('URL Image:'),
            SizedBox(
              width: 150,
              height: 150,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, error, __) => Text('Error: $error', style: const TextStyle(fontSize: 10)),
              ),
            ),

            const SizedBox(height: 20),

            // Tampilan gambar dari data URL (base64)
            const Text('Data URL (base64) Image:'),
            SizedBox(
              width: 150,
              height: 150,
              child: Image.memory(
                _decodeDataUrl(dataUrlImage),
                fit: BoxFit.cover,
                errorBuilder: (_, error, __) => Text('Error: $error', style: const TextStyle(fontSize: 10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

// Fungsi untuk mengekstrak dan mendecode data URL
  Uint8List _decodeDataUrl(String dataUrl) {
    // Memisahkan header dan data base64
    final regexResult = RegExp(r'data:image/[^;]+;base64,(.*)').firstMatch(dataUrl);
    final base64Str = regexResult?.group(1) ?? '';

    // Decode base64 menjadi Uint8List
    return base64Decode(base64Str);
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

            // Profile Image (25% of screen height) with edit button overlay
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                // Profile Image
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

                // Edit Button overlay
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: _isUpdatingImage ? null : _updateProfileImage,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: GlobalStyle.primaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: _isUpdatingImage
                          ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
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
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
// Test Image Loading Button
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ElevatedButton(
                        onPressed: testImageLoading, // Call your existing method
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.image, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Test Image Loading',
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
                    const SizedBox(height: 16), // Add space between buttons

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