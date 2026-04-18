import 'package:flutter/foundation.dart';
import 'package:location/location.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
Future<AppLocation> getCurrentLocation() async{
    if(kIsWeb){
     Position position = await _getLocationWeb();
     return AppLocation(latitude: position.latitude, longitude: position.longitude);
    }else{
     LocationData locationData = await _getLocationPhone();
     return AppLocation(latitude: locationData.latitude!, longitude: locationData.longitude!);
    }
  }

  Future<Position> _getLocationWeb() async{
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if(!serviceEnabled){
      return Future.error('Location services are disabled');
    }

    permission = await Geolocator.checkPermission();
    if(permission == LocationPermission.denied){
      permission = await Geolocator.requestPermission();
      if(permission == LocationPermission.denied){
        return Future.error('Location permissions are denied');
      }
    }
    if(permission == LocationPermission.deniedForever){
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    }
    return await Geolocator.getCurrentPosition();
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
    return locationData;
  }
}

class AppLocation{
    final double latitude;
    final double longitude;
    
    AppLocation({required this.latitude, required this.longitude});
}