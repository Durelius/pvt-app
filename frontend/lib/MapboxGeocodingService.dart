import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Address {   //adressklass för att underlätta backend call
  final String name;
  final double lat;
  final double lon;

  Address({
    required this.name,
    required this.lat,
    required this.lon,
  });
}

class MapboxGeocodingService {
    static final String token = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
    static const String baseUrl = 'https://api.mapbox.com/geocoding/v5/mapbox.places';

    Future<Address?> reverseGeocode(double lat, double lon) async {
      final uri = Uri.parse('$baseUrl/${lon.toStringAsFixed(6)},${lat.toStringAsFixed(6)}.json'
          '?access_token=$token'
          '&limit=1'
          '&types=address'
          '&language=sv',
      );
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List;
        if (features.isEmpty) return null;
        final f = features.first;
        final coords = f['geometry']['coordinates'] as List;
        return Address(
          name: f['place_name'] as String,
          lat: (coords[1] as num).toDouble(),
          lon: (coords[0] as num).toDouble(),
        );
      }
      return null;
    }

    Future<List<Address>> getSuggestions(String query) async{
      if (query.isEmpty) return [];

      final uri = Uri.parse('$baseUrl/${Uri.encodeComponent(query)}.json'
          '?access_token=$token'
          '&autocomplete=true'
          '&limit=5'
          '&language=sv'
          '&bbox=17.2,58.9,19.5,60.0',  // Stockholm + Uppsala län (exkl. Västerås, Grisslehamn)
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List;


        return features
            .where((f) => (f['place_type'] as List).contains('address'))
            .map((f) {
            final coords = f['geometry']['coordinates'] as List;
            return Address(
              name: f['place_name'] as String,
              lat: (coords[1] as num).toDouble(),
              lon: (coords[0] as num).toDouble(),
            );
          })

            .toList();
      
      
      }
      return[];
    }
}