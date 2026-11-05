import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../widgets/liquid_blob.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();

  int _currentPage = 0;

  final List<Map<String, String>> _pages = const [
    {
      'image': 'assets/images/NutriPal Mascot2.png',
      'title': 'Scan nutrition labels',
      'description': 'Capture or upload a nutrition label in seconds.',
    },
    {
      'image': 'assets/images/NutriPal Mascot3.png',
      'title': 'Understand what it means',
      'description':
          'Get personalised insights based on your health goals.',
    },
    {
      'image': 'assets/images/NutriPal Mascot1.png',
      'title': 'Make informed choices',
      'description': 'Compare products and choose what works for you.',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // =========================
  // NEXT PAGE
  // =========================
  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _goToLogin();
    }
  }

  // =========================
  // GO TO LOGIN
  // =========================
  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F2E9),
      body: SafeArea(
        child: Column(
          children: [
            // =========================
            // SKIP BUTTON
            // =========================
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: 8,
                  right: 20,
                ),
                child: TextButton(
                  onPressed: _goToLogin,
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      color: Color(0xFF77718F),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            // =========================
            // ONBOARDING PAGES
            // =========================
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final page = _pages[index];

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                    ),
                    child: Column(
                      children: [
                        // =========================
                        // IMAGE + LIQUID BACKGROUND
                        // =========================
                        Expanded(
                          child: Center(
                            child: SizedBox(
                              width: 400,
                              height: 450,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Animated liquid blob
                                  const LiquidBlob(
                                    size: 360,
                                  ),

                                  // Mascot image
                                  Image.asset(
                                    page['image']!,
                                    width: 330,
                                    height: 330,
                                    fit: BoxFit.contain,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // =========================
                        // TITLE
                        // =========================
                        Text(
                          page['title']!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF4B2E83),
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            height: 1.15,
                          ),
                        ),

                        const SizedBox(height: 14),

                        // =========================
                        // DESCRIPTION
                        // =========================
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                          ),
                          child: Text(
                            page['description']!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF666075),
                              fontSize: 17,
                              height: 1.4,
                            ),
                          ),
                        ),

                        const SizedBox(height: 25),
                      ],
                    ),
                  );
                },
              ),
            ),

            // =========================
            // PAGE DOT INDICATORS
            // =========================
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) {
                  final bool selected =
                      index == _currentPage;

                  return AnimatedContainer(
                    duration: const Duration(
                      milliseconds: 250,
                    ),
                    curve: Curves.easeInOut,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 5,
                    ),
                    width: selected ? 16 : 12,
                    height: selected ? 16 : 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? const Color(0xFF4B2E83)
                          : const Color(0xFFE1D6F4),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 28),

            // =========================
            // NEXT / GET STARTED
            // =========================
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 34,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFF4B2E83),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor:
                        const Color(0x334B2E83),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    _currentPage == _pages.length - 1
                        ? 'Get Started'
                        : 'Next',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}