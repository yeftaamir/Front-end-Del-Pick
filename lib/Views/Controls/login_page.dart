import 'package:del_pick/Common/global_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:provider/provider.dart';
import '../../Services/ApiService.dart';
import 'connectivity_service.dart';

class LoginPage extends StatefulWidget {
  static const String route = "/Controls/Login";
  //
  const LoginPage({super.key});

  @override
  LoginPageState createState() => LoginPageState();
  // @override
  // createState() => LoginState();
}

class LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;
  final FlutterSecureStorage _storage = FlutterSecureStorage();
  bool obscurePassword = true;
  // final TextEditingController emailController = TextEditingController();
  // final TextEditingController passwordController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // Login function to handle authentication
  // Login function to handle authentication
  void _login() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Make the API call to login
      final loginResponse = await ApiService.login(
          emailController.text, passwordController.text);
      print("Full Response Body: $loginResponse"); // Debugging full response

      // Cek apakah response benar-benar memiliki 'token'
      if (loginResponse == null || !loginResponse.containsKey('token')) {
        print("Response is either null or does not contain 'token'");
        showError("Response data is null.");
        return;
      }

      // Ambil token langsung
      final String token = loginResponse['token'] ?? ''; // Akses token langsung

      if (token.isEmpty) {
        print("Token is empty or null.");
        showError("Token is null or empty.");
        return;
      }

      print("Decoded Token: $token");

      // Decode the token
      if (token.contains('.')) {
        final Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
        final String? role = decodedToken['role'];
        print("Decoded Role: $role");

        if (role == null || role.isEmpty) {
          showError("Role is missing in token.");
          return;
        }

        print("User Role: $role");

        // Navigate to the correct page based on the user's role
        if (role == 'customer') {
          Navigator.pushReplacementNamed(context, '/Customers/HomePage');
        } else if (role == 'store') {
          Navigator.pushReplacementNamed(context, '/Store/HomePage');
        } else if (role == 'driver') {
          Navigator.pushReplacementNamed(context, '/Driver/HomePage');
        } else {
          // Handle unknown role
          showError("Role not recognized");
        }
      } else {
        showError("Token tidak valid");
      }

    } catch (e) {
      print("Error: $e"); // Debugging error
      showError(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // void _login() async {
  //   setState(() {
  //     _isLoading = true;
  //   });
  //
  //   try {
  //     // Make the API call to login
  //     final loginResponse = await ApiService.login(
  //         emailController.text, passwordController.text);
  //     print("Response Body: $loginResponse");
  //
  //     // Cek apakah response benar-benar memiliki data dan token
  //     if (loginResponse == null || !loginResponse.containsKey('data')) {
  //       print("Response is either null or does not contain 'data'");
  //       showError("Response data is null.");
  //       // showError("Response data is null.");
  //       return;
  //     }
  //
  //     // // Check if the response contains token data
  //     // if (loginResponse['data'] == null || loginResponse['data']['token'] == null) {
  //     //   showError("Response data is null.");
  //     //   return;
  //     // }
  //
  //     final String token = loginResponse['data']['token'] ?? '';  // Correctly access the token
  //
  //     if (token.isEmpty) {
  //       showError("Token is null or empty.");
  //       return;
  //     }
  //
  //     print("Decoded Token: $token");
  //
  //     // Decode the token
  //     if (token.contains('.')) {
  //       final Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
  //       final String? role = decodedToken['role'];
  //       print("Decoded Role: $role");
  //
  //       if (role == null || role.isEmpty) {
  //         showError("Role is missing in token.");
  //         return;
  //       }
  //
  //       print("User Role: $role");
  //
  //       // Navigate to the correct page based on the user's role
  //       if (role == 'customer') {
  //         Navigator.pushReplacementNamed(context, '/Customers/HomePage');
  //       }
  //       else if (role == 'store') {
  //         Navigator.pushReplacementNamed(context, '/Store/HomePage');
  //       }
  //       else if (role == 'driver') {
  //         Navigator.pushReplacementNamed(context, '/Driver/HomePage');
  //       }
  //       else {
  //         // Handle unknown role
  //         showError("Role not recognized");
  //       }
  //     } else {
  //       showError("Token tidak valid");
  //     }
  //
  //   } catch (e) {
  //     // Handle error and show message
  //     showError(e.toString());
  //   } finally {
  //     setState(() {
  //       _isLoading = false;
  //     });
  //   }
  // }

  // void _login() async {
  //   setState(() {
  //     _isLoading = true;
  //   });
  //
  //   try {
  //     // Make the API call to login
  //     final loginResponse = await ApiService.login(
  //         emailController.text, passwordController.text);
  //     print(loginResponse);
  //
  //     // if (loginResponse['data'] == null) {
  //     //   showError("Response data is null.");
  //     //   return;
  //     // }
  //     if (loginResponse['token'] == null) {
  //       showError("Response data is null.");
  //       return;
  //     }
  //     // final String token = loginResponse['token'] ?? '';
  //
  //     final String token = loginResponse['data']['token'] ?? '';
  //
  //
  //     // final String token = loginResponse['data']['token'];  // Get the token
  //
  //
  //     if (token.isEmpty) {
  //       showError("Token is null or empty.");
  //       return;
  //     }
  //
  //     print("Decoded Token: $token");
  //
  //     // Decode the token
  //     if (token.contains('.')) {
  //       final Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
  //       final String? role = decodedToken['role'];
  //       print("Decoded Role: $role");
  //       if (role == null || role.isEmpty) {
  //         showError("Role is missing in token.");
  //         return;
  //       }
  //       print("User Role: $role");
  //
  //       // Navigate to the correct page based on the user's role
  //       if (role == 'customer') {
  //         Navigator.pushReplacementNamed(context, '/Customers/HomePage');
  //       }
  //       else if (role == 'store') {
  //         Navigator.pushReplacementNamed(context, '/Store/HomePage');
  //       }
  //       else if (role == 'driver') {
  //         Navigator.pushReplacementNamed(context, '/Driver/HomePage');
  //       }
  //       else {
  //         // Handle unknown role
  //         showError("Role not recognized");
  //       }
  //     } else {
  //       showError("Token tidak valid");
  //     }
  //
  //     // final Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
  //
  //     // Extract the role from the decoded token
  //     // final String role = decodedToken['role'];  // Assuming the role is in the token
  //
  //   } catch (e) {
  //     // Handle error and show message
  //     showError(e.toString());
  //   } finally {
  //     setState(() {
  //       _isLoading = false;
  //     });
  //   }
  // }

  // Error handling function
  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showRoleSelectionDialog() {
    // Periksa koneksi dari ConnectivityService
    final connectivityService = Provider.of<ConnectivityService>(context, listen: false);
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
                      () => Navigator.pushReplacementNamed(context, '/Customers/HomePage'),
                ),
                const SizedBox(height: 10),
                _buildRoleButton(
                  'Admin',
                  Icons.admin_panel_settings,
                      () => Navigator.pushReplacementNamed(context, '/Admin/HomePage'),
                ),
                const SizedBox(height: 10),
                _buildRoleButton(
                  'Driver',
                  Icons.delivery_dining,
                      () => Navigator.pushReplacementNamed(context, '/Driver/HomePage'),
                ),
                const SizedBox(height: 10),
                _buildRoleButton(
                  'Store',
                  Icons.store,
                      () => Navigator.pushReplacementNamed(context, '/Store/HomePage'),
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
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword ? Icons.visibility_off : Icons.visibility,
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
              const SizedBox(height: 30.0),

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
                ? const Center(child: CircularProgressIndicator())
                : TextButton(
                  // onPressed: _showRoleSelectionDialog,
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