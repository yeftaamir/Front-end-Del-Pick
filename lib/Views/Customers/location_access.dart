import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:del_pick/Common/global_style.dart';
import 'package:lottie/lottie.dart'; // Add this import for Lottie animations
import 'package:audioplayers/audioplayers.dart'; // Add this import for audio playback

class LocationAccessScreen extends StatefulWidget {
  static const String route = "/Customers/LocationAccess";

  final Function(String location)? onLocationSelected;

  const LocationAccessScreen({Key? key, this.onLocationSelected}) : super(key: key);

  @override
  State<LocationAccessScreen> createState() => _LocationAccessScreenState();
}

class _LocationAccessScreenState extends State<LocationAccessScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String _locationStatus = '';
  String? _currentAddress;
  bool _locationError = false;
  bool _showAnimation = false;

  // Create an audio player instance
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

// In LocationAccessScreen.dart
  Future<void> _requestLocationPermission() async {
    setState(() {
      _isLoading = true;
      _locationError = false;
      _showAnimation = false;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = true;
          _locationStatus = 'Location services are disabled';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationError = true;
            _locationStatus = 'Location permission denied';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError = true;
          _locationStatus = 'Location permissions are permanently denied';
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Here you would normally use a geocoding service to get the address
      // For this example, we'll return a fixed address
      setState(() {
        _currentAddress = 'Depan gerbang Institut Teknologi Del, Sitoluama, Kec. Balige, Toba, Sumatera Utara 22381';
        _showAnimation = true;
      });

      // Play the sound when location is found
      await _audioPlayer.play(AssetSource('audio/found.wav'));

      // Wait for animation to play before navigating back
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.pop(context, {
          'address': _currentAddress,
          'latitude': position.latitude,
          'longitude': position.longitude
        });
      }

    } catch (e) {
      setState(() {
        _locationError = true;
        _locationStatus = 'Error accessing location: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _enterLocationManually() {
    // For manual entry, we'll use a fixed location (Del Institute coordinates)
    // In a real app, this would open an address input form
    Navigator.pop(context, {
      'address': 'Depan gerbang Institut Teknologi Del, Sitoluama, Kec. Balige, Toba, Sumatera Utara 22381',
      'latitude': 2.3833,  // Approximate coordinates for IT Del
      'longitude': 99.1483
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_showAnimation)
                // Show animation when location is found
                  Lottie.asset(
                    'assets/animations/location_access.json',
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                    repeat: true,
                  )
                else
                  Image.asset(
                    'assets/images/location_icon.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                const SizedBox(height: 24),
                Text(
                  _showAnimation ? 'Lokasi Ditemukan!' : 'Dimana lokasi Anda?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: GlobalStyle.fontColor,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                const SizedBox(height: 12),
                if (!_showAnimation)
                  Text(
                    'Kami perlu mengetahui lokasi Anda untuk menyarankan layanan terdekat',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: GlobalStyle.disableColor,
                      fontFamily: GlobalStyle.fontFamily,
                    ),
                  ),
                if (_showAnimation && _currentAddress != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      _currentAddress!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: GlobalStyle.fontColor,
                        fontFamily: GlobalStyle.fontFamily,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                if (_currentAddress == null)
                  ElevatedButton(
                    onPressed: _isLoading ? null : _requestLocationPermission,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GlobalStyle.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : Text(
                      'Izinkan Akses Lokasi',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: GlobalStyle.fontFamily,
                        fontSize: GlobalStyle.fontSize,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                if (_currentAddress == null)
                  GestureDetector(
                    onTap: _enterLocationManually,
                    child: Text(
                      'Masukkan Lokasi Secara Manual',
                      style: TextStyle(
                        color: GlobalStyle.primaryColor,
                        fontFamily: GlobalStyle.fontFamily,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                if (_locationError)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _locationStatus,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.red,
                        fontFamily: GlobalStyle.fontFamily,
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