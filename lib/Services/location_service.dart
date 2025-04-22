import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:del_pick/Services/driver_service.dart';

class LocationService {
  // Singleton instance
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Timer for periodic location updates
  Timer? _locationUpdateTimer;

  // Current position
  Position? _currentPosition;

  // Status flags
  bool _isTracking = false;
  bool _isPermissionGranted = false;

  // For logging and debugging
  final bool _enableLogging = true;

  // Getters
  bool get isTracking => _isTracking;
  Position? get currentPosition => _currentPosition;

  // Initialize location service
  Future<bool> initialize() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _log('Location services are disabled');
      return false;
    }

    // Check location permission status
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _log('Location permissions denied');
        _isPermissionGranted = false;
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _log('Location permissions permanently denied');
      _isPermissionGranted = false;
      return false;
    }

    // Also check permission_handler for more granular control
    var status = await Permission.location.status;
    if (!status.isGranted) {
      status = await Permission.location.request();
      _isPermissionGranted = status.isGranted;
    } else {
      _isPermissionGranted = true;
    }

    _log('Location service initialized, permission: $_isPermissionGranted');
    return _isPermissionGranted;
  }

  // Start tracking location at set intervals
  Future<bool> startTracking() async {
    if (_isTracking) {
      _log('Already tracking location');
      return true;
    }

    // Check for permissions
    if (!_isPermissionGranted) {
      bool initialized = await initialize();
      if (!initialized) {
        _log('Failed to initialize location service');
        return false;
      }
    }

    // Get current position first
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high
      );

      // Send initial position to backend
      await _sendLocationUpdate();

      // Setup periodic location updates (every 10 seconds)
      _locationUpdateTimer = Timer.periodic(
          const Duration(seconds: 10),
              (_) => _updateLocation()
      );

      _isTracking = true;
      _log('Started location tracking with timer');
      return true;
    } catch (e) {
      _log('Error starting location tracking: $e');
      return false;
    }
  }

  // Stop tracking location
  void stopTracking() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
    _isTracking = false;
    _log('Location tracking stopped');
  }

  // Update location once (called from timer)
  Future<void> _updateLocation() async {
    try {
      // Get current position
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high
      );

      // Update stored position
      _currentPosition = position;

      // Send to backend
      await _sendLocationUpdate();
    } catch (e) {
      _log('Error updating location: $e');
    }
  }

  // Send location update to backend
  Future<void> _sendLocationUpdate() async {
    if (_currentPosition == null) {
      _log('No position available to send');
      return;
    }

    try {
      await DriverService.updateDriverLocation({
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
      });

      _log('Location sent to backend: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
    } catch (e) {
      _log('Error sending location to backend: $e');
    }
  }

  // Force a location update immediately (can be called manually)
  Future<bool> forceLocationUpdate() async {
    try {
      await _updateLocation();
      return true;
    } catch (e) {
      _log('Error forcing location update: $e');
      return false;
    }
  }

  // Show location permission dialog
  Future<void> showLocationPermissionDialog(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Izin Lokasi Diperlukan'),
          content: const Text(
              'Untuk mengaktifkan status driver, aplikasi memerlukan akses lokasi. '
                  'Mohon berikan izin lokasi di pengaturan perangkat Anda.'
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Buka Pengaturan'),
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }

  // Get last known position or current position
  Future<Position?> getLastKnownPosition() async {
    try {
      if (_currentPosition != null) {
        return _currentPosition;
      }

      // Try to get last known position if current isn't available
      Position? lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        _currentPosition = lastKnown;
        return lastKnown;
      }

      // If no last known, get current
      _currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high
      );
      return _currentPosition;
    } catch (e) {
      _log('Error getting position: $e');
      return null;
    }
  }

  // Helper for logging
  void _log(String message) {
    if (_enableLogging) {
      print('LocationService: $message');
    }
  }

  // Dispose resources
  void dispose() {
    stopTracking();
  }
}