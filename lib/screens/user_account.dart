import 'package:flutter/material.dart';

import '../models/profile_setup_data.dart';
import '../services/auth_service.dart';
import '../services/name_rules.dart';
import '../services/scan_history_service.dart';
import '../services/user_profile_service.dart';
import '../widgets/progress_dialog.dart';
import 'login_screen.dart';

class UserAccount extends StatefulWidget {
  final ProfileSetupData data;

  const UserAccount({
    super.key,
    required this.data,
  });

  @override
  State<UserAccount> createState() =>
      _UserAccountState();
}

class _UserAccountState extends State<UserAccount> {
  // =====================================================
  // NUTRIPAL COLOURS
  // =====================================================

  static const Color backgroundColor =
      Color(0xFFF7F2E9);

  static const Color primaryPurple =
      Color(0xFF4B2E83);

  static const Color darkPurple =
      Color(0xFF38138C);

  static const Color mediumPurple =
      Color(0xFF67558E);

  static const Color lightPurple =
      Color(0xFFE4D9F7);

  static const Color selectedPurple =
      Color(0xFFF3ECFF);

  static const Color borderPurple =
      Color(0xFFDCCFF0);

  // =====================================================
  // CONTROLLER
  // =====================================================

  late final TextEditingController
      _nicknameController;

  bool _hasChanges = false;

  // =====================================================
  // INIT
  // =====================================================

  @override
  void initState() {
    super.initState();

    _nicknameController =
        TextEditingController(
      text: widget.data.nickname,
    );

    _nicknameController.addListener(
      _checkChanges,
    );
  }

  // =====================================================
  // DISPOSE
  // =====================================================

  @override
  void dispose() {
    _nicknameController.removeListener(
      _checkChanges,
    );

    _nicknameController.dispose();

    super.dispose();
  }

  // =====================================================
  // CHECK CHANGES
  // =====================================================

  void _checkChanges() {
    final bool changed =
        _nicknameController.text.trim() !=
            widget.data.nickname.trim();

    if (_hasChanges != changed) {
      setState(() {
        _hasChanges = changed;
      });
    }
  }

  // =====================================================
  // DATE OF BIRTH
  // =====================================================

  String get _dateOfBirth {
    final dynamic rawDate =
        widget.data.dateOfBirth;

    if (rawDate == null) {
      return 'Not available';
    }

    if (rawDate is DateTime) {
      return _formatDateOfBirth(
        rawDate,
      );
    }

    if (rawDate is String &&
        rawDate.trim().isNotEmpty) {
      // If the model stores DOB as a String,
      // try converting ISO date into a readable date.
      final DateTime? parsedDate =
          DateTime.tryParse(
        rawDate,
      );

      if (parsedDate != null) {
        return _formatDateOfBirth(
          parsedDate,
        );
      }

      return rawDate.trim();
    }

    return 'Not available';
  }

  // =====================================================
  // FORMAT DOB
  // =====================================================

  String _formatDateOfBirth(
    DateTime date,
  ) {
    const List<String> months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${date.day} '
        '${months[date.month - 1]} '
        '${date.year}';
  }

  // =====================================================
  // EMAIL
  // =====================================================

  String get _email {
    if (widget.data.email.trim().isEmpty) {
      return 'Not available';
    }

    return widget.data.email.trim();
  }

  // =====================================================
  // SAVE
  // =====================================================

  // =====================================================
  // DELETE ACCOUNT
  // =====================================================
  //
  // 1. Confirm (password, or the Google account picker).
  // 2. Delete the Firebase Authentication account.
  // 3. Remove this account's scan history and favourites
  //    from the phone.
  // 4. Go back to the login screen.
  // =====================================================

  static const Color deleteRed =
      Color(0xFFE53945);

  void _showSnack(
    String message, {
    Color color = primaryPurple,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _deleteAccount() async {
    FocusScope.of(context).unfocus();

    if (!AuthService.isSignedIn) {
      _showSnack(
        'Please sign in again, then delete your account.',
      );
      return;
    }

    final bool usesPassword =
        AuthService.hasPasswordLogin;

    final String? password =
        await _confirmDeleteDialog(
      usesPassword: usesPassword,
    );

    // Cancelled.
    if (password == null || !mounted) {
      return;
    }

    final String? userId =
        AuthService.currentUserId;

    final NavigatorState navigator =
        Navigator.of(context);

    final ScaffoldMessengerState messenger =
        ScaffoldMessenger.of(context);

    bool deleted = false;

    try {
      deleted = await runWithProgress<bool>(
        context,
        () async {
          // Saved data is deleted after the password /
          // Google check and before the account itself,
          // while the user may still delete it (Firestore
          // rules). If it fails, the account is kept.
          return AuthService.deleteAccount(
            password:
                usesPassword ? password : null,
            beforeDelete: userId == null
                ? null
                : () async {
                    await ScanHistoryService.instance
                        .deleteAllForUser(userId);

                    await UserProfileService.delete(
                      userId,
                    );
                  },
          );
        },
      );
    } on AuthServiceException catch (error) {
      if (!mounted) return;

      _showSnack(
        error.message,
        color: deleteRed,
      );
      return;
    } catch (_) {
      if (!mounted) return;

      _showSnack(
        'Your account could not be deleted. Please try again.',
        color: deleteRed,
      );
      return;
    }

    // Google account picker closed: nothing deleted.
    if (!deleted) {
      return;
    }

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (
          context,
        ) =>
            const LoginScreen(),
      ),
      (Route<dynamic> route) => false,
    );

    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Your NutriPal account has been deleted.',
        ),
        backgroundColor: primaryPurple,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Returns the password (email accounts), '' (Google
  /// accounts) or null when cancelled.
  Future<String?> _confirmDeleteDialog({
    required bool usesPassword,
  }) {
    final TextEditingController passwordController =
        TextEditingController();

    bool hidden = true;

    return showDialog<String>(
      context: context,
      builder: (
        BuildContext dialogContext,
      ) {
        return StatefulBuilder(
          builder: (
            BuildContext context,
            StateSetter setDialogState,
          ) {
            final bool canDelete = !usesPassword ||
                passwordController.text.isNotEmpty;

            return AlertDialog(
              backgroundColor:
                  backgroundColor,
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  22,
                ),
              ),
              title: const Text(
                'Delete your account?',
                style: TextStyle(
                  color: darkPurple,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
              content: Column(
                mainAxisSize:
                    MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This permanently deletes your NutriPal account, '
                    'together with the scan history and favourites '
                    'saved for it on this phone. This cannot be undone.',
                    style: TextStyle(
                      color: mediumPurple,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  if (usesPassword)
                    TextField(
                      controller:
                          passwordController,
                      obscureText: hidden,
                      autofocus: true,
                      onChanged: (_) {
                        setDialogState(() {});
                      },
                      decoration:
                          InputDecoration(
                        labelText:
                            'Enter your password to confirm',
                        filled: true,
                        fillColor:
                            Colors.white,
                        border:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(
                            12,
                          ),
                        ),
                        suffixIcon:
                            IconButton(
                          tooltip: hidden
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () {
                            setDialogState(() {
                              hidden = !hidden;
                            });
                          },
                          icon: Icon(
                            hidden
                                ? Icons
                                    .visibility_outlined
                                : Icons
                                    .visibility_off_outlined,
                          ),
                        ),
                      ),
                    )
                  else
                    const Text(
                      'Next, choose your Google account to confirm it is you.',
                      style: TextStyle(
                        color: darkPurple,
                        fontWeight:
                            FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: primaryPurple,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton(
                  style:
                      FilledButton.styleFrom(
                    backgroundColor:
                        deleteRed,
                    disabledBackgroundColor:
                        deleteRed.withValues(
                      alpha: 0.35,
                    ),
                  ),
                  onPressed: canDelete
                      ? () {
                          Navigator.pop(
                            dialogContext,
                            usesPassword
                                ? passwordController
                                    .text
                                : '',
                          );
                        }
                      : null,
                  child: const Text(
                    'Delete account',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _saveChanges() {
    FocusScope.of(context).unfocus();

    final String nickname =
        NameRules.normalize(_nicknameController.text);

    // Letters, spaces, ' and - only (no numbers or other symbols).
    final String? nicknameProblem =
        NameRules.validate(nickname);

    if (nicknameProblem != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            nicknameProblem,
          ),
          backgroundColor:
              primaryPurple,
          behavior:
              SnackBarBehavior.floating,
        ),
      );

      return;
    }

    setState(() {
      widget.data.nickname =
          nickname;

      _hasChanges =
          false;
    });

    // Saved to Firestore (works offline, sent later).
    UserProfileService.save(widget.data);

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'Nickname updated successfully.',
        ),
        backgroundColor:
            primaryPurple,
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor:
            backgroundColor,

        body: SafeArea(
          child:
              SingleChildScrollView(
            keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior
                    .onDrag,

            physics:
                const ClampingScrollPhysics(),

            padding:
                const EdgeInsets.fromLTRB(
              20,
              18,
              20,
              30,
            ),

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                // =================================================
                // HEADER
                // =================================================
                SizedBox(
                  height: 46,
                  child: Stack(
                    alignment:
                        Alignment.center,
                    children: [
                      Align(
                        alignment:
                            Alignment.centerLeft,
                        child: IconButton(
                          onPressed: () {
                            FocusScope.of(context)
                                .unfocus();

                            Navigator.pop(
                              context,
                            );
                          },
                          padding:
                              EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(),
                          icon:
                              const Icon(
                            Icons
                                .arrow_back_ios_new_rounded,
                            color:
                                darkPurple,
                            size: 21,
                          ),
                        ),
                      ),

                      const Text(
                        'My Account',
                        style:
                            TextStyle(
                          color:
                              darkPurple,
                          fontSize: 22,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 28,
                ),

                // =================================================
                // PROFILE DETAILS
                // =================================================
                // Same section-title style as Weight
                // Management Goal (GOAL, BODY INFORMATION...).
                const Text(
                  'PROFILE DETAILS',
                  style:
                      TextStyle(
                    color:
                        primaryPurple,
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                Container(
                  width:
                      double.infinity,
                  padding:
                      const EdgeInsets.fromLTRB(
                    16,
                    20,
                    16,
                    20,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.white,
                    borderRadius:
                        BorderRadius.circular(
                      18,
                    ),
                    border:
                        Border.all(
                      color:
                          borderPurple,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      // ===========================================
                      // NICKNAME
                      // ===========================================
                      const Text(
                        'Nickname',
                        style:
                            TextStyle(
                          color:
                              darkPurple,
                          fontSize: 16,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      TextField(
                        controller:
                            _nicknameController,
                        inputFormatters:
                            NameRules.inputFormatters,
                        textCapitalization:
                            TextCapitalization
                                .words,
                        textInputAction:
                            TextInputAction.done,
                        style:
                            const TextStyle(
                          color:
                              darkPurple,
                          fontSize: 17,
                          fontWeight:
                              FontWeight.w500,
                        ),
                        decoration:
                            InputDecoration(
                          filled: true,
                          fillColor:
                              Colors.white,

                          suffixIcon:
                              const Icon(
                            Icons.edit_outlined,
                            color:
                                primaryPurple,
                            size: 22,
                          ),

                          contentPadding:
                              const EdgeInsets.symmetric(
                            horizontal:
                                16,
                            vertical:
                                16,
                          ),

                          enabledBorder:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(
                              12,
                            ),
                            borderSide:
                                const BorderSide(
                              color:
                                  primaryPurple,
                              width: 1.4,
                            ),
                          ),

                          focusedBorder:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(
                              12,
                            ),
                            borderSide:
                                const BorderSide(
                              color:
                                  primaryPurple,
                              width: 2,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 7,
                      ),

                      const Text(
                        'This is how NutriPal will address you.',
                        style:
                            TextStyle(
                          color:
                              mediumPurple,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),

                      const SizedBox(
                        height: 24,
                      ),

                      // ===========================================
                      // DATE OF BIRTH
                      // ===========================================
                      const Text(
                        'Date of birth',
                        style:
                            TextStyle(
                          color:
                              darkPurple,
                          fontSize: 16,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      _LockedField(
                        value:
                            _dateOfBirth,
                        leadingIcon:
                            Icons
                                .calendar_month_outlined,
                      ),

                      const SizedBox(
                        height: 24,
                      ),

                      // ===========================================
                      // EMAIL
                      // ===========================================
                      const Text(
                        'Email address',
                        style:
                            TextStyle(
                          color:
                              darkPurple,
                          fontSize: 16,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      _LockedField(
                        value:
                            _email,
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      const Text(
                        'Your registered email cannot be changed here.',
                        style:
                            TextStyle(
                          color:
                              mediumPurple,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),

                // =================================================
                // INFO BOX
                // =================================================
                Container(
                  width:
                      double.infinity,
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        selectedPurple,
                    borderRadius:
                        BorderRadius.circular(
                      16,
                    ),
                  ),
                  child:
                      const Row(
                    children: [
                      CircleAvatar(
                        radius: 19,
                        backgroundColor:
                            primaryPurple,
                        child: Icon(
                          Icons
                              .info_outline_rounded,
                          color:
                              Colors.white,
                          size: 22,
                        ),
                      ),

                      SizedBox(
                        width: 13,
                      ),

                      Expanded(
                        child: Text(
                          'Only your nickname can be edited in NutriPal.',
                          style:
                              TextStyle(
                            color:
                                darkPurple,
                            fontSize: 14,
                            height: 1.35,
                            fontWeight:
                                FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                // =================================================
                // SAVE
                // =================================================
                SizedBox(
                  width:
                      double.infinity,
                  height: 55,
                  child:
                      ElevatedButton(
                    onPressed:
                        _hasChanges
                            ? _saveChanges
                            : null,
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          primaryPurple,
                      foregroundColor:
                          Colors.white,

                      disabledBackgroundColor:
                          mediumPurple
                              .withValues(
                        alpha: 0.40,
                      ),

                      disabledForegroundColor:
                          Colors.white
                              .withValues(
                        alpha: 0.75,
                      ),

                      elevation:
                          _hasChanges
                              ? 4
                              : 0,

                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          18,
                        ),
                      ),
                    ),
                    child:
                        const Text(
                      'Save changes',
                      style:
                          TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ),
                ),

                // =================================================
                // DELETE MY ACCOUNT
                // =================================================
                const SizedBox(
                  height: 40,
                ),

                Center(
                  child: TextButton(
                    onPressed:
                        _deleteAccount,
                    style:
                        TextButton.styleFrom(
                      foregroundColor:
                          deleteRed,
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Delete my account',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =======================================================
// LOCKED FIELD
// =======================================================

class _LockedField extends StatelessWidget {
  final String value;
  final IconData? leadingIcon;

  const _LockedField({
    required this.value,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width:
          double.infinity,

      constraints:
          const BoxConstraints(
        minHeight: 56,
      ),

      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),

      decoration:
          BoxDecoration(
        color:
            _UserAccountState
                .selectedPurple,

        borderRadius:
            BorderRadius.circular(
          12,
        ),

        border:
            Border.all(
          color:
              _UserAccountState
                  .lightPurple,
        ),
      ),

      child: Row(
        children: [
          // =============================================
          // OPTIONAL LEADING ICON
          // =============================================
          if (leadingIcon != null) ...[
            Icon(
              leadingIcon,
              color:
                  _UserAccountState
                      .mediumPurple,
              size: 22,
            ),

            const SizedBox(
              width: 11,
            ),
          ],

          // =============================================
          // VALUE
          // =============================================
          Expanded(
            child: Text(
              value,
              style:
                  const TextStyle(
                color:
                    _UserAccountState
                        .darkPurple,
                fontSize: 17,
                fontWeight:
                    FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          // =============================================
          // LOCK
          // =============================================
          const Icon(
            Icons
                .lock_outline_rounded,
            color:
                _UserAccountState
                    .mediumPurple,
            size: 22,
          ),
        ],
      ),
    );
  }
}