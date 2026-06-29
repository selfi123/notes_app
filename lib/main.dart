import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/storage/hive_storage.dart';
import 'core/services/notification_service.dart';
import 'core/services/iap_service.dart';
import 'core/services/ad_service.dart';
import 'package:firebase_core/firebase_core.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Hive
  await HiveStorage.init();
  await NotificationService.init();

  // Initialize Firebase (Assuming flutterfire configure was run)
  await Firebase.initializeApp();
  
  // Initialize Monetization & Ads
  await IapService.init();
  await AdService.init();

  runApp(
    const ProviderScope(
      child: VoicecardApp(),
    ),
  );
}
