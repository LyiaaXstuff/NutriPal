import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/onboarding_service.dart';
import '../widgets/progress_dialog.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import 'verify_email_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
  });

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // =====================================================
  // CONTROLLERS
  // =====================================================

  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  // =====================================================
  // FOCUS NODES
  // =====================================================

  final FocusNode _emailFocusNode =
      FocusNode();

  final FocusNode _passwordFocusNode =
      FocusNode();

  // =====================================================
  // STATES
  // =====================================================

  bool _obscurePassword = true;

  bool _isPasswordFocused = false;

  bool _rememberMe = false;

  // =====================================================
  // MASCOT ANIMATION
  // =====================================================

  late AnimationController _floatController;

  late Animation<double> _floatAnimation;

  // =====================================================
  // INIT
  // =====================================================

  @override
  void initState() {
    super.initState();

    // Reaching Login means onboarding is done (Get Started
    // or Skip), so the next app start goes straight here.
    OnboardingService.markSeen();

    _passwordFocusNode.addListener(() {
      if (!mounted) {
        return;
      }

      setState(() {
        _isPasswordFocused =
            _passwordFocusNode.hasFocus;
      });
    });

    _floatController =
        AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 1400,
      ),
    )..repeat(
        reverse: true,
      );

    _floatAnimation =
        Tween<double>(
      begin: -6,
      end: 6,
    ).animate(
      CurvedAnimation(
        parent: _floatController,
        curve: Curves.easeInOut,
      ),
    );
  }

  // =====================================================
  // DISPOSE
  // =====================================================

  @override
  void dispose() {
    _emailController.dispose();

    _passwordController.dispose();

    _emailFocusNode.dispose();

    _passwordFocusNode.dispose();

    _floatController.dispose();

    super.dispose();
  }

  // =====================================================
  // LOGIN
  // =====================================================

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    final String email = _emailController.text.trim();
    final String password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Please enter your email and password.');
      return;
    }

    // Remove the message from an earlier attempt.
    ScaffoldMessenger.of(context).clearSnackBars();

    final bool verified;

    try {
      verified = await runWithProgress<bool>(
        context,
        () => AuthService.signIn(email: email, password: password),
      );
    } on AuthServiceException catch (error) {
      _showAuthError(error);
      return;
    }

    if (!mounted) return;

    if (!verified) {
      // Right password, but the email link has not been
      // tapped yet: the app stays closed until it is.
      ScaffoldMessenger.of(context).clearSnackBars();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VerifyEmailScreen(
            email: email,
            from: VerifyEmailFrom.login,
          ),
        ),
      );
      return;
    }

    _goToHome();
  }

  // Accounts are only created on the Register screen. When
  // the account does not exist (or the details are wrong),
  // offer a shortcut to Register.
  void _showAuthError(AuthServiceException error) {
    _showMessage(
      error.message,
      action: error.suggestsRegister
          ? SnackBarAction(
              label: 'Register',
              onPressed: _goToRegister,
            )
          : null,
    );
  }

  void _goToHome() {
    // Messages are shared by all screens: do not carry an
    // old error (such as a wrong password) into Home.
    ScaffoldMessenger.of(context).clearSnackBars();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const HomeScreen(),
      ),
    );
  }

  void _showMessage(
    String message, {
    SnackBarAction? action,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: action,
          duration: Duration(
            seconds: action == null ? 4 : 6,
          ),
          // A message with a button would otherwise stay
          // until tapped, even after leaving this screen.
          persist: false,
        ),
      );
  }

  // =====================================================
  // REGISTER
  // =====================================================

  void _goToRegister() {
    FocusScope.of(context).unfocus();

    ScaffoldMessenger.of(context).clearSnackBars();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const RegisterScreen(),
      ),
    );
  }

  // =====================================================
  // FORGOT PASSWORD
  // =====================================================

  Future<void> _forgotPassword() async {
    FocusScope.of(context).unfocus();

    final String email = _emailController.text.trim();

    try {
      await runWithProgress<void>(
        context,
        () => AuthService.sendPasswordResetTo(email),
      );
    } on AuthServiceException catch (error) {
      _showMessage(error.message);
      return;
    }

    _showMessage(
      'If an account exists for $email, a password reset link has been sent. '
      'Please check your inbox and spam folder.',
    );
  }

  // =====================================================
  // GOOGLE LOGIN
  // =====================================================

  Future<void> _signInWithGoogle() async {
    FocusScope.of(context).unfocus();

    final bool signedIn;

    try {
      // Login only: a Google account without a NutriPal
      // account is sent to Register.
      signedIn = await runWithProgress<bool>(
        context,
        () => AuthService.signInWithGoogle(
          mode: GoogleAuthMode.login,
        ),
      );
    } on AuthServiceException catch (error) {
      _showAuthError(error);
      return;
    }

    if (!signedIn || !mounted) return;

    _goToHome();
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final bool coverEyes =
        _isPasswordFocused &&
        _obscurePassword;

    final bool keyboardOpen =
        MediaQuery.viewInsetsOf(
          context,
        ).bottom >
        0;

    return GestureDetector(
      behavior:
          HitTestBehavior.translucent,

      onTap: () {
        FocusScope.of(context).unfocus();
      },

      child: Scaffold(
        backgroundColor:
            const Color(
          0xFFF7F2E9,
        ),

        // Keep the page fixed when keyboard opens.
        resizeToAvoidBottomInset:
            false,

        body: SafeArea(
          child: LayoutBuilder(
            builder: (
              BuildContext context,
              BoxConstraints constraints,
            ) {
              // =================================================
              // RESPONSIVE LAYOUT
              // =================================================

              final bool compactScreen =
                  constraints.maxHeight <
                      780;

              final bool compact =
                  compactScreen ||
                      keyboardOpen;

              // Same size as "Create Account" on the
              // Register screen.
              const double titleSize =
                  28;

              final double topPadding =
                  keyboardOpen
                      ? 4
                      : compact
                          ? 8
                          : 14;

              final double cardPadding =
                  compact
                      ? 18
                      : 22;

              final double fieldGap =
                  compact
                      ? 15
                      : 19;

              return Padding(
                padding:
                    EdgeInsets.fromLTRB(
                  24,
                  topPadding,
                  24,
                  8,
                ),

                child: Column(
                  children: [
                    // =================================================
                    // FLOATING MASCOT
                    //
                    // FIXED SIZE.
                    // DOES NOT SHRINK WHEN KEYBOARD OPENS.
                    // =================================================

                    AnimatedBuilder(
                      animation:
                          _floatAnimation,

                      builder: (
                        context,
                        child,
                      ) {
                        return Transform.translate(
                          offset: Offset(
                            0,
                            _floatAnimation.value,
                          ),

                          child:
                              child,
                        );
                      },

                      child: SizedBox(
                        height:
                            155,

                        width:
                            220,

                        child: Stack(
                          alignment:
                              Alignment.center,

                          children: [
                            // =========================================
                            // GLOW
                            // =========================================

                            Container(
                              width:
                                  145,

                              height:
                                  145,

                              decoration:
                                  const BoxDecoration(
                                shape:
                                    BoxShape.circle,

                                gradient:
                                    RadialGradient(
                                  colors: [
                                    Color(
                                      0x50FFB703,
                                    ),
                                    Color(
                                      0x25FFB703,
                                    ),
                                    Color(
                                      0x00FFB703,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // =========================================
                            // LEFT SPARKLE
                            // =========================================

                            const Positioned(
                              top:
                                  16,

                              left:
                                  38,

                              child:
                                  Icon(
                                Icons.auto_awesome,

                                color:
                                    Color(
                                  0xFFFFB703,
                                ),

                                size:
                                    15,
                              ),
                            ),

                            // =========================================
                            // RIGHT SPARKLE
                            // =========================================

                            const Positioned(
                              top:
                                  8,

                              right:
                                  38,

                              child:
                                  Icon(
                                Icons.auto_awesome,

                                color:
                                    Color(
                                  0xFFFFB703,
                                ),

                                size:
                                    19,
                              ),
                            ),

                            // =========================================
                            // TEAL SPARKLE
                            // =========================================

                            const Positioned(
                              bottom:
                                  20,

                              right:
                                  43,

                              child:
                                  Icon(
                                Icons.auto_awesome,

                                color:
                                    Color(
                                  0xFF17B6B1,
                                ),

                                size:
                                    11,
                              ),
                            ),

                            // =========================================
                            // MASCOT
                            // =========================================

                            AnimatedSwitcher(
                              duration:
                                  const Duration(
                                milliseconds:
                                    350,
                              ),

                              child:
                                  Image.asset(
                                coverEyes
                                    ? 'assets/images/NutriPal Mascot5.png'
                                    : 'assets/images/NutriPal Mascot6.png',

                                key:
                                    ValueKey(
                                  coverEyes,
                                ),

                                height:
                                    120,

                                fit:
                                    BoxFit.contain,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // =================================================
                    // TITLE
                    // =================================================

                    Text(
                      'Welcome Back',

                      textAlign:
                          TextAlign.center,

                      style:
                          TextStyle(
                        color:
                            const Color(
                          0xFF4B2E83,
                        ),

                        fontSize:
                            titleSize,

                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    SizedBox(
                      height:
                          compact
                              ? 4
                              : 6,
                    ),

                    const Text(
                      'Your nutrition buddy is ready to guide you',

                      textAlign:
                          TextAlign.center,

                      style:
                          TextStyle(
                        color:
                            Color(
                          0xFF756D7E,
                        ),

                        fontSize:
                            14.5,
                      ),
                    ),

                    SizedBox(
                      height:
                          compact
                              ? 14
                              : 20,
                    ),

                    // =================================================
                    // LOGIN CARD
                    // =================================================

                    Container(
                      width:
                          double.infinity,

                      padding:
                          EdgeInsets.all(
                        cardPadding,
                      ),

                      decoration:
                          BoxDecoration(
                        color:
                            Colors.white,

                        borderRadius:
                            BorderRadius.circular(
                          26,
                        ),

                        boxShadow: [
                          BoxShadow(
                            color:
                                Colors.black
                                    .withValues(
                              alpha:
                                  0.07,
                            ),

                            blurRadius:
                                14,

                            offset:
                                const Offset(
                              0,
                              5,
                            ),
                          ),
                        ],
                      ),

                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        children: [
                          // =========================================
                          // EMAIL LABEL
                          // =========================================

                          const Text(
                            'EMAIL ADDRESS',

                            style:
                                TextStyle(
                              color:
                                  Color(
                                0xFF6F687A,
                              ),

                              fontSize:
                                  12,

                              fontWeight:
                                  FontWeight.bold,

                              letterSpacing:
                                  0.5,
                            ),
                          ),

                          const SizedBox(
                            height:
                                7,
                          ),

                          // =========================================
                          // EMAIL FIELD
                          // =========================================

                          SizedBox(
                            height:
                                52,

                            child:
                                TextField(
                              controller:
                                  _emailController,

                              focusNode:
                                  _emailFocusNode,

                              keyboardType:
                                  TextInputType
                                      .emailAddress,

                              textInputAction:
                                  TextInputAction
                                      .next,

                              decoration:
                                  InputDecoration(
                                filled:
                                    true,

                                fillColor:
                                    const Color(
                                  0xFFF7F2E9,
                                ),

                                prefixIcon:
                                    const Icon(
                                  Icons
                                      .email_outlined,

                                  color:
                                      Color(
                                    0xFF756D7E,
                                  ),
                                ),

                                hintText:
                                    'name@gmail.com',

                                hintStyle:
                                    const TextStyle(
                                  color:
                                      Color(
                                    0xFF756D7E,
                                  ),

                                  fontSize:
                                      14,
                                ),

                                contentPadding:
                                    const EdgeInsets.symmetric(
                                  vertical:
                                      14,
                                ),

                                border:
                                    OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                    30,
                                  ),

                                  borderSide:
                                      BorderSide.none,
                                ),
                              ),

                              onSubmitted:
                                  (_) {
                                _passwordFocusNode
                                    .requestFocus();
                              },
                            ),
                          ),

                          SizedBox(
                            height:
                                fieldGap,
                          ),

                          // =========================================
                          // PASSWORD LABEL
                          // =========================================

                          const Text(
                            'PASSWORD',

                            style:
                                TextStyle(
                              color:
                                  Color(
                                0xFF6F687A,
                              ),

                              fontSize:
                                  12,

                              fontWeight:
                                  FontWeight.bold,

                              letterSpacing:
                                  0.5,
                            ),
                          ),

                          const SizedBox(
                            height:
                                7,
                          ),

                          // =========================================
                          // PASSWORD FIELD
                          // =========================================

                          SizedBox(
                            height:
                                52,

                            child:
                                TextField(
                              controller:
                                  _passwordController,

                              focusNode:
                                  _passwordFocusNode,

                              obscureText:
                                  _obscurePassword,

                              textInputAction:
                                  TextInputAction
                                      .done,

                              decoration:
                                  InputDecoration(
                                filled:
                                    true,

                                fillColor:
                                    const Color(
                                  0xFFF7F2E9,
                                ),

                                prefixIcon:
                                    const Icon(
                                  Icons
                                      .lock_outline,

                                  color:
                                      Color(
                                    0xFF756D7E,
                                  ),
                                ),

                                hintText:
                                    'Enter your password',

                                hintStyle:
                                    const TextStyle(
                                  color:
                                      Color(
                                    0xFF756D7E,
                                  ),

                                  fontSize:
                                      14,
                                ),

                                contentPadding:
                                    const EdgeInsets.symmetric(
                                  vertical:
                                      14,
                                ),

                                border:
                                    OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                    30,
                                  ),

                                  borderSide:
                                      BorderSide.none,
                                ),

                                suffixIcon:
                                    IconButton(
                                  onPressed:
                                      () {
                                    setState(
                                      () {
                                        _obscurePassword =
                                            !_obscurePassword;
                                      },
                                    );
                                  },

                                  icon:
                                      Icon(
                                    _obscurePassword
                                        ? Icons
                                            .visibility_outlined
                                        : Icons
                                            .visibility_off_outlined,

                                    color:
                                        const Color(
                                      0xFF756D7E,
                                    ),
                                  ),
                                ),
                              ),

                              onSubmitted:
                                  (_) {
                                _login();
                              },
                            ),
                          ),

                          SizedBox(
                            height:
                                compact
                                    ? 11
                                    : 14,
                          ),

                          // =========================================
                          // REMEMBER + FORGOT PASSWORD
                          // =========================================

                          Row(
                            children: [
                              SizedBox(
                                width:
                                    22,

                                height:
                                    22,

                                child:
                                    Checkbox(
                                  value:
                                      _rememberMe,

                                  activeColor:
                                      const Color(
                                    0xFF4B2E83,
                                  ),

                                  materialTapTargetSize:
                                      MaterialTapTargetSize
                                          .shrinkWrap,

                                  onChanged:
                                      (
                                    value,
                                  ) {
                                    setState(
                                      () {
                                        _rememberMe =
                                            value ??
                                                false;
                                      },
                                    );
                                  },
                                ),
                              ),

                              const SizedBox(
                                width:
                                    8,
                              ),

                              const Text(
                                'Remember me',

                                style:
                                    TextStyle(
                                  color:
                                      Color(
                                    0xFF5E5867,
                                  ),

                                  fontSize:
                                      13,
                                ),
                              ),

                              const Spacer(),

                              TextButton(
                                onPressed:
                                    _forgotPassword,

                                style:
                                    TextButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(
                                    horizontal:
                                        4,
                                  ),

                                  minimumSize:
                                      Size.zero,

                                  tapTargetSize:
                                      MaterialTapTargetSize
                                          .shrinkWrap,
                                ),

                                child:
                                    const Text(
                                  'Forgot Password?',

                                  style:
                                      TextStyle(
                                    color:
                                        Color(
                                      0xFF17B6B1,
                                    ),

                                    fontSize:
                                        13,

                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(
                            height:
                                compact
                                    ? 14
                                    : 17,
                          ),

                          // =========================================
                          // LOGIN BUTTON
                          // =========================================

                          SizedBox(
                            width:
                                double.infinity,

                            height:
                                52,

                            child:
                                ElevatedButton(
                              onPressed:
                                  _login,

                              style:
                                  ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(
                                  0xFF4B2E83,
                                ),

                                foregroundColor:
                                    Colors.white,

                                elevation:
                                    4,

                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                    30,
                                  ),
                                ),
                              ),

                              child:
                                  const Text(
                                'Log In',

                                style:
                                    TextStyle(
                                  fontSize:
                                      17,

                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(
                            height:
                                compact
                                    ? 13
                                    : 17,
                          ),

                          // =========================================
                          // OR
                          // =========================================

                          const Row(
                            children: [
                              Expanded(
                                child:
                                    Divider(
                                  color:
                                      Color(
                                    0xFFE2DCE8,
                                  ),
                                ),
                              ),

                              Padding(
                                padding:
                                    EdgeInsets.symmetric(
                                  horizontal:
                                      14,
                                ),

                                child:
                                    Text(
                                  'OR',

                                  style:
                                      TextStyle(
                                    color:
                                        Color(
                                      0xFF756D7E,
                                    ),

                                    fontSize:
                                        12,

                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                              ),

                              Expanded(
                                child:
                                    Divider(
                                  color:
                                      Color(
                                    0xFFE2DCE8,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(
                            height:
                                compact
                                    ? 13
                                    : 17,
                          ),

                          // =========================================
                          // GOOGLE
                          // =========================================

                          _googleButton(
                            onPressed:
                                _signInWithGoogle,
                          ),
                        ],
                      ),
                    ),

                    // =================================================
                    // SPACE BEFORE REGISTER
                    // =================================================

                    const SizedBox(
                      height:
                          14,
                    ),

                    // =================================================
                    // REGISTER
                    // =================================================

                    if (!keyboardOpen)
                      Padding(
                        padding:
                            const EdgeInsets.only(
                          top:
                              2,

                          bottom:
                              12,
                        ),

                        child:
                            Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,

                          children: [
                            const Text(
                              "Don't have an account? ",

                              style:
                                  TextStyle(
                                color:
                                    Color(
                                  0xFF5E5867,
                                ),

                                fontSize:
                                    14,
                              ),
                            ),

                            GestureDetector(
                              onTap:
                                  _goToRegister,

                              child:
                                  const Text(
                                'Register',

                                style:
                                    TextStyle(
                                  color:
                                      Color(
                                    0xFF17B6B1,
                                  ),

                                  fontSize:
                                      14,

                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // =====================================================
  // GOOGLE BUTTON
  // =====================================================

  Widget _googleButton({
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width:
          double.infinity,

      height:
          52,

      child:
          OutlinedButton(
        onPressed:
            onPressed,

        style:
            OutlinedButton.styleFrom(
          backgroundColor:
              Colors.white,

          foregroundColor:
              const Color(
            0xFF4B2E83,
          ),

          side:
              const BorderSide(
            color:
                Color(
              0xFFE2DCE8,
            ),

            width:
                1.2,
          ),

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              30,
            ),
          ),
        ),

        child:
            Row(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            Image.asset(
              'assets/images/google_logo.png',

              width:
                  22,

              height:
                  22,

              fit:
                  BoxFit.contain,
            ),

            const SizedBox(
              width:
                  11,
            ),

            const Text(
              'Continue with Google',

              style:
                  TextStyle(
                fontSize:
                    15,

                fontWeight:
                    FontWeight.w600,

                color:
                    Color(
                  0xFF4B2E83,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}