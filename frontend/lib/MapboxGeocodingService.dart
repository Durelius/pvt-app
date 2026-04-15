import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MapboxGeocodingService {
    static final String token = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
    static const String baseUrl = 'https://api.mapbox.com/geocoding/v5/mapbox.places';

    Future<List<String>> getSuggestions(String query) async{
      if (query.isEmpty) return [];

      final uri = Uri.parse('$baseUrl/${Uri.encodeComponent(query)}.json'
          '?access_token=$token'
          '&autocomplete=true'
          '&limit=5'
          '&language=sv',  // svenska förslag
      );

      print('Token: $token');           // är token laddad?
      print('URL: $uri');                // ser URL korrekt ut?

      final response = await http.get(uri);

      print('Status: ${response.statusCode}');   // 200 = ok, 401 = fel token
      print('Svar: ${response.body}');           // vad säger API:et?

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List;
        return features
            .map((f) => f['place_name'] as String)
            .toList();
      }
      return[];
    }
}