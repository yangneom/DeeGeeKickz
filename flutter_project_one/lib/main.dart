// Basic Flutter import - needed for every Flutter app
import 'package:flutter/material.dart';

// Supabase import - replaces Firebase
import 'package:supabase_flutter/supabase_flutter.dart';

// Riverpod import - needed for state management
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ScreenUtil import - needed for responsive design
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Environment variables
import 'package:flutter_dotenv/flutter_dotenv.dart';

// This is our Login screen
import 'screens/auth/login_screen.dart';



// ================================================
// MAIN FUNCTION
// ================================================
void main() async {

  // Make sure Flutter is ready before we do anything
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env file first
  await dotenv.load(fileName: '.env');

  print('URL = ${dotenv.env['SUPABASE_URL']}');
  print('KEY = ${dotenv.env['SUPABASE_ANON_KEY']}');

  // Initialize Supabase
  try {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
    print('Supabase initialized successfully');
  } catch (error) {
    print('Supabase initialization failed: $error');
  }

  // Start the app
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

// ================================================
// MY APP
// ================================================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'DeeGee Kickz',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.black,
            ),
            useMaterial3: true,
          ),
          home: const LoginScreen(),
        );
      },
    );
  }
}