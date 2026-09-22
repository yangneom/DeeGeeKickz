import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';

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
import 'screens/auth/mfa_enroll_screen.dart';
import 'screens/auth/mfa_challenge_screen.dart';

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
bool isOwnLoginInProgress = false;

// ================================================
// MAIN FUNCTION
// ================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: 'env.public');

  final hasSupabaseUrl = dotenv.env['SUPABASE_URL']?.isNotEmpty ?? false;
  final hasSupabaseAnonKey =
      dotenv.env['SUPABASE_ANON_KEY']?.isNotEmpty ?? false;

  if (!hasSupabaseUrl || !hasSupabaseAnonKey) {
    throw Exception(
      'Missing Supabase environment configuration. '
      'SUPABASE_URL present: $hasSupabaseUrl, '
      'SUPABASE_ANON_KEY present: $hasSupabaseAnonKey',
    );
  }

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );

  Widget startScreen = const HomeScreen();

  final user = Supabase.instance.client.auth.currentUser;

  // On the actual app (not web), no Guest browsing — force Login/Sign Up
  // as the very first screen if nobody's logged in. Web keeps Guest
  // browsing, matching standard e-commerce behavior (browse freely,
  // login only required at checkout).
  if (!kIsWeb && user == null) {
    startScreen = const LoginScreen();
  }

  if (user != null) {
    try {
      final profile = await Supabase.instance.client
          .from('users')
          .select('password_set, role')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null) {
        // Session exists but no public.users row — signup never
        // completed (likely phone OTP failed or app closed mid-flow).
        // startScreen stays HomeScreen here; MyApp's initState checks
        // for this again once the ProviderScope is ready, and redirects
        // to resume registration at the phone step.
      } else {
        final passwordSet = profile['password_set'] as bool? ?? true;
        final role = profile['role'] as String? ?? 'Customer';

        if (!passwordSet &&
            (role == 'Admin' || role == 'Cashier' || role == 'Super Admin')) {
          startScreen = const SetPasswordScreen();
        } else if (passwordSet &&
            (role == 'Admin' || role == 'Super Admin' || role == 'Cashier')) {
          final factors = await Supabase.instance.client.auth.mfa.listFactors();
          if (factors.totp.isEmpty) {
            startScreen = const MfaEnrollScreen();
          } else {
            final aal = await Supabase.instance.client.auth.mfa
                .getAuthenticatorAssuranceLevel();
            if (aal.currentLevel != AuthenticatorAssuranceLevels.aal2) {
              startScreen = MfaChallengeScreen(role: role, onVerified: () {});
            } else {
              startScreen = role == 'Admin'
                  ? const AdminLayout()
                  : role == 'Cashier'
                  ? const CashierLayout()
                  : const SuperLayout();
            }
          }
        }
        // role == 'Customer' → startScreen stays HomeScreen (correct)
      }
    } catch (e) {}
  }

  runApp(ProviderScope(child: MyApp(startScreen: startScreen)));
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
  Timer? _presenceHeartbeat;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initDeepLinks();
    }
    _listenForAuthEvents();
    _startPresenceHeartbeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialCart();
      _checkForOrphanedSignup();
    });
  }

  @override
  void dispose() {
    _presenceHeartbeat?.cancel();
    super.dispose();
  }

  // ================================================
  // PRESENCE HEARTBEAT
  // Updates last_active_at every 2 minutes while a session is open,
  // so "Online" in Customer Management reflects genuinely active
  // use — not just the moment someone happened to log in.
  // ================================================
  void _startPresenceHeartbeat() {
    _updateLastActive();
    _presenceHeartbeat = Timer.periodic(const Duration(minutes: 2), (_) {
      _updateLastActive();
    });
  }

  Future<void> _updateLastActive() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await Supabase.instance.client
          .from('users')
          .update({'last_active_at': DateTime.now().toIso8601String()})
          .eq('id', user.id);
    } catch (e) {}
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
        return;
      }

      ref
          .read(pendingRegistrationProvider.notifier)
          .set(
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
    } catch (e) {}
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();
    _appLinks!.uriLinkStream.listen((Uri uri) {
      if (uri.scheme == 'dgeekickz') {
        if (uri.host == 'payment-success') {
          final orderId = uri.queryParameters['order'];
          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
            (route) => route.isFirst,
          );
        } else if (uri.host == 'payment-cancel') {
          _navigatorKey.currentState?.popUntil((route) => route.isFirst);
        }
      }
    });
  }

  void _listenForAuthEvents() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      if (session == null) {
        return;
      }

      final user = session.user;

      if (event == AuthChangeEvent.passwordRecovery) {
        if (isCustomerPasswordResetFlow) {
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

            // AUDIT FIX: an invite/magic link opened in a FRESH browser tab
      // (exactly what clicking an email link does) establishes the
      // session as initialSession, not signedIn — Supabase Flutter's
      // SDK only fires signedIn for a transition WITHIN an already-
      // open app. initialSession had zero handling here at all, so
      // the correct password_set → SetPasswordScreen routing below
      // simply never ran for a freshly-opened invite link — the
      // session established fine (correct domain, no crash), but
      // nothing ever redirected to Set Password.
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.initialSession) {
        try {
          final profile = await Supabase.instance.client
              .from('users')
              .select('password_set, role, is_disabled')
              .eq('id', user.id)
              .maybeSingle();

          if (profile == null) {
            // Mid-signup — email verified but phone step / profile
            // creation isn't done yet. Don't merge the cart here; the
            // real merge happens once registration actually completes
            // (see otp_screen.dart) or on a normal future login.
          } else {
            final passwordSet = profile['password_set'] as bool? ?? true;
            final role = profile['role'] as String? ?? 'Customer';
            final isDisabled = profile['is_disabled'] as bool? ?? false;

            if (isDisabled) {
              // Suspended/banned account — login()'s own check runs
              // in parallel and will sign this session back out with
              // the real suspension reason shown on the login screen.
              // Without this guard, this listener was racing that
              // logout by navigating to Home/a role layout first,
              // which is why a suspended login sometimes landed on
              // the Guest/Home screen instead of showing the error —
              // same race class as the existing mobile-staff-block
              // case just below, just for a different condition.
            } else if (!passwordSet &&
                (role == 'Admin' ||
                    role == 'Cashier' ||
                    role == 'Super Admin')) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _navigatorKey.currentState?.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const SetPasswordScreen()),
                  (route) => false,
                );
              });
            } else if (!kIsWeb && role != 'Customer') {
              // Mobile app is Customer-only by design. login_form.dart's
              // own mobile-block check will sign this session back out
              // right after this listener runs — don't race it by
              // navigating to a staff layout that's about to be undone.
                                                       } else if (isOwnLoginInProgress) {
              // login_form.dart is ALREADY actively handling this exact
              // sign-in on this exact tab — this listener firing too
              // was the actual bug: it would push a completely fresh
              // MfaChallengeScreen via pushAndRemoveUntil, silently
              // discarding whatever the user had already typed/
              // submitted on the screen login_form.dart just showed.
              // Skip entirely here; only act for OTHER tabs' sessions.
            } else {
              Widget destination;
              if (role == 'Admin' ||
                  role == 'Super Admin' ||
                  role == 'Cashier') {
                final factors = await Supabase.instance.client.auth.mfa
                    .listFactors();
                final bool hasMfaEnrolled = factors.totp.isNotEmpty;

                if (!hasMfaEnrolled) {
                  destination = const MfaEnrollScreen();
                } else {
                  final aal = await Supabase.instance.client.auth.mfa
                      .getAuthenticatorAssuranceLevel();
                  if (aal.currentLevel != AuthenticatorAssuranceLevels.aal2) {
                    destination = MfaChallengeScreen(
                      role: role,
                      onVerified: () {
                        _navigatorKey.currentState?.pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => role == 'Admin'
                                ? const AdminLayout()
                                : role == 'Cashier'
                                ? const CashierLayout()
                                : const SuperLayout(),
                          ),
                          (route) => false,
                        );
                      },
                    );
                  } else {
                    destination = role == 'Admin'
                        ? const AdminLayout()
                        : role == 'Cashier'
                        ? const CashierLayout()
                        : const SuperLayout();
                  }
                }
              } else {
                destination = const HomeScreen();
              }
              // Merge BEFORE navigating, not concurrently with it —
              // previously, navigation was scheduled via
              // addPostFrameCallback while the cart merge ran at the
              // same time in the background, a genuine race between
              // two unrelated async operations.
              try {
                await ref
                    .read(customerCartProvider.notifier)
                    .mergeGuestCartIntoAccount();
              } catch (e) {
                // Don't block login over a cart-merge hiccup — the
                // account itself is still valid and logged in.
              }

              WidgetsBinding.instance.addPostFrameCallback((_) {
                _navigatorKey.currentState?.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => destination),
                  (route) => false,
                );
              });
            }
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
        } catch (e) {}
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
