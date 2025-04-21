import 'package:del_pick/Common/global_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:provider/provider.dart';
import 'package:del_pick/services/auth_service.dart';
import 'package:del_pick/services/core/token_service.dart';
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

  // Login function to handle authentication with improved error handling
  void _login() async {
    // Check if the input fields are not empty
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      showError("Email dan kata sandi tidak boleh kosong.");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Check internet connectivity first
      bool hasConnection = await _checkInternetConnection();
      if (!hasConnection) {
        showError("Tidak ada koneksi internet. Silakan periksa koneksi Anda.");
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Make the API call to login using AuthService
      final loginResponse = await AuthService.login(
          emailController.text, passwordController.text);

      // Handle Remember Me functionality
      await _handleRememberMe();

      // Check if response is valid
      if (loginResponse == null || !loginResponse.containsKey('token')) {
        showError("Gagal login: Data respons tidak valid.");
        return;
      }

      // Get token
      final String token = loginResponse['token'] ?? '';

      if (token.isEmpty) {
        showError("Gagal login: Token kosong atau tidak valid.");
        return;
      }

      print("Login berhasil, token diterima");

      // Save token
      await TokenService.saveToken(token);

      // Decode the token
      if (token.contains('.')) {
        final Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
        final String? role = decodedToken['role'];

        if (role == null || role.isEmpty) {
          showError("Peran tidak ditemukan dalam token.");
          return;
        }

        print("User Role: $role");

        // Save user role
        await TokenService.saveUserRole(role);

        // Save user data if available
        if (loginResponse.containsKey('user')) {
          await _storage.write(
              key: 'user_profile',
              value: loginResponse['user'].toString());
        }

        // Navigate to the correct page based on the user's role
        if (role == 'customer') {
          Navigator.pushReplacementNamed(context, '/Customers/HomePage');
        } else if (role == 'store') {
          Navigator.pushReplacementNamed(context, '/Store/HomePage');
        } else if (role == 'driver') {
          Navigator.pushReplacementNamed(context, '/Driver/HomePage');
        } else {
          // Handle unknown role
          showError("Peran tidak dikenali");
        }
      } else {
        showError("Token tidak valid");
      }
    } on SocketException catch (e) {
      print("Socket Error: $e");
      showError("Gagal terhubung ke server. Silakan periksa koneksi internet Anda.");
    } on HttpException catch (e) {
      print("HTTP Error: $e");
      showError("Terjadi kesalahan pada server. Silakan coba lagi nanti.");
    } on FormatException catch (e) {
      print("Format Error: $e");
      showError("Format respons tidak valid. Silakan hubungi administrator.");
    } catch (e) {
      print("Error: $e");
      showError("Terjadi kesalahan: ${e.toString()}");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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

  // Error handling function
  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showRoleSelectionDialog() {
    // Periksa koneksi dari ConnectivityService
    final connectivityService =
    Provider.of<ConnectivityService>(context, listen: false);
    if (!connectivityService.isConnected) {
      return; // Tidak perlu menampilkan dialog, karena overlay akan muncul otomatis
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Select Role',
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

              // Email Label + Field
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
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20.0),

              // Password Label + Field
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
                  ],
                ),
              ),

              const SizedBox(height: 20.0),

              // Login Button
              Container(
                width: screenWidth * 0.5,
                height: 50.0,
                decoration: BoxDecoration(
                  color: GlobalStyle.primaryColor,
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
            ],
          ),
        ),
      ),
    );
  }
}