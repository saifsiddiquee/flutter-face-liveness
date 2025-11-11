import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:liveness_app/home_page.dart';
import 'package:liveness_app/models/user_profile.dart';
import 'package:path_provider/path_provider.dart';

import 'services/tf_lite_service.dart';

Future<void> main() async {
  // Ensure all Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local database
  final appDocumentDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentDir.path);

  // Register our UserProfile adapter
  // You MUST run "flutter pub run build_runner build" after this
  Hive.registerAdapter(UserProfileAdapter());

  // Open our database "boxes". We'll create a box to store user profiles.
  await Hive.openBox<UserProfile>('userBox');

  // Load the TFLite model on startup
  await TfliteService().loadModel();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Liveness App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pinkAccent),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          centerTitle: true,
          elevation: 2,
        ),
      ),
      home: const HomePage(),
    );
  }
}
