import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alarm/alarm.dart';
import 'constants/supabase_config.dart';
import 'pages/onboarding_page.dart';
import 'pages/home_page.dart';
import 'pages/forgot_password_page.dart';
import 'pages/ringing_page.dart';
import 'services/alarm_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await AlarmService.init();

  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
  } catch (e) {
    debugPrint('Supabase initialization failed: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<AlarmSettings>? _ringSubscription;

  @override
  void initState() {
    super.initState();
    _ringSubscription = Alarm.ringStream.stream.listen((alarmSettings) {
      _navigateToRingingPage(alarmSettings);
    });
  }

  @override
  void dispose() {
    _ringSubscription?.cancel();
    super.dispose();
  }

  void _navigateToRingingPage(AlarmSettings settings) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => RingingPage(alarmSettings: settings),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'MediTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SplashPage(),
    );
  }
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  StreamSubscription<AuthState>? _authSubscription;
  bool _isRecoveringPassword = false;

  @override
  void initState() {
    super.initState();

    // Listen to password recovery deep link callback event
    try {
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        if (data.event == AuthChangeEvent.passwordRecovery) {
          _isRecoveringPassword = true;
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const ForgotPasswordPage(initialStep: 2),
              ),
            );
          }
        }
      });
    } catch (_) {
      // Ignore if Supabase is not initialized (e.g. in tests)
    }

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();

    // Navigate to HomePage if user is logged in, else OnboardingPage
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && !_isRecoveringPassword) {
        Session? session;
        try {
          session = Supabase.instance.client.auth.currentSession;
        } catch (_) {
          // Fallback to null session when Supabase is not initialized (e.g., in widget tests)
        }
        final targetPage = session != null ? const HomePage() : const OnboardingPage();
        
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => targetPage,
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color(0xFF0F2B48), // Deep Dark Blue
              Color(0xFF1E6FB3), // Royal Blue
              Color(0xFF2FD5AA), // Teal/Green
            ],
            stops: [0.1, 0.5, 0.9],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Faint heart decoration in the background
            Positioned(
              top: MediaQuery.of(context).size.height * 0.35,
              child: Opacity(
                opacity: 0.04,
                child: const Icon(
                  Icons.favorite,
                  size: 280,
                  color: Colors.white,
                ),
              ),
            ),
            // Main content
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 3),
                      // White logo card
                      Container(
                        width: 145,
                        height: 145,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(36),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0x26000000),
                              blurRadius: 25,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Center(
                          child: ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [
                                Color(0xFF1E6FB3),
                                Color(0xFF2FD5AA),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            child: const Icon(
                              Icons.monitor_heart_rounded,
                              size: 78,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),
                      // MediTrack Title
                      const Text(
                        'MediTrack',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Subtitle
                      Text(
                        'Your Health. Your Control.',
                        style: TextStyle(
                          color: const Color(0xBFFFFFFF),
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Separator pill
                      Container(
                        width: 45,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: const Color(0x4DFFFFFF),
                          borderRadius: BorderRadius.circular(2.25),
                        ),
                      ),
                      const Spacer(flex: 3),
                      // Version at bottom
                      Text(
                        'Version 1.0',
                        style: TextStyle(
                          color: const Color(0x80FFFFFF),
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
