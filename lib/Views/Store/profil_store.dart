import 'package:flutter/material.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ProfileStorePage extends StatelessWidget {
  static const String route = "/Store/Profile";

  const ProfileStorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header dengan judul terpusat
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
                      icon: FaIcon(
                        FontAwesomeIcons.arrowLeft,
                        color: GlobalStyle.primaryColor,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Store Image
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(0),
                  bottom: Radius.circular(16),
                ),
                child: Image.network(
                  'https://storage.googleapis.com/a1aa/image/5Cq_e1zvmarYJk2l1nLIWCqWm-vE7i5hHEUmyboR2mo.jpg',
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),

              const SizedBox(height: 32),

              // Container informasi profil
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
                        value: 'Toko Indonesia',
                      ),
                      const Divider(height: 1, indent: 20),
                      _buildInfoTile(
                        icon: FontAwesomeIcons.star,
                        title: 'Penilaian',
                        value: '4.8 dari 5',
                      ),
                      const Divider(height: 1, indent: 20),
                      _buildInfoTile(
                        icon: FontAwesomeIcons.phone,
                        title: 'Nomor Telepon',
                        value: '+62 8132635487',
                      ),
                      const Divider(height: 1, indent: 20),
                      _buildInfoTile(
                        icon: FontAwesomeIcons.box,
                        title: 'Jumlah Produk',
                        value: '10 Produk',
                      ),
                      const Divider(height: 1, indent: 20),
                      _buildInfoTile(
                        icon: FontAwesomeIcons.circleInfo,
                        title: 'Keterangan',
                        value: 'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
                        isDescription: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
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