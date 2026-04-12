// This imports the basic Flutter tools we need to build the app
import 'package:flutter/material.dart';

// This imports Firebase so we can connect to it
import 'package:firebase_core/firebase_core.dart';

// This imports the config file that FlutterFire generated for us
import 'firebase_options.dart';

// This is the STARTING POINT of your app
// "async" means this function can wait for things to finish (like Firebase loading)
void main() async {

  // This makes sure Flutter is ready BEFORE we start Firebase
  // Always needed when doing something before runApp()
  WidgetsFlutterBinding.ensureInitialized();

  // This connects your Flutter app to your Firebase project
  // "await" means "wait for this to finish before moving on"
  await Firebase.initializeApp(
    // This automatically picks the right config depending on the platform
    // Android uses android config, iOS uses iOS config, etc.
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // This starts your Flutter app after Firebase is ready
  runApp(const MyApp());
}

// This is your main App widget — think of it as the "root" of your app
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // The name of your app
      title: 'Sales & Inventory with Ordering System',

      // This removes the "DEBUG" banner on the top right corner
      debugShowCheckedModeBanner: false,

      // This sets the color theme of your whole app
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),

      // This is the first screen your app shows
      // Just a temporary screen to test if Firebase is connected
      home: const Scaffold(
        body: Center(
          child: Text('Firebase Connected!'),
        ),
      ),
    );
  }
}