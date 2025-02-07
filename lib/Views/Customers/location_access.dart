import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:del_pick/Common/global_style.dart';

class LocationAccessScreen extends StatefulWidget {
  static const String route = "/Customers/LocationAccess";

  const LocationAccessScreen({Key? key}) : super(key: key);

  @override
  State<LocationAccessScreen> createState() => _LocationAccessScreenState();
}

class _LocationAccessScreenState extends State<LocationAccessScreen> {
  bool _isLoading = false;
  String _locationStatus = '';
  String? _currentAddress;
  bool _locationError = false;
  final TextEditingController _addressController = TextEditingController();

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    setState(() {
      _isLoading = true;
      _locationError = false;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        setState(() {
          _currentAddress =
          'Lat ${position.latitude}, Lon ${position.longitude}';
          _locationStatus = 'Location accessed successfully';
        });
      } else {
        setState(() {
          _locationError = true;
          _locationStatus = 'Location permission denied';
        });
      }
    } catch (e) {
      setState(() {
        _locationError = true;
        _locationStatus = 'Error accessing location';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _enterLocationManually() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Enter Location Manually',
          style: TextStyle(
            fontFamily: GlobalStyle.fontFamily,
            color: GlobalStyle.fontColor,
          ),
        ),
        content: TextField(
          controller: _addressController,
          decoration: InputDecoration(
            hintText: 'Enter your address',
            hintStyle: TextStyle(
              fontFamily: GlobalStyle.fontFamily,
              color: GlobalStyle.fontColor,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: GlobalStyle.borderColor),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close the dialog
            },
            child: Text(
              'Cancel',
              style: TextStyle(
                color: GlobalStyle.primaryColor,
                fontFamily: GlobalStyle.fontFamily,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _saveManualAddress();
              Navigator.pop(context); // Close the dialog
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: GlobalStyle.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text(
              'Save Address',
              style: TextStyle(
                color: Colors.white,
                fontFamily: GlobalStyle.fontFamily,
                fontSize: GlobalStyle.fontSize + 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _saveManualAddress() {
    setState(() {
      _currentAddress = _addressController.text;
      _locationStatus = 'Manual location entered';
      _locationError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
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
              // Conditional button or address display
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
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                    'Allow Location Access',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: GlobalStyle.fontFamily,
                      fontSize: GlobalStyle.fontSize,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: GlobalStyle.lightColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on, color: GlobalStyle.primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        _currentAddress!,
                        style: TextStyle(
                          color: GlobalStyle.fontColor,
                          fontFamily: GlobalStyle.fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              // Manual location entry
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
              const SizedBox(height: 16),
              // Error message in red
              if (_locationError)
                Text(
                  _locationStatus,
                  style: TextStyle(
                    color: Colors.red,
                    fontFamily: GlobalStyle.fontFamily,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
