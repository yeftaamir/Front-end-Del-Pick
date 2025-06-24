import 'package:del_pick/Common/global_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:del_pick/Services/auth_service.dart';
import 'package:del_pick/Services/core/token_service.dart';
import 'package:del_pick/Views/Controls/connectivity_service.dart';
import 'package:del_pick/Views/Customers/home_cust.dart';
import 'package:del_pick/Views/Store/home_store.dart';
import 'package:del_pick/Views/Driver/home_driver.dart';

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
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
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

        // Optionally auto-login if credentials are saved
        // Uncomment the next line if you want auto-login
        // _login();
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
    try {
      if (rememberMe) {
        await _storage.write(key: 'remembered_email', value: emailController.text);
        await _storage.write(key: 'remembered_password', value: passwordController.text);
        await _storage.write(key: 'is_remembered', value: 'true');
      } else {
        await _storage.delete(key: 'remembered_email');
        await _storage.delete(key: 'remembered_password');
        await _storage.write(key: 'is_remembered', value: 'false');
      }
    } catch (e) {
      print("Error handling remember me: $e");
    }
  }

  // Login function using AuthService
  void _login() async {
    // Validate input fields
    if (emailController.text.trim().isEmpty || passwordController.text.trim().isEmpty) {
      _showError("Email dan kata sandi tidak boleh kosong.");
      return;
    }

    // Validate email format
    if (!_isValidEmail(emailController.text.trim())) {
      _showError("Format email tidak valid.");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Check internet connectivity using ConnectivityService
      final connectivityService = Provider.of<ConnectivityService>(context, listen: false);
      if (!connectivityService.isConnected) {
        _showError("Tidak ada koneksi internet. Silakan periksa koneksi Anda.");
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Make the API call to login using AuthService
      final loginResponse = await AuthService.login(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      // Handle Remember Me functionality
      await _handleRememberMe();

      // Check if login was successful
      if (loginResponse == null) {
        _showError("Login gagal. Silakan periksa email dan kata sandi Anda.");
        return;
      }

      // Get user data from the response
      final userData = loginResponse['user'];
      if (userData == null) {
        _showError("Data pengguna tidak ditemukan.");
        return;
      }

      // Get user role
      final String? role = userData['role']?.toString().toLowerCase();
      if (role == null || role.isEmpty) {
        _showError("Peran pengguna tidak ditemukan.");
        return;
      }

      print("Login berhasil untuk role: $role");

      // Show success message
      _showSuccess("Login berhasil! Selamat datang.");

      // Navigate to the correct page based on the user's role
      await _navigateBasedOnRole(role);

    } catch (e) {
      print("Login error: $e");

      // Handle specific error messages
      String errorMessage = "Terjadi kesalahan saat login.";

      if (e.toString().contains('401')) {
        errorMessage = "Email atau kata sandi salah.";
      } else if (e.toString().contains('400')) {
        errorMessage = "Data yang dikirim tidak valid.";
      } else if (e.toString().contains('500')) {
        errorMessage = "Terjadi kesalahan pada server. Silakan coba lagi nanti.";
      } else if (e.toString().contains('network')) {
        errorMessage = "Gagal terhubung ke server. Periksa koneksi internet Anda.";
      } else if (e.toString().contains('timeout')) {
        errorMessage = "Koneksi timeout. Silakan coba lagi.";
      }

      _showError(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Navigate based on user role
  Future<void> _navigateBasedOnRole(String role) async {
    if (!mounted) return;

    switch (role) {
      case 'customer':
        Navigator.pushReplacementNamed(context, HomePage.route);
        break;
      case 'store':
      case 'store_owner':
        Navigator.pushReplacementNamed(context, HomeStore.route);
        break;
      case 'driver':
        Navigator.pushReplacementNamed(context, HomeDriverPage.route);
        break;
      case 'admin':
        Navigator.pushReplacementNamed(context, '/Admin/HomePage');
        break;
      default:
        _showError("Peran '$role' tidak dikenali.");
        break;
    }
  }

  // Validate email format
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    return emailRegex.hasMatch(email);
  }

  // Error handling function
  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Tutup',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  // Success message function
  void _showSuccess(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
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
        onPressed: () {
          Navigator.of(context).pop(); // Close dialog first
          onPressed();
        },
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
              // App Logo
              Image.asset(
                'assets/images/delpick_image.png',
                width: 250,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 250,
                    height: 150,
                    decoration: BoxDecoration(
                      color: GlobalStyle.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.delivery_dining,
                      size: 80,
                      color: GlobalStyle.primaryColor,
                    ),
                  );
                },
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
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        hintText: 'Masukkan email Anda',
                        prefixIcon: const Icon(Icons.email_outlined),
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
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        hintText: 'Masukkan kata sandi Anda',
                        prefixIcon: const Icon(Icons.lock_outlined),
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
                      onChanged: _isLoading ? null : (bool? value) {
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
                    // Demo button for testing
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
                  boxShadow: _isLoading ? [] : [
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

              // Additional info text
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}