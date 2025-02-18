import 'package:flutter/material.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ProfilePage extends StatelessWidget {
  static const String route = "/Customers/Profile";

  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Header dengan judul terpusat
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

              // Foto profil dengan border
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: GlobalStyle.primaryColor,
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: GlobalStyle.lightColor,
                  child: Icon(
                    Icons.person,
                    size: 60,
                    color: GlobalStyle.primaryColor,
                  ),
                ),
              ),

              const SizedBox(height: 32),

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
                      title: 'Nama User',
                      value: 'John Doe',
                    ),
                    const Divider(height: 1, indent: 20),
                    _buildInfoTile(
                      icon: FontAwesomeIcons.phone,
                      title: 'Nomor Telepon',
                      value: '+62 812 3456 7890',
                    ),
                    const Divider(height: 1, indent: 20),
                    _buildInfoTile(
                      icon: FontAwesomeIcons.envelope,
                      title: 'Email User',
                      value: 'johndoe@example.com',
                    ),
                  ],
                ),
              ),
            ],
          ),
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
        ],
      ),
    );
  }
}