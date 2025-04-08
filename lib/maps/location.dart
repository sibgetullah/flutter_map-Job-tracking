import 'package:flutter/material.dart';
import 'package:location/location.dart';

class LocationPermissionPage extends StatefulWidget {
  @override
  _LocationPermissionPageState createState() => _LocationPermissionPageState();
}

class _LocationPermissionPageState extends State<LocationPermissionPage> {
  Location location = Location();
  LocationData? _currentLocation;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
  }

  /// Konum iznini kontrol et ve konum bilgilerini al
  Future<void> _checkLocationPermission() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    // Konum servisinin açık olup olmadığını kontrol et
    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = 'Konum servisi kapalı. Lütfen açın.';
        });
        return;
      }
    }

    // Konum iznini kontrol et
    permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        setState(() {
          _errorMessage = 'Konum izni reddedildi.';
        });
        return;
      }
    }

    // Konum bilgilerini al
    _getCurrentLocation();
  }

  /// Mevcut konumu al
  Future<void> _getCurrentLocation() async {
    try {
      final locationData = await location.getLocation();
      setState(() {
        _currentLocation = locationData;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Konum bilgisi alınamadı: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Konum İzni ve Bilgisi'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_errorMessage.isNotEmpty)
              Text(
                _errorMessage,
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
            if (_currentLocation != null)
              Text(
                'Enlem: ${_currentLocation!.latitude}\nBoylam: ${_currentLocation!.longitude}',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _getCurrentLocation,
              child: Text('Konumu Yenile'),
            ),
          ],
        ),
      ),
    );
  }
}