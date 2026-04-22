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