import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:app_links/app_links.dart';

import 'screens/customer/homescreen/home_screen.dart';
import 'screens/customer/orders/order_history_screen.dart';
import 'screens/auth/set_password_screen.dart';
import 'screens/auth/login_screen.dart';
import 'providers/customer/customer_cart_provider.dart';

// Global navigator key — lets any file navigate without needing a
// local BuildContext that might get unmounted mid-flow (e.g. checkout
// screens that disappear the instant the cart clears).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

// ================================================
// MAIN FUNCTION
// ================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );

  print('Supabase initialized');

  Widget startScreen = const HomeScreen();

  final user = Supabase.instance.client.auth.currentUser;
  print('POST-INIT USER: ${user?.email}');

  if (user != null) {
    try {
      final profile = await Supabase.instance.client
          .from('users')
          .select('password_set, role')
          .eq('id', user.id)
          .maybeSingle();

      print('POST-INIT PROFILE: $profile');

      final passwordSet = profile?['password_set'] as bool? ?? true;
      final role = profile?['role'] as String? ?? 'Customer';

      print('password_set=$passwordSet | role=$role');

      if (!passwordSet &&
          (role == 'Admin' || role == 'Cashier' || role == 'Super Admin')) {
        print('→ Routing to SetPasswordScreen');
        startScreen = const SetPasswordScreen();
      }
    } catch (e) {
      print('Profile check error: $e');
    }
  }

  runApp(
    ProviderScope(
      child: MyApp(startScreen: startScreen),
    ),
  );
}

// ================================================
// MY APP
// ================================================
class MyApp extends ConsumerStatefulWidget {
  final Widget startScreen;
  const MyApp({super.key, required this.startScreen});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = appNavigatorKey;
  AppLinks? _appLinks;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initDeepLinks();
    }
    _listenForAuthEvents();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialCart());
  }

  Future<void> _loadInitialCart() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await ref.read(customerCartProvider.notifier).loadFromSupabase();
    } else {
      await ref.read(customerCartProvider.notifier).loadGuestCartFromLocal();
    }
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();
    _appLinks!.uriLinkStream.listen((Uri uri) {
      if (uri.scheme == 'dgeekickz') {
        if (uri.host == 'payment-success') {
          final orderId = uri.queryParameters['order'];
          print('Payment success for order: $orderId');
          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
            (route) => route.isFirst,
          );
        } else if (uri.host == 'payment-cancel') {
          print('Payment cancelled');
          _navigatorKey.currentState?.popUntil((route) => route.isFirst);
        }
      }
    });
  }

  void _listenForAuthEvents() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      print('AUTH EVENT: $event');

      if (session == null) {
        print('NO SESSION');
        return;
      }

      final user = session.user;
      print('USER: ${user.email}');

      if (event == AuthChangeEvent.passwordRecovery) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const SetPasswordScreen()),
            (route) => false,
          );
        });
        return;
      }

      if (event == AuthChangeEvent.signedIn) {
        try {
          final profile = await Supabase.instance.client
              .from('users')
              .select('password_set, role')
              .eq('id', user.id)
              .maybeSingle();

          print('PROFILE: $profile');

          final passwordSet = profile?['password_set'] as bool? ?? true;
          final role = profile?['role'] as String? ?? 'Customer';

          print('password_set=$passwordSet | role=$role');

          if (!passwordSet &&
              (role == 'Admin' || role == 'Cashier' || role == 'Super Admin')) {
            print('→ Navigating to SetPasswordScreen');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _navigatorKey.currentState?.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const SetPasswordScreen()),
                (route) => false,
              );
            });
          }

          await ref.read(customerCartProvider.notifier).mergeGuestCartIntoAccount();
        } catch (e) {
          print('Auth event profile check error: $e');
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
          navigatorKey: _navigatorKey,
          title: 'DeeGee Kickz',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
            useMaterial3: true,
          ),
          routes: {
            '/login': (context) => const LoginScreen(),
            '/set-password': (context) => const SetPasswordScreen(),
          },
          home: widget.startScreen,
        );
      },
    );
  }
}