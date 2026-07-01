import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Shared config for the PythonAnywhere backend.
class BackendApi {
  static String get baseUrl =>
      dotenv.env['BACKEND_API_URL'] ?? 'https://yourusername.pythonanywhere.com';

  static String get apiKey =>
      dotenv.env['API_SECRET_KEY'] ?? 'voicecard-secure-api-key-2026';

  static const String packageName = 'com.krpdev.voicecard';

  static Map<String, String> get headers => {
        'x-api-key': apiKey,
        'Content-Type': 'application/json',
      };
}
