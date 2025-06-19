import 'package:del_pick/Common/global_style.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Import services berdasarkan struktur baru
import 'package:del_pick/Services/Auth/auth_service.dart';
import 'package:del_pick/Services/Utils/auth_manager.dart';
import 'package:del_pick/Services/Utils/error_handler.dart';
import 'package:del_pick/Services/Utils/storage_service.dart';
import 'package:del_pick/Services/Utils/notification_service.dart';

// Import models
import 'package:del_pick/Models/Requests/auth_requests.dart';
import 'package:del_pick/Models/Validators/input_validators.dart';
import 'package:del_pick/Models/Exceptions/api_exception.dart';
import 'package:del_pick/Models/Enums/user_role.dart';

import 'dart:io';

import '../Controls/connectivy_service.dart';

class LoginPage extends StatefulWidget {
  static const String route = "/Controls/Login";
  const LoginPage({super.key});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool obscurePassword = true;
  bool rememberMe = false;

  late AnimationController _errorAnimationController;
  late Animation<double> _errorAnimation;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _setupAnimations();
    _checkSavedCredentials();
  }

  void _setupAnimations() {
    _errorAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _errorAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _errorAnimationController,
      curve: Curves.elasticOut,
    ));
  }

  Future<void> _initializeServices() async {
    try {
      await StorageService.init();
      await AuthManager.init();
      await NotificationService.init();
    } catch (e) {
      print('Error initializing services: $e');
    }
  }

  // Check for saved credentials on startup
  Future<void> _checkSavedCredentials() async {
    try {
      final String? savedEmail = StorageService.getString('remembered_email');
      final String? savedPassword = StorageService.getString('remembered_password');
      final bool? isRemembered = StorageService.getBool('is_remembered');

      if (savedEmail != null && savedPassword != null && isRemembered == true) {
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
    _errorAnimationController.dispose();
    super.dispose();
  }

  // Save or clear credentials based on Remember Me
  Future<void> _handleRememberMe() async {
    if (rememberMe) {
      await StorageService.saveString('remembered_email', emailController.text);
      await StorageService.saveString('remembered_password', passwordController.text);
      await StorageService.saveBool('is_remembered', true);
    } else {
      await StorageService.remove('remembered_email');
      await StorageService.remove('remembered_password');
      await StorageService.saveBool('is_remembered', false);
    }
  }

  // Login function using the new service structure
  Future<void> _login() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      _showCustomError('Mohon periksa kembali data yang Anda masukkan');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Check internet connectivity first
      bool hasConnection = await _checkInternetConnection();
      if (!hasConnection) {
        _showCustomError('Koneksi internet tidak tersedia. Silakan periksa koneksi Anda');
        return;
      }

      // Create login request
      final loginRequest = LoginRequest(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      // Make the API call using the new AuthService
      final response = await AuthService.login(loginRequest);

      if (response.isSuccess && response.data != null) {
        // Handle successful login
        await _handleSuccessfulLogin(response.data!);
      } else {
        // Handle API error
        _showCustomError(response.message.isNotEmpty
            ? _formatErrorMessage(response.message)
            : 'Terjadi kesalahan saat login. Silakan coba lagi');
      }
    } on ValidationException catch (e) {
      _showCustomError(_formatValidationError(e));
    } on UnauthorizedException catch (e) {
      _showCustomError('Email atau kata sandi yang Anda masukkan salah. Silakan periksa kembali');
    } on NetworkException catch (e) {
      _showCustomError('Gagal terhubung ke server. Periksa koneksi internet Anda');
    } on ApiException catch (e) {
      _showCustomError(_formatErrorMessage(e.message));
    } catch (e) {
      print("Unexpected error during login: $e");
      _showCustomError('Terjadi kesalahan yang tidak terduga. Silakan coba lagi');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSuccessfulLogin(loginResponse) async {
    try {
      // Save authentication data using AuthManager
      await AuthManager.saveAuthData(
        loginResponse.token,
        loginResponse.user,
      );

      // Handle Remember Me functionality
      await _handleRememberMe();

      // Update FCM token
      await NotificationService.updateFCMTokenOnServer();

      // Show success message
      _showSuccessMessage('Login berhasil! Selamat datang kembali');

      // Navigate based on user role
      _navigateBasedOnRole(loginResponse.user.role);

    } catch (e) {
      print("Error handling successful login: $e");
      _showCustomError('Login berhasil, tetapi terjadi kesalahan saat menyimpan data');
    }
  }

  void _navigateBasedOnRole(UserRole role) {
    String routeName;

    switch (role) {
      case UserRole.customer:
        routeName = '/Customers/HomePage';
        break;
      case UserRole.store:
        routeName = '/Store/HomePage';
        break;
      case UserRole.driver:
        routeName = '/Driver/HomePage';
        break;
      case UserRole.admin:
        routeName = '/Admin/HomePage';
        break;
      default:
        _showCustomError('Peran pengguna tidak dikenali');
        return;
    }

    // Navigate with delay for better UX
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, routeName);
      }
    });
  }

  String _formatErrorMessage(String message) {
    // Convert technical error messages to user-friendly ones
    if (message.toLowerCase().contains('invalid credentials') ||
        message.toLowerCase().contains('unauthorized') ||
        message.toLowerCase().contains('email atau password salah')) {
      return 'Email atau kata sandi yang Anda masukkan tidak valid. Silakan coba lagi';
    } else if (message.toLowerCase().contains('network') ||
        message.toLowerCase().contains('connection')) {
      return 'Masalah koneksi jaringan. Periksa internet Anda';
    } else if (message.toLowerCase().contains('server')) {
      return 'Server sedang mengalami gangguan. Silakan coba lagi nanti';
    }

    return message.isNotEmpty ? message : 'Terjadi kesalahan. Silakan coba lagi';
  }

  String _formatValidationError(ValidationException e) {
    if (e.validationErrors != null && e.validationErrors!.isNotEmpty) {
      final errors = e.validationErrors!;

      if (errors.containsKey('email')) {
        return 'Format email tidak valid. Silakan periksa kembali';
      } else if (errors.containsKey('password')) {
        return 'Kata sandi harus memiliki minimal 6 karakter';
      }

      // Return first validation error
      return errors.values.first.first;
    }

    return 'Data yang Anda masukkan tidak valid. Silakan periksa kembali';
  }

  // Check internet connection
  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  // Custom attractive error notification
  void _showCustomError(String message) {
    _errorAnimationController.forward().then((_) {
      _errorAnimationController.reverse();
    });

    // Show custom animated error dialog
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AnimatedBuilder(
          animation: _errorAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _errorAnimation.value,
              child: AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                backgroundColor: Colors.white,
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFEBEE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.error_outline,
                        color: Color(0xFFE53E3E),
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Oops! Terjadi Kesalahan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF4A5568),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GlobalStyle.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Mengerti',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Success message
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: GlobalStyle.newInfo,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Pilih Peran',
            style: TextStyle(
              color: GlobalStyle.primaryColor,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildRoleButton(
                  'Customers',
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
          foregroundColor: GlobalStyle.primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: GlobalStyle.primaryColor),
          ),
          elevation: 0,
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(icon, color: GlobalStyle.primaryColor),
            const SizedBox(width: 12),
            Text(
              'Masuk sebagai $role',
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
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Image.asset(
                  'assets/images/delpick_image.png',
                  width: 250,
                ),
                const SizedBox(height: 10),

                // Subtitle
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
                        validator: InputValidators.validateEmail,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            borderSide: BorderSide(color: GlobalStyle.primaryColor, width: 2),
                          ),
                          hintText: 'Masukkan email Anda',
                          prefixIcon: Icon(Icons.email_outlined, color: GlobalStyle.primaryColor),
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
                        validator: InputValidators.validatePassword,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            borderSide: BorderSide(color: GlobalStyle.primaryColor, width: 2),
                          ),
                          hintText: 'Masukkan kata sandi Anda',
                          prefixIcon: Icon(Icons.lock_outline, color: GlobalStyle.primaryColor),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: GlobalStyle.primaryColor,
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
                    borderRadius: BorderRadius.circular(30.0),
                    gradient: LinearGradient(
                      colors: [
                        GlobalStyle.primaryColor,
                        GlobalStyle.primaryColor.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: GlobalStyle.primaryColor.withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
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
                    style: TextButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                    ),
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

                const SizedBox(height: 20),

                // Debug/Dev Button (remove in production)
                if (const bool.fromEnvironment('dart.vm.product') == false)
                  TextButton(
                    onPressed: _showRoleSelectionDialog,
                    child: Text(
                      'Debug: Pilih Role',
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
      ),
    );
  }
}