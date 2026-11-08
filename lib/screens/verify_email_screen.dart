import 'dart:async';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/progress_dialog.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'successful_signup_screen.dart';

// =======================================================
// CHECK YOUR EMAIL (email verification)
// =======================================================
//
// Shown after registering with email + password, and when
// someone logs in before verifying. Firebase has emailed a
// link; the app opens only after the link is tapped.
//
//   - Checks automatically every few seconds and when the
//     user comes back to the app, so tapping the link in
//     the email app is usually enough.
//   - "I've verified my email" checks straight away.
//   - "Resend email" waits 60 seconds between sends.
//   - From Register: "Wrong email? Register again" deletes
//     the unverified account so the user can start over.
//   - From Login: "Back to log in" just signs out.
//
// Google accounts never see this screen: Google has
// already verified their email.
// =======================================================

/// Where the user came from, which decides where they go
/// once verified.
enum VerifyEmailFrom { register, login }

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  final VerifyEmailFrom from;

  /// False when the first email could not be sent, so the
  /// screen asks the user to tap Resend.
  final bool emailSent;

  const VerifyEmailScreen({
    super.key,
    required this.email,
    required this.from,
    this.emailSent = true,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with WidgetsBindingObserver {
  static const Color _purple = Color(0xFF4B2E83);
  static const Color _teal = Color(0xFF17B6B1);
  static const Color _background = Color(0xFFF7F2E9);
  static const Color _bodyInk = Color(0xFF3A2668);
  static const Color _muted = Color(0xFF6B5E86);

  static const Duration _autoCheckEvery = Duration(seconds: 5);
  static const int _resendWaitSeconds = 60;

  Timer? _autoCheckTimer;
  Timer? _cooldownTimer;

  int _cooldown = 0;
  bool _checking = false;
  bool _leaving = false;

  bool get _fromRegister => widget.from == VerifyEmailFrom.register;

  // =====================================================
  // LIFECYCLE
  // =====================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    // Just sent from Register: wait before allowing another.
    if (widget.emailSent && _fromRegister) _startCooldown();

    _autoCheckTimer = Timer.periodic(_autoCheckEvery, (_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoCheckTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  // Back from the email app: check straight away.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  // =====================================================
  // CHECKING
  // =====================================================

  /// Quiet check used by the timer and on resume.
  Future<void> _check() async {
    if (_checking || _leaving) return;

    _checking = true;

    try {
      final bool verified = await AuthService.checkEmailVerified();

      if (verified) _continue();
    } catch (_) {
      // Offline or similar: try again on the next tick.
    } finally {
      _checking = false;
    }
  }

  /// "I've verified my email" button.
  Future<void> _checkNow() async {
    if (_leaving) return;

    final bool verified;

    try {
      verified = await runWithProgress<bool>(
        context,
        AuthService.checkEmailVerified,
      );
    } on AuthServiceException catch (error) {
      _showMessage(error.message);
      return;
    }

    if (verified) {
      _continue();
    } else {
      _showMessage(
        'Your email is not verified yet. '
        'Please tap the link in the email we sent, then try again.',
      );
    }
  }

  void _continue() {
    if (_leaving || !mounted) return;

    _leaving = true;
    _autoCheckTimer?.cancel();

    ScaffoldMessenger.of(context).clearSnackBars();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => _fromRegister
            ? const SuccessfulSignupScreen()
            : const HomeScreen(),
      ),
      (Route<dynamic> route) => false,
    );
  }

  // =====================================================
  // RESEND
  // =====================================================

  Future<void> _resend() async {
    if (_cooldown > 0) return;

    try {
      await runWithProgress<void>(
        context,
        AuthService.sendVerificationEmail,
      );
    } on AuthServiceException catch (error) {
      _showMessage(error.message);
      return;
    }

    if (!mounted) return;

    _startCooldown();

    _showMessage('A new verification email has been sent to ${widget.email}.');
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();

    setState(() => _cooldown = _resendWaitSeconds);

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (!mounted) {
        t.cancel();
        return;
      }

      setState(() => _cooldown--);

      if (_cooldown <= 0) t.cancel();
    });
  }

  // =====================================================
  // LEAVE
  // =====================================================

  Future<void> _leave() async {
    if (_leaving) return;

    _leaving = true;
    _autoCheckTimer?.cancel();

    final NavigatorState navigator = Navigator.of(context);

    ScaffoldMessenger.of(context).clearSnackBars();

    try {
      await runWithProgress<void>(
        context,
        // From Register the address may be mistyped, so the
        // unverified account is removed and can be made
        // again. From Login the account is kept.
        _fromRegister
            ? AuthService.discardUnverifiedAccount
            : AuthService.signOut,
      );
    } catch (_) {
      // Leave anyway; the app never opens for an
      // unverified account.
    }

    if (!navigator.mounted) return;

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (BuildContext context) => const LoginScreen(),
      ),
      (Route<dynamic> route) => false,
    );

    if (_fromRegister) {
      navigator.push(
        MaterialPageRoute(
          builder: (BuildContext context) => const RegisterScreen(),
        ),
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final String intro = !widget.emailSent
        ? 'Your account is ready, but we could not send the verification '
            'email. Tap Resend email to try again.'
        : _fromRegister
            ? 'We sent a verification link to'
            : 'Please verify your email before logging in. '
                'We sent a link to';

    return PopScope(
      // Leaving must sign out, so the system back button
      // is routed through the same action as the button.
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && !_leaving) _leave();
      },
      child: Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset(
                      'assets/images/NutriPal Mascot6.png',
                      height: 140,
                      fit: BoxFit.contain,
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'Check your email',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _purple,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ===========================================
                    // EMAIL CARD
                    // ===========================================

                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFEDE4F7)),
                        boxShadow: [
                          BoxShadow(
                            color: _purple.withValues(alpha: 0.06),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: _teal.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.mark_email_unread_rounded,
                              color: _teal,
                              size: 30,
                            ),
                          ),

                          const SizedBox(height: 14),

                          Text(
                            intro,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _bodyInk,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),

                          if (widget.emailSent) ...[
                            const SizedBox(height: 6),
                            Text(
                              widget.email,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _purple,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],

                          const SizedBox(height: 14),

                          const Text(
                            'Tap the link in the email, then come back here. '
                            "Can't find it? Check your spam or junk folder.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _muted,
                              fontSize: 13.5,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 26),

                    // ===========================================
                    // BUTTONS
                    // ===========================================

                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _checkNow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _purple,
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          "I've verified my email",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: _cooldown > 0 ? null : _resend,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _purple,
                          side: BorderSide(
                            color: _cooldown > 0
                                ? _purple.withValues(alpha: 0.25)
                                : _purple,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          _cooldown > 0
                              ? 'Resend email in ${_cooldown}s'
                              : 'Resend email',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    TextButton(
                      onPressed: _leave,
                      style: TextButton.styleFrom(foregroundColor: _muted),
                      child: Text(
                        _fromRegister
                            ? 'Wrong email? Register again'
                            : 'Back to log in',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
