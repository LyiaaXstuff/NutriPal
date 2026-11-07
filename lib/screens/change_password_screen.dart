import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/password_rules.dart';

// =======================================================
// CHANGE PASSWORD (Profile -> Security)
// =======================================================
//
// 1. Current password (re-authenticates the user)
// 2. New password with a live checklist of the rules
// 3. Confirm new password
//
// The Firebase work is done by AuthService; this screen
// only collects input, validates it and shows the result.
// =======================================================

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  // =====================================================
  // NUTRIPAL COLOURS
  // =====================================================

  static const Color backgroundColor = Color(0xFFF7F2E9);
  static const Color primaryPurple = Color(0xFF4B2E83);
  static const Color darkPurple = Color(0xFF38138C);
  static const Color mediumPurple = Color(0xFF67558E);
  static const Color lightPurple = Color(0xFFE4D9F7);
  static const Color borderPurple = Color(0xFFDCCFF0);
  static const Color teal = Color(0xFF17B6B1);

  // =====================================================
  // CONTROLLERS
  // =====================================================

  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  final FocusNode _newFocusNode = FocusNode();
  final FocusNode _confirmFocusNode = FocusNode();

  bool _hideCurrent = true;
  bool _hideNew = true;
  bool _hideConfirm = true;

  bool _saving = false;
  bool _sendingReset = false;

  String? _error;

  @override
  void initState() {
    super.initState();

    // Rebuild the checklist and button as the user types.
    for (final TextEditingController controller in <TextEditingController>[
      _currentController,
      _newController,
      _confirmController,
    ]) {
      controller.addListener(_onChanged);
    }
  }

  void _onChanged() {
    setState(() {
      _error = null;
    });
  }

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    _newFocusNode.dispose();
    _confirmFocusNode.dispose();
    super.dispose();
  }

  // =====================================================
  // SAVE
  // =====================================================

  Future<void> _changePassword() async {
    FocusScope.of(context).unfocus();

    final String? problem = PasswordRules.validate(
      currentPassword: _currentController.text,
      newPassword: _newController.text,
      confirmPassword: _confirmController.text,
    );

    if (problem != null) {
      setState(() {
        _error = problem;
      });

      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await AuthService.changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password changed successfully.'),
        ),
      );

      Navigator.pop(context);
    } on AuthServiceException catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // =====================================================
  // FORGOT CURRENT PASSWORD
  // =====================================================

  Future<void> _sendResetEmail() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _sendingReset = true;
      _error = null;
    });

    try {
      final String email = await AuthService.sendPasswordReset();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('A password reset link has been sent to $email.'),
        ),
      );
    } on AuthServiceException catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _sendingReset = false;
        });
      }
    }
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final bool canSubmit = !_saving &&
        _currentController.text.isNotEmpty &&
        _newController.text.isNotEmpty &&
        _confirmController.text.isNotEmpty;

    final bool confirmMismatch = _confirmController.text.isNotEmpty &&
        _confirmController.text != _newController.text;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // =============================================
                // HEADER
                // =============================================
                SizedBox(
                  height: 46,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: _saving
                              ? null
                              : () {
                                  FocusScope.of(context).unfocus();
                                  Navigator.pop(context);
                                },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: darkPurple,
                            size: 24,
                          ),
                        ),
                      ),
                      const Text(
                        'Security',
                        style: TextStyle(
                          color: darkPurple,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                const Text(
                  'Change password',
                  style: TextStyle(
                    color: darkPurple,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  'Enter your current password, then choose a new one.',
                  style: TextStyle(
                    color: mediumPurple,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),

                const SizedBox(height: 14),

                // =============================================
                // FORM CARD
                // =============================================
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderPurple),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // CURRENT PASSWORD
                      const _FieldLabel('Current password'),
                      const SizedBox(height: 8),
                      _passwordField(
                        controller: _currentController,
                        hidden: _hideCurrent,
                        onToggle: () =>
                            setState(() => _hideCurrent = !_hideCurrent),
                        hint: 'Enter your current password',
                        action: TextInputAction.next,
                        onSubmitted: (_) => _newFocusNode.requestFocus(),
                        autofill: AutofillHints.password,
                      ),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed:
                              (_saving || _sendingReset) ? null : _sendResetEmail,
                          style: TextButton.styleFrom(
                            foregroundColor: primaryPurple,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 6,
                            ),
                          ),
                          child: Text(
                            _sendingReset
                                ? 'Sending reset link...'
                                : 'Forgot current password?',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // NEW PASSWORD
                      const _FieldLabel('New password'),
                      const SizedBox(height: 8),
                      _passwordField(
                        controller: _newController,
                        focusNode: _newFocusNode,
                        hidden: _hideNew,
                        onToggle: () => setState(() => _hideNew = !_hideNew),
                        hint: 'Enter a new password',
                        action: TextInputAction.next,
                        onSubmitted: (_) => _confirmFocusNode.requestFocus(),
                        autofill: AutofillHints.newPassword,
                      ),

                      const SizedBox(height: 12),

                      _RuleChecklist(
                        rules: PasswordRules.check(_newController.text),
                        differentFromCurrent: _newController.text.isEmpty ||
                            _newController.text != _currentController.text,
                      ),

                      const SizedBox(height: 22),

                      // CONFIRM NEW PASSWORD
                      const _FieldLabel('Confirm new password'),
                      const SizedBox(height: 8),
                      _passwordField(
                        controller: _confirmController,
                        focusNode: _confirmFocusNode,
                        hidden: _hideConfirm,
                        onToggle: () =>
                            setState(() => _hideConfirm = !_hideConfirm),
                        hint: 'Re-enter your new password',
                        action: TextInputAction.done,
                        onSubmitted: (_) {
                          if (canSubmit) _changePassword();
                        },
                        autofill: AutofillHints.newPassword,
                        errorText:
                            confirmMismatch ? 'Passwords do not match' : null,
                      ),
                    ],
                  ),
                ),

                // =============================================
                // ERROR MESSAGE
                // =============================================
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEEF0),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF3C2C8)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFFC62839),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: Color(0xFF8C1C2A),
                              fontSize: 14,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 22),

                // =============================================
                // SUBMIT
                // =============================================
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: canSubmit ? _changePassword : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryPurple,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: lightPurple,
                      disabledForegroundColor: mediumPurple,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.6,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Update password',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }

  // =====================================================
  // PASSWORD FIELD
  // =====================================================

  Widget _passwordField({
    required TextEditingController controller,
    FocusNode? focusNode,
    required bool hidden,
    required VoidCallback onToggle,
    required String hint,
    required TextInputAction action,
    required ValueChanged<String> onSubmitted,
    required String autofill,
    String? errorText,
  }) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: hidden,
      enabled: !_saving,
      enableSuggestions: false,
      autocorrect: false,
      textInputAction: action,
      onSubmitted: onSubmitted,
      autofillHints: <String>[autofill],
      style: const TextStyle(
        color: darkPurple,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: mediumPurple, fontSize: 15),
        errorText: errorText,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        prefixIcon: const Icon(Icons.lock_outline_rounded, color: mediumPurple),
        suffixIcon: IconButton(
          onPressed: onToggle,
          tooltip: hidden ? 'Show password' : 'Hide password',
          icon: Icon(
            hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: mediumPurple,
          ),
        ),
        enabledBorder: border(borderPurple, 1.4),
        disabledBorder: border(lightPurple, 1.2),
        focusedBorder: border(primaryPurple, 2),
        errorBorder: border(const Color(0xFFC62839), 1.4),
        focusedErrorBorder: border(const Color(0xFFC62839), 2),
      ),
    );
  }
}

// =======================================================
// SMALL WIDGETS
// =======================================================

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _ChangePasswordScreenState.darkPurple,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _RuleChecklist extends StatelessWidget {
  final List<PasswordRule> rules;
  final bool differentFromCurrent;

  const _RuleChecklist({
    required this.rules,
    required this.differentFromCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final List<PasswordRule> all = <PasswordRule>[
      ...rules,
      PasswordRule('Different from your current password', differentFromCurrent),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final PasswordRule rule in all)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(
                  rule.met
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: rule.met
                      ? _ChangePasswordScreenState.teal
                      : _ChangePasswordScreenState.borderPurple,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rule.label,
                    style: TextStyle(
                      color: rule.met
                          ? _ChangePasswordScreenState.darkPurple
                          : _ChangePasswordScreenState.mediumPurple,
                      fontSize: 13.5,
                      fontWeight: rule.met ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
