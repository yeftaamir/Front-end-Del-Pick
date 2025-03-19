import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:del_pick/Common/global_style.dart';
import 'connectivity_service.dart';

// Widget Wrapper untuk menangani tampilan offline
class InternetConnectivityWrapper extends StatefulWidget {
  final Widget child;

  const InternetConnectivityWrapper({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<InternetConnectivityWrapper> createState() => _InternetConnectivityWrapperState();
}

class _InternetConnectivityWrapperState extends State<InternetConnectivityWrapper> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (context, connectivityService, _) {
        // Tampilkan child jika terkoneksi atau overlay jika tidak terkoneksi
        return Stack(
          children: [
            widget.child,
            if (!connectivityService.isConnected)
              _buildNoInternetOverlay(context, connectivityService),
          ],
        );
      },
    );
  }

  // Overlay yang ditampilkan saat tidak ada koneksi internet
  Widget _buildNoInternetOverlay(BuildContext context, ConnectivityService service) {
    return Material(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Menampilkan animasi loading atau animasi tidak ada internet
            _isLoading
                ? Lottie.asset(
              'assets/animations/loading_animation.json',
              width: 250,
              height: 250,
              fit: BoxFit.contain,
            )
                : Lottie.asset(
              'assets/animations/no_internet.json',
              width: 250,
              height: 250,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            if (!_isLoading) ...[
              const Text(
                'Tidak ada koneksi internet',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Silakan periksa koneksi internet Anda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlobalStyle.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                onPressed: () async {
                  // Tampilkan animasi loading
                  setState(() {
                    _isLoading = true;
                  });

                  // Periksa konektivitas
                  await service.checkConnectivity();

                  // Delay singkat untuk memastikan animasi loading terlihat
                  await Future.delayed(const Duration(seconds: 2));

                  // Kembalikan ke tampilan awal jika masih tidak ada koneksi
                  if (!service.isConnected) {
                    setState(() {
                      _isLoading = false;
                    });
                  }
                },
                child: const Text(
                  'Coba Lagi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}