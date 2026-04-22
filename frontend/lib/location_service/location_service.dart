import 'package:flutter/foundation.dart';
import 'package:location/location.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:geocoding/geocoding.dart' as geocoding;

class LocationService {
  Future<AppLocation> getCurrentLocation() async{
    if(kIsWeb){
     geolocator.Position position = await _getLocationWeb();
     return AppLocation(latitude: position.latitude, longitude: position.longitude);
    }else{
     LocationData locationData = await _getLocationPhone();
     return AppLocation(latitude: locationData.latitude!, longitude: locationData.longitude!);
    }
  }

  Future<geolocator.Position> _getLocationWeb() async{
    bool serviceEnabled;
    geolocator.LocationPermission permission;

    serviceEnabled = await geolocator.Geolocator.isLocationServiceEnabled();
    if(!serviceEnabled){
      return Future.error('Location services are disabled');
    }

    permission = await geolocator.Geolocator.checkPermission();
    if(permission == geolocator.LocationPermission.denied){
      permission = await geolocator.Geolocator.requestPermission();
      if(permission == geolocator.LocationPermission.denied){
        return Future.error('Location permissions are denied');
      }
    }
    if(permission == geolocator.LocationPermission.deniedForever){
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    }
    return await geolocator.Geolocator.getCurrentPosition();
  }
  Future<LocationData> _getLocationPhone() async{
    Location location = Location();
    
    bool serviceEnabled;
    PermissionStatus permissionGranted;
    LocationData locationData;

    serviceEnabled = await location.serviceEnabled();
    if(!serviceEnabled){
      serviceEnabled = await location.requestService();
      if(!serviceEnabled){
        return Future.error('Location services are disabled');
      }
    }

    permissionGranted = await location.hasPermission();
    if(permissionGranted == PermissionStatus.denied){
      permissionGranted = await location.requestPermission();
      if(permissionGranted != PermissionStatus.granted){
        return Future.error('Location permissions are denied');
      }
    }
    locationData = await location.getLocation();
    debugPrint(locationData.altitude.toString());
    return locationData;
  }
  //Hittar addressen baserat på koordinaterna
  Future<List<geocoding.Placemark>> calculatedAddress(AppLocation appLocation) async{
    List<geocoding.Placemark> placemarks = await geocoding.placemarkFromCoordinates(appLocation.latitude, appLocation.longitude);
    if(placemarks.isNotEmpty){
      geocoding.Placemark place = placemarks.first;
      debugPrint('Address: ${place.street}, ${place.locality}, ${place.country}');
    }else{
      debugPrint('No address found for the given coordinates.');
    }
    return placemarks;
  }
}

class AppLocation{
    final double latitude;
    final double longitude;
    
    AppLocation({required this.latitude, required this.longitude});
}

