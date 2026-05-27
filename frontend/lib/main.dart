import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mitten/location_service/location_service.dart';
import '/MapboxGeocodingService.dart';

import 'models/address_entry.dart';
import 'models/address_group.dart';

import 'pages/home.dart';
import 'pages/home_address_setup.dart';
import 'pages/login.dart';
import 'pages/plan.dart';
import 'pages/saved.dart';

//Imports for google sign in and location services
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

final FlutterLocalNotificationsPlugin notifications =
    FlutterLocalNotificationsPlugin();

const Color kPurple = Color(0xFF63519F);
const Color kNavDark = Color(0xFF2D1F5E);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await GoogleSignIn.instance.initialize(
    clientId: kIsWeb
        ? '169231317250-nc8otuvk6ic7cqii3sfdd4pbbp8ge9d7.apps.googleusercontent.com'
        : null,
  );
  if (kIsWeb) {
    GoogleSignIn.instance.attemptLightweightAuthentication();
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  await Hive.initFlutter();

  Hive.registerAdapter(AddressEntryAdapter());
  Hive.registerAdapter(AddressGroupAdapter());

  await Hive.openBox<AddressEntry>('addressEntries');
  await Hive.openBox('recentSearches');
  await Hive.openBox('savedGroups');
  await Hive.openBox('homeAddress');

  await notifications.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    ),
    macOS: DarwinInitializationSettings(),
    linux: LinuxInitializationSettings(defaultActionName: 'Open notification'),
  ));

  await dotenv.load(fileName: '.env');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mitten',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kPurple),
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
      ),
      routes: {
        '/': (_) => const LoginScreen(),
        '/main': (_) => const MainShell(),
        '/login': (_) => const LoginScreen(),
        '/setup': (_) => const HomeAddressSetupPage(),
      },
      initialRoute: '/',
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  AppLocation? _currentLocation;
  List<Address>? _prefilledAddresses;
  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _requestLocation();
    notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> _requestLocation() async {
    try {
      final loc = await _locationService.getCurrentLocation();
      if (mounted) setState(() => _currentLocation = loc);
    } catch (_) {
      // Location unavailable at startup — user can request it manually on the plan page.
    }
  }

  void _openPlanWithAddresses(List<Address> addresses) {
    setState(() {
      _prefilledAddresses = addresses;
      _currentIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomePage(),
      PlanPage(currentLocation: _currentLocation,
        prefilledAddresses: _prefilledAddresses,
      ),
      SavedPage(onOpenPlan: _openPlanWithAddresses),
    ];

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          pages[_currentIndex],
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(40, 0, 40, 8),
                child: _PillNav(
                  currentIndex: _currentIndex,
                  onTap: (i) => setState(() => _currentIndex = i),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _PillNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: kNavDark,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _NavItem(icon: Icons.home, label: 'Home', index: 0, currentIndex: currentIndex, onTap: onTap),
          _NavItem(icon: Icons.add_circle_outline_rounded, label: 'Plan', index: 1, currentIndex: currentIndex, onTap: onTap),
          _NavItem(icon: Icons.bookmark_rounded, label: 'Saved', index: 2, currentIndex: currentIndex, onTap: onTap),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = index == currentIndex;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Icon(
          icon,
          color: selected ? Colors.white : Colors.white38,
          size: 28,
        ),
      ),
    );
  }
}

