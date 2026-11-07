import 'package:flutter/material.dart';
import 'user_profile_form.dart';

class SuccessfulSignupScreen extends StatefulWidget {
  const SuccessfulSignupScreen({super.key});

  @override
  State<SuccessfulSignupScreen> createState() =>
      _SuccessfulSignupScreenState();
}

class _SuccessfulSignupScreenState
    extends State<SuccessfulSignupScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _floatController;

  late Animation<double> _successScale;
  late Animation<double> _successFade;

  late Animation<double> _mascotFade;
  late Animation<double> _mascotScale;
  late Animation<Offset> _mascotSlide;

  late Animation<double> _headingFade;
  late Animation<Offset> _headingSlide;

  late Animation<double> _subtitleFade;
  late Animation<Offset> _subtitleSlide;

  late Animation<double> _cardFade;
  late Animation<Offset> _cardSlide;

  late Animation<double> _buttonFade;
  late Animation<double> _buttonScale;

  late Animation<double> _floatMovement;
  late Animation<double> _rotation;

  @override
  void initState() {
    super.initState();

    // =========================
    // ENTRANCE ANIMATION
    // =========================
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 3600,
      ),
    );

    // =========================
    // SUCCESS LABEL
    // =========================
    _successScale = Tween<double>(
      begin: 0.80,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(
          0.00,
          0.10,
          curve: Curves.easeOutBack,
        ),
      ),
    );

    _successFade = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: 1,
        ),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 0,
        ),
        weight: 25,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(
          0.00,
          0.48,
        ),
      ),
    );

    // =========================
    // MASCOT ENTRANCE
    // =========================
    _mascotFade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(
          0.12,
          0.42,
          curve: Curves.easeOut,
        ),
      ),
    );

    _mascotScale = Tween<double>(
      begin: 0.80,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(
          0.12,
          0.42,
          curve: Curves.easeOutBack,
        ),
      ),
    );

    _mascotSlide = Tween<Offset>(
      begin: const Offset(
        0,
        0.08,
      ),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(
          0.12,
          0.42,
          curve: Curves.easeOutBack,
        ),
      ),
    );

    // =========================
    // HEADING
    // =========================
    _headingFade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(
          0.38,
          0.56,
          curve: Curves.easeOut,
        ),
      ),
    );

    _headingSlide = Tween<Offset>(
      begin: const Offset(
        0,
        0.16,
      ),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(
          0.38,
          0.56,
          curve: Curves.easeOut,
        ),
      ),
    );

    // =========================
    // SUBTITLE
    // =========================
    _subtitleFade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(
          0.50,
          0.68,
          curve: Curves.easeOut,
        ),
      ),
    );

    _subtitleSlide = Tween<Offset>(
      begin: const Offset(
        0,
        0.14,
      ),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(
          0.50,
          0.68,
          curve: Curves.easeOut,
        ),
      ),
    );

    // =========================
    // CARD
    // =========================
    _cardFade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(
          0.62,
          0.82,
          curve: Curves.easeOut,
        ),
      ),
    );

    _cardSlide = Tween<Offset>(
      begin: const Offset(
        0,
        0.12,
      ),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(
          0.62,
          0.82,
          curve: Curves.easeOut,
        ),
      ),
    );

    // =========================
    // BUTTON
    // =========================
    _buttonFade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(
          0.76,
          1.00,
          curve: Curves.easeOut,
        ),
      ),
    );

    _buttonScale = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(
          0.76,
          1.00,
          curve: Curves.easeOutBack,
        ),
      ),
    );

    // =========================
    // CONTINUOUS FLOATING
    // =========================
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 3400,
      ),
    );

    _floatMovement = Tween<double>(
      begin: -5,
      end: 5,
    ).animate(
      CurvedAnimation(
        parent: _floatController,
        curve: Curves.easeInOut,
      ),
    );

    _rotation = Tween<double>(
      begin: -0.010,
      end: 0.010,
    ).animate(
      CurvedAnimation(
        parent: _floatController,
        curve: Curves.easeInOut,
      ),
    );

    _entranceController.forward();

    Future.delayed(
      const Duration(
        milliseconds: 3600,
      ),
      () {
        if (!mounted) return;

        _floatController.repeat(
          reverse: true,
        );
      },
    );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _floatController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFFF7F2E9,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 20,
          ),
          child: Column(
            children: [
              const SizedBox(
                height: 8,
              ),

              // =========================
              // SUCCESS LABEL
              // =========================
              FadeTransition(
                opacity: _successFade,
                child: ScaleTransition(
                  scale: _successScale,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFFE4F8F5,
                      ),
                      borderRadius: BorderRadius.circular(
                        30,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: Color(
                            0xFF17B6B1,
                          ),
                          size: 21,
                        ),
                        SizedBox(
                          width: 8,
                        ),
                        Text(
                          'Account created successfully!',
                          style: TextStyle(
                            color: Color(
                              0xFF168986,
                            ),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              // =========================
              // MASCOT AREA
              // =========================
              FadeTransition(
                opacity: _mascotFade,
                child: ScaleTransition(
                  scale: _mascotScale,
                  child: SlideTransition(
                    position: _mascotSlide,
                    child: AnimatedBuilder(
                      animation: _floatController,
                      builder: (
                        context,
                        child,
                      ) {
                        return Transform.translate(
                          offset: Offset(
                            0,
                            _floatMovement.value,
                          ),
                          child: Transform.rotate(
                            angle: _rotation.value,
                            child: child,
                          ),
                        );
                      },
                      child: SizedBox(
                        width: double.infinity,
                        height: 330,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Soft purple background
                            Container(
                              width: 300,
                              height: 300,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Color(
                                      0xFFE9DEFF,
                                    ),
                                    Color(
                                      0xFFF3ECFF,
                                    ),
                                    Color(
                                      0x00F3ECFF,
                                    ),
                                  ],
                                  stops: [
                                    0.25,
                                    0.70,
                                    1.0,
                                  ],
                                ),
                              ),
                            ),

                            // Mascot
                            Image.asset(
                              'assets/images/NutriPal Mascot8.png',
                              width: 300,
                              height: 300,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 4,
              ),

              // =========================
              // TITLE
              // =========================
              FadeTransition(
                opacity: _headingFade,
                child: SlideTransition(
                  position: _headingSlide,
                  child: const Text(
                    'Welcome to NutriPal!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(
                        0xFF4B2E83,
                      ),
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 16,
              ),

              // =========================
              // SUBTITLE
              // =========================
              FadeTransition(
                opacity: _subtitleFade,
                child: SlideTransition(
                  position: _subtitleSlide,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12,
                    ),
                    child: Text(
                      'Let’s personalise your nutrition insights so NutriPal can guide you better.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(
                          0xFF756D7E,
                        ),
                        fontSize: 17,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 30,
              ),

              // =========================
              // NEXT UP CARD
              // =========================
              FadeTransition(
                opacity: _cardFade,
                child: SlideTransition(
                  position: _cardSlide,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        28,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: 0.07,
                          ),
                          blurRadius: 16,
                          offset: const Offset(
                            0,
                            7,
                          ),
                        ),
                      ],
                    ),
                    child: const Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Next up',
                          style: TextStyle(
                            color: Color(
                              0xFF4B2E83,
                            ),
                            fontSize: 23,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        SizedBox(
                          height: 12,
                        ),

                        Text(
                          'Tell us about your health goals for more relevant guidance.',
                          style: TextStyle(
                            color: Color(
                              0xFF756D7E,
                            ),
                            fontSize: 17,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Space above the button (moved a little lower).
              const SizedBox(
                height: 56,
              ),

              // =========================
              // LET'S GET STARTED
              // =========================
              FadeTransition(
                opacity: _buttonFade,
                child: ScaleTransition(
                  scale: _buttonScale,
                  child: SizedBox(
                    width: double.infinity,
                    height: 62,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const UserProfileForm(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(
                          0xFF4B2E83,
                        ),
                        foregroundColor: Colors.white,
                        elevation: 5,
                        shadowColor: const Color(
                          0x334B2E83,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            32,
                          ),
                        ),
                      ),
                      child: const Text(
                        'Let’s Get Started',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 15,
              ),
            ],
          ),
        ),
      ),
    );
  }
}