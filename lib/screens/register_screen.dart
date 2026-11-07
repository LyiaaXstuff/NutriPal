import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/password_rules.dart';
import '../widgets/progress_dialog.dart';

import 'successful_signup_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
  });

  @override
  State<RegisterScreen> createState() =>
      _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  // =====================================================
  // CONTROLLERS
  // =====================================================

  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // =====================================================
  // FOCUS NODES
  // =====================================================

  final FocusNode _emailFocusNode =
      FocusNode();

  final FocusNode _passwordFocusNode =
      FocusNode();

  final FocusNode _confirmPasswordFocusNode =
      FocusNode();

  // =====================================================
  // PASSWORD STATES
  // =====================================================

  bool _hidePassword = true;

  bool _hideConfirmPassword = true;

  bool _isPasswordFocused = false;

  bool _isConfirmPasswordFocused = false;

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

    _passwordFocusNode.addListener(() {
      if (!mounted) {
        return;
      }

      setState(() {
        _isPasswordFocused =
            _passwordFocusNode.hasFocus;
      });
    });

    _confirmPasswordFocusNode.addListener(() {
      if (!mounted) {
        return;
      }

      setState(() {
        _isConfirmPasswordFocused =
            _confirmPasswordFocusNode.hasFocus;
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

    _confirmPasswordController.dispose();

    _emailFocusNode.dispose();

    _passwordFocusNode.dispose();

    _confirmPasswordFocusNode.dispose();

    _floatController.dispose();

    super.dispose();
  }

  // =====================================================
  // CREATE ACCOUNT
  // =====================================================

  Future<void> _createAccount() async {
    FocusScope.of(context).unfocus();

    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please complete all fields.',
          ),
        ),
      );

      return;
    }

    if (_passwordController.text !=
        _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Passwords do not match.',
          ),
        ),
      );

      return;
    }

    if (!PasswordRules.isStrong(_passwordController.text)) {
      _showMessage(
        'Password must be at least ${PasswordRules.minLength} characters '
        'and include an uppercase letter, a lowercase letter and a number.',
      );

      return;
    }

    try {
      await runWithProgress<void>(
        context,
        () => AuthService.register(
          email: _emailController.text,
          password: _passwordController.text,
        ),
      );
    } on AuthServiceException catch (error) {
      _showMessage(error.message);
      return;
    }

    if (!mounted) return;

    _goToSignupSuccess();
  }

  void _goToSignupSuccess() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const SuccessfulSignupScreen(),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  // =====================================================
  // GOOGLE SIGN UP
  // =====================================================

  Future<void> _signUpWithGoogle() async {
    FocusScope.of(context).unfocus();

    final bool signedIn;

    try {
      signedIn = await runWithProgress<bool>(
        context,
        AuthService.signInWithGoogle,
      );
    } on AuthServiceException catch (error) {
      _showMessage(error.message);
      return;
    }

    if (!signedIn || !mounted) return;

    _goToSignupSuccess();
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final bool coverEyes =
        (_isPasswordFocused &&
                _hidePassword) ||
            (_isConfirmPasswordFocused &&
                _hideConfirmPassword);

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

        resizeToAvoidBottomInset:
            true,

        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior
                    .onDrag,

            padding:
                const EdgeInsets.fromLTRB(
              24,
              14,
              24,
              20,
            ),

            child: Column(
              children: [
                // =================================================
                // FLOATING MASCOT
                // FIXED SIZE WHEN KEYBOARD OPENS
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
                      child: child,
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
                                : 'assets/images/NutriPal Mascot4.png',

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

                const Text(
                  'Create Account',

                  textAlign:
                      TextAlign.center,

                  style:
                      TextStyle(
                    color:
                        Color(
                      0xFF4B2E83,
                    ),

                    fontSize:
                        25,

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height:
                      6,
                ),

                const Text(
                  'Start your journey with NutriPal',

                  textAlign:
                      TextAlign.center,

                  style:
                      TextStyle(
                    color:
                        Color(
                      0xFF756D7E,
                    ),

                    fontSize:
                        15,
                  ),
                ),

                const SizedBox(
                  height:
                      22,
                ),

                // =================================================
                // REGISTER CARD
                // =================================================

                Container(
                  width:
                      double.infinity,

                  padding:
                      const EdgeInsets.all(
                    22,
                  ),

                  decoration:
                      BoxDecoration(
                    color:
                        Colors.white,

                    borderRadius:
                        BorderRadius.circular(
                      28,
                    ),

                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black
                                .withValues(
                          alpha:
                              0.08,
                        ),

                        blurRadius:
                            15,

                        offset:
                            const Offset(
                          0,
                          6,
                        ),
                      ),
                    ],
                  ),

                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [
                      // =========================================
                      // EMAIL
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

                      _normalField(
                        controller:
                            _emailController,

                        focusNode:
                            _emailFocusNode,

                        icon:
                            Icons.email_outlined,

                        hint:
                            'name@gmail.com',

                        keyboardType:
                            TextInputType
                                .emailAddress,

                        action:
                            TextInputAction.next,

                        onSubmitted:
                            (_) {
                          _passwordFocusNode
                              .requestFocus();
                        },
                      ),

                      const SizedBox(
                        height:
                            16,
                      ),

                      // =========================================
                      // PASSWORD
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

                      _passwordField(
                        controller:
                            _passwordController,

                        focusNode:
                            _passwordFocusNode,

                        hidden:
                            _hidePassword,

                        hint:
                            'Enter your password',

                        action:
                            TextInputAction.next,

                        onVisibilityPressed:
                            () {
                          setState(() {
                            _hidePassword =
                                !_hidePassword;
                          });
                        },

                        onSubmitted:
                            (_) {
                          _confirmPasswordFocusNode
                              .requestFocus();
                        },
                      ),

                      const SizedBox(
                        height:
                            16,
                      ),

                      // =========================================
                      // CONFIRM PASSWORD
                      // =========================================

                      const Text(
                        'CONFIRM PASSWORD',

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

                      _passwordField(
                        controller:
                            _confirmPasswordController,

                        focusNode:
                            _confirmPasswordFocusNode,

                        hidden:
                            _hideConfirmPassword,

                        hint:
                            'Re-enter your password',

                        action:
                            TextInputAction.done,

                        onVisibilityPressed:
                            () {
                          setState(() {
                            _hideConfirmPassword =
                                !_hideConfirmPassword;
                          });
                        },

                        onSubmitted:
                            (_) {
                          _createAccount();
                        },
                      ),

                      const SizedBox(
                        height:
                            22,
                      ),

                      // =========================================
                      // CREATE ACCOUNT BUTTON
                      // =========================================

                      SizedBox(
                        width:
                            double.infinity,

                        height:
                            54,

                        child:
                            ElevatedButton(
                          onPressed:
                              _createAccount,

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
                            'Create Account',

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

                      const SizedBox(
                        height:
                            18,
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

                      const SizedBox(
                        height:
                            18,
                      ),

                      // =========================================
                      // GOOGLE
                      // =========================================

                      _googleButton(
                        onPressed:
                            _signUpWithGoogle,
                      ),
                    ],
                  ),
                ),

                // =================================================
                // LOG IN
                // =================================================

                const SizedBox(
                  height:
                      16,
                ),

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,

                  children: [
                    const Text(
                      'Already have an account? ',

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
                      onTap: () {
                        Navigator.pop(
                          context,
                        );
                      },

                      child:
                          const Text(
                        'Log In',

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

                const SizedBox(
                  height:
                      18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =====================================================
  // NORMAL FIELD
  // =====================================================

  Widget _normalField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    required String hint,
    required TextInputAction action,
    required ValueChanged<String> onSubmitted,
    TextInputType? keyboardType,
  }) {
    return SizedBox(
      height:
          52,

      child:
          TextField(
        controller:
            controller,

        focusNode:
            focusNode,

        keyboardType:
            keyboardType,

        textInputAction:
            action,

        decoration:
            InputDecoration(
          filled:
              true,

          fillColor:
              const Color(
            0xFFF7F2E9,
          ),

          prefixIcon:
              Icon(
            icon,

            color:
                const Color(
              0xFF756D7E,
            ),
          ),

          hintText:
              hint,

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
            onSubmitted,
      ),
    );
  }

  // =====================================================
  // PASSWORD FIELD
  // =====================================================

  Widget _passwordField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool hidden,
    required String hint,
    required TextInputAction action,
    required VoidCallback onVisibilityPressed,
    required ValueChanged<String> onSubmitted,
  }) {
    return SizedBox(
      height:
          52,

      child:
          TextField(
        controller:
            controller,

        focusNode:
            focusNode,

        obscureText:
            hidden,

        textInputAction:
            action,

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
            Icons.lock_outline,

            color:
                Color(
              0xFF756D7E,
            ),
          ),

          hintText:
              hint,

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
                onVisibilityPressed,

            icon:
                Icon(
              hidden
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,

              color:
                  const Color(
                0xFF756D7E,
              ),
            ),
          ),
        ),

        onSubmitted:
            onSubmitted,
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
          54,

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

        child: Row(
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