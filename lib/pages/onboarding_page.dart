import 'package:flutter/material.dart';
import 'login_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: 'Never Miss a\nDose',
      description:
          'MediTrack sends smart reminders for every medication, tracks your stock, and alerts you when it\'s time to refill.',
      imagePath: 'assets/images/onboarding1.png',
      themeColor: const Color(0xFF2B72D0), // Blue
      buttonText: 'Get Started',
    ),
    OnboardingData(
      title: 'Smart Stock &\nRefills',
      description:
          'Track how many pills you have left. Get refill alerts before you run out. Never scramble for medicine last minute.',
      imagePath: 'assets/images/onboarding2.png',
      themeColor: const Color(0xFF3EC8A8), // Teal/Green
      buttonText: 'Next',
    ),
    OnboardingData(
      title: 'Track & Share\nProgress',
      description:
          'Share your health history with doctors or family members. Keep your loved ones in the loop with secure data syncing.',
      imagePath: 'assets/images/onboarding3.png',
      themeColor: const Color(0xFF5C6BC0), // Indigo/Purple
      buttonText: 'Get Started',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  void _onNext() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const LoginPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeThemeColor = _pages[_currentPage].themeColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FD),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Top Image Section (taking 45% of height)
            Builder(
              builder: (context) {
                final height = MediaQuery.of(context).size.height * 0.45;
                return SizedBox(
                  height: height,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      PageView.builder(
                        controller: _pageController,
                        onPageChanged: _onPageChanged,
                        itemCount: _pages.length,
                        itemBuilder: (context, index) {
                          return Image.asset(
                            _pages[index].imagePath,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: height,
                            alignment: Alignment.center,
                            errorBuilder: (context, error, stackTrace) {
                              // Fallback in case of image load error
                              return Container(
                                color: Color.fromARGB(25, (_pages[index].themeColor.r * 255).round(), (_pages[index].themeColor.g * 255).round(), (_pages[index].themeColor.b * 255).round()),
                                child: Center(
                                  child: Icon(
                                    Icons.medical_services_outlined,
                                    size: 100,
                                    color: _pages[index].themeColor,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      // Skip Button
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 16,
                        right: 20,
                        child: TextButton(
                          onPressed: _navigateToLogin,
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0x4D000000),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          child: const Text(
                            'Skip',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Page Indicator Dots
            Container(
              margin: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    height: 8,
                    width: _currentPage == index ? 24 : 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? activeThemeColor
                          : const Color(0xFFB0C4DE),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),

            // Text & Buttons Section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Title and Description
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            Text(
                              _pages[_currentPage].title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D1B2A),
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _pages[_currentPage].description,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF5C6B73),
                                height: 1.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Navigation Action Buttons (At the bottom)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Primary Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _onNext,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: activeThemeColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _pages[_currentPage].buttonText,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Secondary Link
                          GestureDetector(
                            onTap: _navigateToLogin,
                            child: RichText(
                              text: TextSpan(
                                text: 'Already have an account? ',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF5C6B73),
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Sign In',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: activeThemeColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String description;
  final String imagePath;
  final Color themeColor;
  final String buttonText;

  OnboardingData({
    required this.title,
    required this.description,
    required this.imagePath,
    required this.themeColor,
    required this.buttonText,
  });
}
