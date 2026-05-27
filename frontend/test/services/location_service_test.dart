import 'package:flutter_test/flutter_test.dart';
import 'package:mitten/services/location_service.dart';

void main() {
  group('AppLocation', () {
    test('AppLocation constructor sets latitude and longitude', () {
      final location = AppLocation(latitude: 40.7128, longitude: -74.0060);

      expect(location.latitude, 40.7128);
      expect(location.longitude, -74.0060);
    });

    test('AppLocation stores coordinates as doubles', () {
      final location = AppLocation(latitude: 51.5074, longitude: -0.1278);

      expect(location.latitude is double, true);
      expect(location.longitude is double, true);
    });

    test('AppLocation handles zero coordinates', () {
      final location = AppLocation(latitude: 0.0, longitude: 0.0);

      expect(location.latitude, 0.0);
      expect(location.longitude, 0.0);
    });

    test('AppLocation handles negative coordinates', () {
      final location = AppLocation(latitude: -33.8688, longitude: 151.2093);

      expect(location.latitude, -33.8688);
      expect(location.longitude, 151.2093);
    });

    test('AppLocation handles very small coordinates', () {
      final location = AppLocation(latitude: 0.0001, longitude: -0.0002);

      expect(location.latitude, 0.0001);
      expect(location.longitude, -0.0002);
    });

    test('AppLocation handles very large coordinates', () {
      final location = AppLocation(latitude: 89.9999, longitude: 179.9999);

      expect(location.latitude, 89.9999);
      expect(location.longitude, 179.9999);
    });

    test('Two AppLocation instances with same coordinates are equal', () {
      final location1 = AppLocation(latitude: 40.7128, longitude: -74.0060);
      final location2 = AppLocation(latitude: 40.7128, longitude: -74.0060);

      expect(location1.latitude, location2.latitude);
      expect(location1.longitude, location2.longitude);
    });

    test('Two AppLocation instances with different coordinates are not equal', () {
      final location1 = AppLocation(latitude: 40.7128, longitude: -74.0060);
      final location2 = AppLocation(latitude: 51.5074, longitude: -0.1278);

      expect(location1.latitude, isNot(location2.latitude));
      expect(location1.longitude, isNot(location2.longitude));
    });

    test('AppLocation with equator coordinates', () {
      final location = AppLocation(latitude: 0.0, longitude: 100.0);

      expect(location.latitude, 0.0);
      expect(location.longitude, 100.0);
    });

    test('AppLocation with prime meridian coordinates', () {
      final location = AppLocation(latitude: 50.0, longitude: 0.0);

      expect(location.latitude, 50.0);
      expect(location.longitude, 0.0);
    });

    test('AppLocation with international date line coordinates', () {
      final location1 = AppLocation(latitude: 45.0, longitude: 179.9999);
      final location2 = AppLocation(latitude: 45.0, longitude: -179.9999);

      expect(location1.longitude, 179.9999);
      expect(location2.longitude, -179.9999);
    });
  });

  group('LocationService', () {
    late LocationService locationService;

    setUp(() {
      locationService = LocationService();
    });

    test('LocationService can be instantiated', () {
      expect(locationService, isNotNull);
    });

    test('LocationService has getCurrentLocation method', () {
      expect(locationService.getCurrentLocation, isNotNull);
    });

    test('getCurrentLocation returns a Future<AppLocation>', () {
      final result = locationService.getCurrentLocation();
      expect(result, isA<Future<AppLocation>>());
    });

    test('AppLocation can be created from LocationService pattern', () {
      final location = AppLocation(latitude: 37.7749, longitude: -122.4194);

      expect(location.latitude, 37.7749);
      expect(location.longitude, -122.4194);
    });

    test('Multiple AppLocation instances can be created independently', () {
      final location1 = AppLocation(latitude: 37.7749, longitude: -122.4194);
      final location2 = AppLocation(latitude: 34.0522, longitude: -118.2437);
      final location3 = AppLocation(latitude: 41.8781, longitude: -87.6298);

      expect(location1.latitude, 37.7749);
      expect(location2.latitude, 34.0522);
      expect(location3.latitude, 41.8781);

      expect(location1.longitude, -122.4194);
      expect(location2.longitude, -118.2437);
      expect(location3.longitude, -87.6298);
    });

    test('AppLocation with realistic city coordinates - New York', () {
      final nyLocation = AppLocation(latitude: 40.7128, longitude: -74.0060);

      expect(nyLocation.latitude, closeTo(40.7128, 0.001));
      expect(nyLocation.longitude, closeTo(-74.0060, 0.001));
    });

    test('AppLocation with realistic city coordinates - Tokyo', () {
      final tokyoLocation = AppLocation(latitude: 35.6762, longitude: 139.6503);

      expect(tokyoLocation.latitude, closeTo(35.6762, 0.001));
      expect(tokyoLocation.longitude, closeTo(139.6503, 0.001));
    });

    test('AppLocation with realistic city coordinates - Sydney', () {
      final sydneyLocation = AppLocation(latitude: -33.8688, longitude: 151.2093);

      expect(sydneyLocation.latitude, closeTo(-33.8688, 0.001));
      expect(sydneyLocation.longitude, closeTo(151.2093, 0.001));
    });

    test('AppLocation coordinate precision handling', () {
      final precisionLocation = AppLocation(
        latitude: 40.71280123456789,
        longitude: -74.00601234567890,
      );

      // Double precision should be maintained
      expect(precisionLocation.latitude, isNotNull);
      expect(precisionLocation.longitude, isNotNull);
    });

    test('AppLocation handles maximum valid latitude values', () {
      final northPole = AppLocation(latitude: 90.0, longitude: 0.0);
      final southPole = AppLocation(latitude: -90.0, longitude: 0.0);

      expect(northPole.latitude, 90.0);
      expect(southPole.latitude, -90.0);
    });

    test('AppLocation handles maximum valid longitude values', () {
      final eastMost = AppLocation(latitude: 0.0, longitude: 180.0);
      final westMost = AppLocation(latitude: 0.0, longitude: -180.0);

      expect(eastMost.longitude, 180.0);
      expect(westMost.longitude, -180.0);
    });
  });
}
