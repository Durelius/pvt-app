import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<AppLocation> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException('Location services are disabled. Please enable them in your device settings.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationException('Location permission was denied.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationException('Location permission is permanently denied. Please enable it in your device settings.');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return AppLocation(latitude: position.latitude, longitude: position.longitude);
  }
}

class AppLocation {
  final double latitude;
  final double longitude;

  AppLocation({required this.latitude, required this.longitude});
}

class LocationException implements Exception {
  final String message;
  LocationException(this.message);

  @override
  String toString() => message;
}
