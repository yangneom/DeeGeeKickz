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
import 'screens/auth/otp_screen.dart';
import 'providers/auth/auth_provider.dart';
import 'providers/customer/customer_cart_provider.dart';
import 'providers/customer/notification_provider.dart';
import 'screens/admin/admin_layout.dart';
import 'screens/super/super_layout.dart';
import 'screens/cashier/cashier_layout.dart';
import 'providers/customer/chat_provider.dart';


// Global navigator key — lets any file navigate without needing a
// local BuildContext that might get unmounted mid-flow (e.g. checkout
// screens that disappear the instant the cart clears).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

// Set to true right before the customer forgot-password flow calls
// verifyOTP(type: OtpType.recovery, ...), and back to false once that
// screen is done with it. Supabase fires the SAME passwordRecovery
// auth event for both staff invite links and customer password
// resets — this flag lets the global listener below tell the two
// apart, so it doesn't hijack the customer flow's own navigation.
bool isCustomerPasswordResetFlow = false;

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

  // On the actual app (not web), no Guest browsing — force Login/Sign Up
  // as the very first screen if nobody's logged in. Web keeps Guest
  // browsing, matching standard e-commerce behavior (browse freely,
  // login only required at checkout).
  if (!kIsWeb && user == null) {
    print('→ Non-web platform, no session — routing to LoginScreen');
    startScreen = const LoginScreen();
  }

  if (user != null) {
    try {
      final profile = await Supabase.instance.client
          .from('users')
          .select('password_set, role')
          .eq('id', user.id)
          .maybeSingle();

      print('POST-INIT PROFILE: $profile');

      if (profile == null) {
        // Session exists but no public.users row — signup never
        // completed (likely phone OTP failed or app closed mid-flow).
        // startScreen stays HomeScreen here; MyApp's initState checks
        // for this again once the ProviderScope is ready, and redirects
        // to resume registration at the phone step.
        print('→ Orphaned signup detected at startup, will resume in MyApp');
      } else {
        final passwordSet = profile['password_set'] as bool? ?? true;
        final role = profile['role'] as String? ?? 'Customer';

        print('password_set=$passwordSet | role=$role');

        if (!passwordSet &&
            (role == 'Admin' || role == 'Cashier' || role == 'Super Admin')) {
          print('→ Routing to SetPasswordScreen');
          startScreen = const SetPasswordScreen();
        } else if (passwordSet && role == 'Admin') {
          print('→ Routing to AdminLayout');
          startScreen = const AdminLayout();
        } else if (passwordSet && role == 'Super Admin') {
          print('→ Routing to SuperLayout');
          startScreen = const SuperLayout();
        } else if (passwordSet && role == 'Cashier') {
          print('→ Routing to CashierLayout');
          startScreen = const CashierLayout();
        }
        // role == 'Customer' → startScreen stays HomeScreen (correct)
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialCart();
      _checkForOrphanedSignup();
    });
  }

  Future<void> _loadInitialCart() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await ref.read(customerCartProvider.notifier).loadFromSupabase();
    } else {
      await ref.read(customerCartProvider.notifier).loadGuestCartFromLocal();
    }
  }

  // ── Detect and resume an orphaned signup ──
  // If a session exists but there's no matching public.users row, the
  // customer verified their email OTP but never finished phone
  // verification (SMS failed, or they closed the app). Recover their
  // name/phone from auth user metadata (saved at signUp() time) and
  // drop them back into the phone-verification step instead of letting
  // them fall through to HomeScreen as a broken account.
  Future<void> _checkForOrphanedSignup() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final profile = await Supabase.instance.client
          .from('users')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (profile != null) return; // profile exists, nothing to resume

      final meta = user.userMetadata;
      final firstName = meta?['first_name'] as String? ?? '';
      final lastName = meta?['last_name'] as String? ?? '';
      final phone = meta?['phone'] as String? ?? '';

      if (phone.isEmpty) {
        // Can't resume without a phone number to verify — this shouldn't
        // happen for anyone who signed up after this fix, but guards
        // against pre-fix orphaned accounts with no metadata to recover.
        print('Orphaned signup found but no phone metadata to resume with.');
        return;
      }

      print('Resuming orphaned signup for ${user.email}');

      ref.read(pendingRegistrationProvider.notifier).set(
        PendingRegistration(
          firstName: firstName,
          lastName: lastName,
          email: user.email ?? '',
          phone: phone,
        ),
      );

      if (!mounted) return;
      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const OtpVerificationScreen(startAtPhoneStep: true),
        ),
        (route) => false,
      );
    } catch (e) {
      print('Orphaned signup check error: $e');
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
        if (isCustomerPasswordResetFlow) {
          print('Skipping auto-navigation — customer reset flow handles its own screen.');
          return;
        }
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

          if (profile == null) {
            // Mid-signup — email verified but phone step / profile
            // creation isn't done yet. Don't merge the cart here; the
            // real merge happens once registration actually completes
            // (see otp_screen.dart) or on a normal future login.
            print('signedIn event fired mid-signup — skipping cart merge for now.');
          } else {
            final passwordSet = profile['password_set'] as bool? ?? true;
            final role = profile['role'] as String? ?? 'Customer';

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
          }

          // Force every notification feed to refetch fresh for
          // whichever account just signed in — otherwise Riverpod
          // keeps serving the PREVIOUS user's cached notification
          // state after switching accounts.
          ref.invalidate(notificationProvider);
          ref.invalidate(adminNotificationProvider);
          ref.invalidate(superAdminNotificationProvider);
          ref.invalidate(customerChatProvider);
          ref.invalidate(adminChatProvider);
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