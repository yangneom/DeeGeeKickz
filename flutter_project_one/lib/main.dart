import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:app_links/app_links.dart';

import 'screens/customer/homescreen/home_screen.dart';
import 'screens/customer/orders/order_history_screen.dart';

// ================================================
// MAIN FUNCTION
// ================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  print('URL = ${dotenv.env['SUPABASE_URL']}');
  print('KEY = ${dotenv.env['SUPABASE_ANON_KEY']}');

  try {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
    print('Supabase initialized successfully');
    final user = Supabase.instance.client.auth.currentUser;
    print('CURRENT USER: ${user?.email}');
  } catch (error) {
    print('Supabase initialization failed: $error');
  }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

// ================================================
// MY APP
// ================================================
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  AppLinks? _appLinks;

  @override
  void initState() {
    super.initState();
    // Only set up deep links on mobile — not needed on web
    if (!kIsWeb) {
      _initDeepLinks();
    }
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();
    _appLinks!.uriLinkStream.listen((Uri uri) {
      if (uri.scheme == 'dgeekickz') {
        if (uri.host == 'payment-success') {
          final orderId = uri.queryParameters['order'];
          print('GCash payment success for order: $orderId');
          // Navigate to order history
          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const OrderHistoryScreen(),
            ),
            (route) => route.isFirst,
          );
        } else if (uri.host == 'payment-cancel') {
          final orderId = uri.queryParameters['order'];
          print('GCash payment cancelled for order: $orderId');
          // Just go back to home
          _navigatorKey.currentState?.popUntil((route) => route.isFirst);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          navigatorKey: _navigatorKey, // ← needed for deep link navigation
          title: 'DeeGee Kickz',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.black,
            ),
            useMaterial3: true,
          ),
          home: const HomeScreen(),
        );
      },
    );
  }
}