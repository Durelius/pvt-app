const bool _dev = bool.fromEnvironment('DEV', defaultValue: false);
const String apiBase = _dev ? 'http://localhost:8080/api' : 'https://tidochplats.se/api';
