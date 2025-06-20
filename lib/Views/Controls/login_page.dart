import 'package:del_pick/Common/global_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:del_pick/Services/auth_service.dart';
import 'connectivity_service.dart';
import 'dart:io';

class LoginPage extends StatefulWidget {
  static const String route = "/Controls/Login";
  const LoginPage({super.key});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;
  final FlutterSecureStorage _storage = FlutterSecureStorage();
  bool obscurePassword = true;
  bool rememberMe = false;

  @override
  void initState() {
    super.initState();
    _checkSavedCredentials();
  }

  // Check for saved credentials on startup
  Future<void> _checkSavedCredentials() async {
    try {
      final String? savedEmail = await _storage.read(key: 'remembered_email');
      final String? savedPassword = await _storage.read(key: 'remembered_password');
      final String? isRemembered = await _storage.read(key: 'is_remembered');

      if (savedEmail != null && savedPassword != null && isRemembered == 'true') {
        setState(() {
          emailController.text = savedEmail;
          passwordController.text = savedPassword;
          rememberMe = true;
        });
      }
    } catch (e) {
      print("Error retrieving saved credentials: $e");
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // Save or clear credentials based on Remember Me
  Future<void> _handleRememberMe() async {
    if (rememberMe) {
      await _storage.write(key: 'remembered_email', value: emailController.text);
      await _storage.write(key: 'remembered_password', value: passwordController.text);
      await _storage.write(key: 'is_remembered', value: 'true');
    } else {
      await _storage.delete(key: 'remembered_email');
      await _storage.delete(key: 'remembered_password');
      await _storage.write(key: 'is_remembered', value: 'false');
    }
  }

  // Improved login function using AuthService
  void _login() async {
    // Validate input fields
    if (emailController.text.trim().isEmpty || passwordController.text.isEmpty) {
      _showFriendlyError("Mohon lengkapi email dan kata sandi Anda.");
      return;
    }

    // Basic email validation
    if (!_isValidEmail(emailController.text.trim())) {
      _showFriendlyError("Format email tidak valid. Silakan periksa kembali.");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Check internet connectivity
      bool hasConnection = await _checkInternetConnection();
      if (!hasConnection) {
        _showFriendlyError("Tidak ada koneksi internet",
            "Pastikan perangkat Anda terhubung ke internet dan coba lagi.");
        return;
      }

      // Use AuthService for login - it handles token saving automatically
      final loginResponse = await AuthService.login(
          emailController.text.trim(),
          passwordController.text
      );

      // Handle Remember Me functionality
      await _handleRememberMe();

      // Check if login was successful
      if (loginResponse.isEmpty) {
        _showFriendlyError("Login gagal", "Terjadi kesalahan saat masuk. Silakan coba lagi.");
        return;
      }

      // Get user data from response
      final userData = loginResponse['user'];
      if (userData == null) {
        _showFriendlyError("Login gagal", "Data pengguna tidak ditemukan. Silakan coba lagi.");
        return;
      }

      final String userRole = userData['role'] ?? '';
      final String userName = userData['name'] ?? 'Pengguna';

      print("Login successful for user: $userName (Role: $userRole)");

      // Show success message
      _showSuccessMessage("Selamat datang, $userName!");

      // Navigate based on user role
      await Future.delayed(Duration(milliseconds: 500)); // Brief delay for user to see success message

      switch (userRole.toLowerCase()) {
        case 'customer':
          Navigator.pushReplacementNamed(context, '/Customers/HomePage');
          break;
        case 'store':
          Navigator.pushReplacementNamed(context, '/Store/HomePage');
          break;
        case 'driver':
          Navigator.pushReplacementNamed(context, '/Driver/HomePage');
          break;
        case 'admin':
          Navigator.pushReplacementNamed(context, '/Admin/HomePage');
          break;
        default:
          _showFriendlyError("Akun tidak dikenali",
              "Tipe akun Anda belum didukung. Silakan hubungi administrator.");
      }

    } on SocketException catch (_) {
      _showFriendlyError("Koneksi bermasalah",
          "Tidak dapat terhubung ke server. Periksa koneksi internet Anda.");
    } on HttpException catch (_) {
      _showFriendlyError("Server bermasalah",
          "Server sedang mengalami gangguan. Silakan coba beberapa saat lagi.");
    } catch (e) {
      String errorMessage = _getFriendlyErrorMessage(e.toString());
      _showFriendlyError("Login gagal", errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Email validation helper
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // Convert technical error messages to user-friendly ones
  String _getFriendlyErrorMessage(String technicalError) {
    String lowerError = technicalError.toLowerCase();

    if (lowerError.contains('invalid credentials') ||
        lowerError.contains('unauthorized') ||
        lowerError.contains('wrong password') ||
        lowerError.contains('email not found')) {
      return "Email atau kata sandi salah. Silakan periksa kembali.";
    }

    if (lowerError.contains('network') || lowerError.contains('connection')) {
      return "Gangguan koneksi internet. Pastikan Anda terhubung ke internet.";
    }

    if (lowerError.contains('timeout')) {
      return "Koneksi terlalu lambat. Silakan coba lagi.";
    }

    if (lowerError.contains('server error') || lowerError.contains('500')) {
      return "Server sedang bermasalah. Silakan coba beberapa saat lagi.";
    }

    if (lowerError.contains('not found') || lowerError.contains('404')) {
      return "Layanan tidak tersedia saat ini. Silakan coba lagi nanti.";
    }

    if (lowerError.contains('validation') || lowerError.contains('format')) {
      return "Data yang dimasukkan tidak sesuai format. Silakan periksa kembali.";
    }

    if (lowerError.contains('expired')) {
      return "Sesi telah berakhir. Silakan masuk kembali.";
    }

    if (lowerError.contains('blocked') || lowerError.contains('suspended')) {
      return "Akun Anda diblokir. Hubungi customer service untuk bantuan.";
    }

    // Default fallback message
    return "Terjadi kesalahan yang tidak terduga. Silakan coba lagi atau hubungi customer service.";
  }

  // Check internet connection
  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  // Enhanced error display with better UX
  void _showFriendlyError(String title, [String? subtitle]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            if (subtitle != null) ...[
              SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  // Success message display
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Role selection dialog for testing/demo purposes
  void _showRoleSelectionDialog() {
    final connectivityService =
    Provider.of<ConnectivityService>(context, listen: false);
    if (!connectivityService.isConnected) {
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Pilih Role Demo',
            style: TextStyle(
              color: GlobalStyle.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildRoleButton(
                  'Customer',
                  Icons.person,
                      () => Navigator.pushReplacementNamed(
                      context, '/Customers/HomePage'),
                ),
                const SizedBox(height: 10),
                _buildRoleButton(
                  'Admin',
                  Icons.admin_panel_settings,
                      () => Navigator.pushReplacementNamed(
                      context, '/Admin/HomePage'),
                ),
                const SizedBox(height: 10),
                _buildRoleButton(
                  'Driver',
                  Icons.delivery_dining,
                      () => Navigator.pushReplacementNamed(
                      context, '/Driver/HomePage'),
                ),
                const SizedBox(height: 10),
                _buildRoleButton(
                  'Store',
                  Icons.store,
                      () => Navigator.pushReplacementNamed(
                      context, '/Store/HomePage'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoleButton(String role, IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: GlobalStyle.primaryColor),
          ),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(icon, color: GlobalStyle.primaryColor),
            const SizedBox(width: 12),
            Text(
              'Login as $role',
              style: TextStyle(
                color: GlobalStyle.primaryColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/delpick_image.png',
                width: 250,
              ),
              const SizedBox(height: 10),
              const Text(
                "Masuk menggunakan akun Anda",
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 30.0),

              // Email Field
              SizedBox(
                width: screenWidth * 0.8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Email:',
                      style: TextStyle(
                        fontSize: 16,
                        color: GlobalStyle.fontColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        hintText: 'Masukkan email Anda',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20.0),

              // Password Field
              SizedBox(
                width: screenWidth * 0.8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kata Sandi:',
                      style: TextStyle(
                        fontSize: 16,
                        color: GlobalStyle.fontColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    TextFormField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        hintText: 'Masukkan kata sandi Anda',
                        prefixIcon: Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Remember Me Checkbox
              SizedBox(
                width: screenWidth * 0.8,
                child: Row(
                  children: [
                    Checkbox(
                      value: rememberMe,
                      activeColor: GlobalStyle.primaryColor,
                      onChanged: (bool? value) {
                        setState(() {
                          rememberMe = value ?? false;
                        });
                      },
                    ),
                    Text(
                      'Ingat Saya',
                      style: TextStyle(
                        color: GlobalStyle.fontColor,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        // TODO: Implement forgot password
                        _showFriendlyError("Fitur Lupa Password",
                            "Fitur ini akan tersedia segera. Hubungi customer service untuk bantuan.");
                      },
                      child: Text(
                        'Lupa Password?',
                        style: TextStyle(
                          color: GlobalStyle.primaryColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20.0),

              // Login Button
              Container(
                width: screenWidth * 0.5,
                height: 50.0,
                decoration: BoxDecoration(
                  color: _isLoading ? Colors.grey : GlobalStyle.primaryColor,
                  borderRadius: BorderRadius.circular(30.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: _isLoading
                    ? const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : TextButton(
                  onPressed: _login,
                  child: const Text(
                    'Masuk',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20.0),

              // Demo Role Selection Button (for testing)
              if (false) // Set to true for demo/testing
                TextButton(
                  onPressed: _showRoleSelectionDialog,
                  child: Text(
                    'Demo Role Selection',
                    style: TextStyle(
                      color: GlobalStyle.primaryColor,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}