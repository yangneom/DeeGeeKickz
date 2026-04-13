// Basic Flutter import - needed for every Flutter app
import 'package:flutter/material.dart';

// Firebase core import - needed to initialize Firebase
import 'package:firebase_core/firebase_core.dart';

// Riverpod import - needed for state management
// ProviderScope is the wrapper that makes Riverpod work
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ScreenUtil import - needed for responsive design
import 'package:flutter_screenutil/flutter_screenutil.dart';

// This is the file that FlutterFire generated for us
import 'firebase_options.dart';

// This is our Login screen
import 'screens/auth/login_screen.dart';

// ================================================
// MAIN FUNCTION
// This is the starting point of the whole app
// ================================================
void main() async {

  // Make sure Flutter is ready BEFORE we start Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // Try to connect to Firebase
  // We wrap this in try catch in case something goes wrong
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error) {
    // If Firebase fails to initialize print the error
    print('Firebase initialization failed: $error');
  }

  // Start the app
  // ProviderScope wraps the whole app
  // This is REQUIRED for Riverpod to work
  // Without this Riverpod providers will not work
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

// ================================================
// MY APP
// This is the root widget of the whole app
// Every other screen is inside this widget
// ================================================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {

    // ScreenUtilInit wraps the whole app
    // This makes everything inside responsive
    // It scales sizes based on the design size below
    return ScreenUtilInit(

      // We design for 375x812 which is standard iPhone size
      // ScreenUtil will automatically scale up for tablets
      // and scale down for smaller phones
      designSize: const Size(375, 812),

      // This allows text to adapt its size to the screen
      minTextAdapt: true,

      // This helps with split screen mode on tablets
      splitScreenMode: true,

      // Builder returns the actual app
      builder: (context, child) {
        return MaterialApp(

          // Name of the app
          title: 'DeeGee Kickz',

          // Remove the DEBUG banner on top right corner
          debugShowCheckedModeBanner: false,

          // Set the color theme of the whole app
          // We use black to match DeeGee Kickz design
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.black,
            ),
            useMaterial3: true,
          ),

          // The first screen the app shows is LoginScreen
          home: const LoginScreen(),
        );
      },
    );
  }
}