import 'package:flutter/material.dart';
import 'package:mitten/pages/home.dart';
import 'package:mitten/pages/plan.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


final FlutterLocalNotificationsPlugin notifications = 
FlutterLocalNotificationsPlugin();


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const AndroidInitializationSettings androidSettings = 
  AndroidInitializationSettings('@mipmap/ic_launcher');
  
  const InitializationSettings initSettings = 
  InitializationSettings(android: androidSettings);

  await notifications.initialize(initSettings);


  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

Future<void> showTestNotification() async {
  await notifications.show(
    0,
    'Testnotis',
    'Detta är en lokal testnotis',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'test_channel',
        'Testkanal', 
        importance: Importance.max,
        priority: Priority.high,
      ),
    ),
  );
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState(){
    super.initState();
    notifications.resolvePlatformSpecificImplementation<
    AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
  } 
  int currentPageIndex = 0;
  String heading = "Mitten Prototype Page";
  int savedBadgeCount = 1;

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: showTestNotification,
            tooltip: 'Visa testnotis',
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
          });
        },
        indicatorColor: Color(0xFF99D98C),
        selectedIndex: currentPageIndex,
        destinations: <Widget>[
          NavigationDestination(
            selectedIcon: Icon(Icons.home),
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          NavigationDestination(
            icon:  Icon(Icons.add),
            label: 'Plan',
          ),
          NavigationDestination(
            icon: Badge(label: Text('$savedBadgeCount'), child: const Icon(Icons.bookmark)),
            label: 'Saved',
          ),
        ],
      ),
      body: <Widget>[
        // homepage from home.dart
        HomePage(onIncrement: () => setState(() => savedBadgeCount++)),
        // this is the planning page
        const PlanPage(),
        // this is the saved page
        Card(
          color: Colors.transparent,
          shadowColor: Colors.transparent,
          margin: const EdgeInsets.all(8.0),
          child: SizedBox.expand(
            child: Center(
              child: Text(' $savedBadgeCount new saved locations', style: theme.textTheme.titleLarge),
            ),
          ),
        ),
      ][currentPageIndex],
    );
  }
}

