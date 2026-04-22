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

  Future<List<String>> getSuggestions(String query) async{
    Future<List<Address>> getSuggestions(String query) async{
      if (query.isEmpty) return [];

      final uri = Uri.parse('$baseUrl/${Uri.encodeComponent(query)}.json'
        @@ -27,9 +39,22 @@ class MapboxGeocodingService {
        if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List;


        return features
            .map((f) => f['place_name'] as String)
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
        23 changes: 11 additions & 12 deletions23
        frontend/lib/pages/plan.dart
        Original file line number	Diff line number	Diff line change
        @@ -19,11 +19,11 @@ class _PlanPageState extends State<PlanPage> {

        //Mapbox API
        final MapboxGeocodingService geocoding = MapboxGeocodingService();
        List<String> suggestions = [];
        List<Address> suggestions = [];


        //addresses stored
        final List<String> addresses = [];
        final List<Address> addresses = [];

        void onTextChanged(String value) {
        debouncer.debounce(
        @@ -46,7 +46,7 @@ Future<void> findMiddle() async {
        if (addresses.isEmpty) return;

        final response = await http.post(
        Uri.parse('http://10.0.2.2:8080/api/middle'),
        Uri.parse('http://localhost:8080/api/mitten/v1/middleplaces'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'addresses': addresses}),
        );
        @@ -63,10 +63,7 @@ Future<void> findMiddle() async {
        ),
        );
        }



        void selectSuggestion(String address){
        void selectSuggestion(Address address){
        setState(() {
        addresses.add(address);
        suggestions = [];
        @@ -76,8 +73,10 @@ Future<void> findMiddle() async {

        void addItem(){
        if (controller.text.trim().isEmpty) return;
        if (suggestions.isEmpty) return;
        setState(() {
        addresses.add(controller.text.trim());
        addresses.add(suggestions.first);
        suggestions = [];
        controller.clear();
        });
        }
        @@ -114,7 +113,7 @@ Future<void> findMiddle() async {
        itemCount: suggestions.length,
        itemBuilder: (context, index) => ListTile(
        leading: const Icon(Icons.location_on),
        title: Text(suggestions[index]),
        title: Text(suggestions[index].name.toString()),
        onTap: () => selectSuggestion(suggestions[index]),
        ),
        ),
        @@ -128,15 +127,15 @@ Future<void> findMiddle() async {
        child: ListView.builder(
        itemCount: addresses.length,
        itemBuilder: (context, index) => ListTile(
        title: Text(addresses[index]),
        title: Text(addresses[index].name.toString()),
        ),
        ),
        ),

        if (addresses.length >1)
        ElevatedButton(
        onPressed: () { //todo: kalla pa find middle
        },
        onPressed: findMiddle //todo: kalla pa find middle
        ,
        child: const Text('Find the middle!')
        ),
        const SizedBox(width: 8),