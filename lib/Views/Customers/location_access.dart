import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:del_pick/Common/global_style.dart';

class LocationAccessScreen extends StatefulWidget {
  static const String route = "/Customers/LocationAccess";

  const LocationAccessScreen({Key? key, required Null Function(String location) onLocationSelected}) : super(key: key);

  @override
  State<LocationAccessScreen> createState() => _LocationAccessScreenState();
}

class _LocationAccessScreenState extends State<LocationAccessScreen> {
  bool _isLoading = false;
  String _locationStatus = '';
  String? _currentAddress;
  bool _locationError = false;

  Future<void> _requestLocationPermission() async {
    setState(() {
      _isLoading = true;
      _locationError = false;
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
      });

      Navigator.pop(context, {'address': _currentAddress});

    } catch (e) {
      setState(() {
        _locationError = true;
        _locationStatus = 'Error accessing location: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _enterLocationManually() {
    Navigator.pop(context, {
      'address': 'Depan gerbang Institut Teknologi Del, Sitoluama, Kec. Balige, Toba, Sumatera Utara 22381'
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
                Image.asset(
                  'assets/images/location_icon.png',
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
                const SizedBox(height: 24),
                Text(
                  'What is Your Location?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: GlobalStyle.fontColor,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'We need to know your location in order to suggest nearby services',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: GlobalStyle.disableColor,
                    fontFamily: GlobalStyle.fontFamily,
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
                      'Allow Location Access',
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
                      'Enter Location Manually',
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