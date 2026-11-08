import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/profile_setup_data.dart';
import '../services/auth_service.dart';
import '../services/profile_photo_service.dart';
import '../services/user_profile_service.dart';
import '../widgets/profile_avatar.dart';
import 'change_password_screen.dart';
import 'health_conditions_settings.dart';
import 'history_screen.dart';
import 'login_screen.dart';
import 'user_account.dart';
import 'weight_management_settings.dart';

class ProfileScreen extends StatefulWidget {
  final ProfileSetupData data;

  const ProfileScreen({
    super.key,
    required this.data,
  });

  @override
  State<ProfileScreen> createState() =>
      _ProfileScreenState();
}

class _ProfileScreenState
    extends State<ProfileScreen> {
  // =====================================================
  // COLOURS
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

  static const Color logoutRed =
      Color(0xFFE53945);

  // =====================================================
  // DISPLAY NAME
  // =====================================================

  String get _displayName {
    if (widget.data.nickname
        .trim()
        .isEmpty) {
      return 'NutriPal User';
    }

    return widget.data.nickname.trim();
  }

  // =====================================================
  // HEALTH CONDITIONS
  // =====================================================

  String get _healthConditions {
    final List<String> conditions =
        [];

    if (widget.data.diabetes) {
      conditions.add(
        'Diabetes',
      );
    }

    if (widget.data.hypertension) {
      conditions.add(
        'Hypertension',
      );
    }

    if (widget.data.highCholesterol) {
      conditions.add(
        'High cholesterol',
      );
    }

    if (widget.data.weightManagement) {
      conditions.add(
        'Weight management',
      );
    }

    if (conditions.isEmpty) {
      return 'General nutrition';
    }

    return conditions.join(
      '  ·  ',
    );
  }

  // =====================================================
  // WEIGHT MANAGEMENT SUBTITLE
  // =====================================================

  String get _weightManagementSubtitle {
    if (!widget.data.weightManagement) {
      return 'Not enabled';
    }

    final String? goal =
        widget.data.weightGoal;

    if (goal == null ||
        goal.trim().isEmpty) {
      return 'Not selected';
    }

    return goal.trim();
  }

  // =====================================================
  // COMPLETE WEIGHT MANAGEMENT DATA
  // =====================================================

  bool get _hasCompleteWeightManagementData {
    final String? goal =
        widget.data.weightGoal;

    final String? gender =
        widget.data.genderForEnergyEstimate;

    final String? activity =
        widget.data.activityLevel;

    return goal != null &&
        goal.trim().isNotEmpty &&
        gender != null &&
        gender.trim().isNotEmpty &&
        widget.data.currentWeight != null &&
        widget.data.currentWeight! > 0 &&
        widget.data.height != null &&
        widget.data.height! > 0 &&
        activity != null &&
        activity.trim().isNotEmpty;
  }

  // =====================================================
  // MY ACCOUNT
  // =====================================================

  Future<void> _openMyAccount() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (
          context,
        ) =>
            UserAccount(
          data: widget.data,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {});
  }

  // =====================================================
  // SECURITY (CHANGE PASSWORD)
  // =====================================================

  // =====================================================
  // SCAN HISTORY (90 days; not a bottom tab)
  // =====================================================

  Future<void> _openScanHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (
          context,
        ) =>
            HistoryScreen(
          profile: widget.data,
        ),
      ),
    );
  }

  Future<void> _openSecurity() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (
          context,
        ) =>
            const ChangePasswordScreen(),
      ),
    );
  }

  // =====================================================
  // HEALTH CONDITIONS
  // =====================================================

  Future<void>
      _openHealthConditionsSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (
          context,
        ) =>
            HealthConditionsSettings(
          data: widget.data,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {});
  }

  // =====================================================
  // WEIGHT MANAGEMENT SETTINGS
  // =====================================================

  Future<void>
      _openWeightManagementSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (
          context,
        ) =>
            WeightManagementSettings(
          data: widget.data,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {});
  }

  // =====================================================
  // WEIGHT MANAGEMENT TAP
  // =====================================================

  Future<void>
      _handleWeightManagementTap() async {
    if (widget.data.weightManagement) {
      await _openWeightManagementSettings();

      return;
    }

    _showEnableWeightManagementSheet();
  }

  // =====================================================
  // ENABLE WEIGHT MANAGEMENT SHEET
  // =====================================================

  void _showEnableWeightManagementSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          Colors.transparent,
      isScrollControlled:
          true,
      builder: (
        BuildContext sheetContext,
      ) {
        return SafeArea(
          top: false,
          child: Container(
            padding:
                const EdgeInsets.fromLTRB(
              22,
              14,
              22,
              26,
            ),
            decoration:
                const BoxDecoration(
              color:
                  backgroundColor,
              borderRadius:
                  BorderRadius.vertical(
                top:
                    Radius.circular(
                  28,
                ),
              ),
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration:
                      BoxDecoration(
                    color:
                        lightPurple,
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 24,
                ),

                Container(
                  width: 66,
                  height: 66,
                  decoration:
                      const BoxDecoration(
                    shape:
                        BoxShape.circle,
                    color:
                        selectedPurple,
                  ),
                  child:
                      const Icon(
                    Icons
                        .track_changes_rounded,
                    color:
                        primaryPurple,
                    size:
                        34,
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),

                const Text(
                  'Enable Weight Management?',
                  textAlign:
                      TextAlign.center,
                  style:
                      TextStyle(
                    color:
                        darkPurple,
                    fontSize:
                        22,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),

                const Text(
                  'Weight management is not currently enabled. '
                  'Enable it to set your weight goal, body information '
                  'and activity level.',
                  textAlign:
                      TextAlign.center,
                  style:
                      TextStyle(
                    color:
                        mediumPurple,
                    fontSize:
                        14,
                    height:
                        1.45,
                  ),
                ),

                const SizedBox(
                  height: 24,
                ),

                SizedBox(
                  width:
                      double.infinity,
                  height:
                      52,
                  child:
                      ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(
                        sheetContext,
                      );

                      await _enableWeightManagement();
                    },
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          primaryPurple,
                      foregroundColor:
                          Colors.white,
                      elevation:
                          0,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          17,
                        ),
                      ),
                    ),
                    child:
                        const Text(
                      'Enable Weight Management',
                      style:
                          TextStyle(
                        fontSize:
                            16,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                SizedBox(
                  width:
                      double.infinity,
                  height:
                      48,
                  child:
                      TextButton(
                    onPressed: () {
                      Navigator.pop(
                        sheetContext,
                      );
                    },
                    child:
                        const Text(
                      'Cancel',
                      style:
                          TextStyle(
                        color:
                            mediumPurple,
                        fontSize:
                            15,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =====================================================
  // ENABLE WEIGHT MANAGEMENT
  // =====================================================

  Future<void> _enableWeightManagement() async {
    final bool oldGeneralNutrition =
        widget.data.generalNutrition;

    setState(() {
      widget.data.weightManagement =
          true;

      widget.data.generalNutrition =
          false;
    });

    await _openWeightManagementSettings();

    if (!mounted) {
      return;
    }

    if (!_hasCompleteWeightManagementData) {
      setState(() {
        widget.data.weightManagement =
            false;

        widget.data.generalNutrition =
            oldGeneralNutrition;
      });
    } else {
      setState(() {});
    }
  }

  // =====================================================
  // HERO CARD DATA
  // =====================================================

  String get _email {
    final String saved = widget.data.email.trim();

    if (saved.isNotEmpty) return saved;

    return AuthService.currentEmail ?? '';
  }

  /// The user's health areas as (label, icon); "General
  /// nutrition" when none is selected.
  List<(String, IconData)> get _healthFocus {
    final ProfileSetupData d = widget.data;

    final IconData weightIcon = switch (d.weightGoal) {
      'Lose weight' => Icons.trending_down_rounded,
      'Gain weight' => Icons.trending_up_rounded,
      'Maintain weight' => Icons.drag_handle_rounded,
      _ => Icons.track_changes_rounded,
    };

    final List<(String, IconData)> areas = <(String, IconData)>[
      if (d.diabetes) ('Diabetes', Icons.water_drop_outlined),
      if (d.hypertension) ('Hypertension', Icons.monitor_heart_outlined),
      if (d.highCholesterol) ('High cholesterol', Icons.favorite_border_rounded),
      if (d.weightManagement) ('Weight management', weightIcon),
    ];

    if (areas.isEmpty) {
      return const <(String, IconData)>[('General nutrition', Icons.eco_outlined)];
    }

    return areas;
  }

  // =====================================================
  // PROFILE PICTURE
  // =====================================================
  //
  // Gallery -> square 320 px JPEG (ProfilePhotoService)
  // -> shown at once and saved to Firestore
  // (UserProfileService.saveAvatar), so it is the same on
  // every phone the user logs in on.

  bool _savingPhoto = false;

  Future<void> _pickFromGallery() async {
    final ScaffoldMessengerState messenger =
        ScaffoldMessenger.of(context);

    setState(() => _savingPhoto = true);

    Uint8List? photo;

    try {
      photo = await ProfilePhotoService.pickFromGallery();
    } on ProfilePhotoException catch (error) {
      _showSnack(messenger, error.message);
    } finally {
      if (mounted) setState(() => _savingPhoto = false);
    }

    // Closed the gallery without choosing.
    if (photo == null || !mounted) return;

    setState(() => widget.data.avatarPhoto = photo);

    UserProfileService.saveAvatar(photo);

    _showSnack(messenger, 'Profile picture updated.');
  }

  void _removePhoto() {
    setState(() => widget.data.avatarPhoto = null);

    UserProfileService.saveAvatar(null);

    _showSnack(ScaffoldMessenger.of(context), 'Profile picture removed.');
  }

  void _showSnack(
    ScaffoldMessengerState messenger,
    String message,
  ) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: primaryPurple,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // =====================================================
  // AVATAR OPTIONS
  // =====================================================

  void _openAvatarOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          Colors.transparent,
      builder: (
        BuildContext sheetContext,
      ) {
        return SafeArea(
          top: false,
          child: Container(
            padding:
                const EdgeInsets.fromLTRB(
              22,
              14,
              22,
              26,
            ),
            decoration:
                const BoxDecoration(
              color:
                  backgroundColor,
              borderRadius:
                  BorderRadius.vertical(
                top:
                    Radius.circular(
                  28,
                ),
              ),
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration:
                        BoxDecoration(
                      color:
                          lightPurple,
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                const Text(
                  'Change profile picture',
                  style:
                      TextStyle(
                    color:
                        darkPurple,
                    fontSize:
                        22,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),

                const SizedBox(
                  height: 6,
                ),

                Text(
                  widget.data.avatarPhoto == null
                      ? 'Upload your own picture from your device.'
                      : 'Choose a new picture or remove the current one.',
                  style:
                      TextStyle(
                    color:
                        mediumPurple,
                    fontSize:
                        14,
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),

                _AvatarOption(
                  icon:
                      Icons.photo_library_outlined,
                  title:
                      'Upload from gallery',
                  subtitle:
                      'Choose a photo from your device',
                  onTap: () {
                    Navigator.pop(
                      sheetContext,
                    );

                    _pickFromGallery();
                  },
                ),

                if (widget.data.avatarPhoto != null) ...[
                  const SizedBox(
                    height: 10,
                  ),

                  _AvatarOption(
                    icon:
                        Icons.delete_outline_rounded,
                    title:
                        'Remove photo',
                    subtitle:
                        'Go back to the NutriPal icon',
                    onTap: () {
                      Navigator.pop(
                        sheetContext,
                      );

                      _removePhoto();
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // =====================================================
  // LOGOUT
  // =====================================================

  Future<void> _logout() async {
    final bool? logout =
        await showDialog<bool>(
      context: context,
      builder: (
        BuildContext dialogContext,
      ) {
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
          title:
              const Text(
            'Log out?',
            style:
                TextStyle(
              color:
                  darkPurple,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          content:
              const Text(
            'Are you sure you want to log out of NutriPal?',
            style:
                TextStyle(
              color:
                  mediumPurple,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child:
                  const Text(
                'Cancel',
              ),
            ),

            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child:
                  const Text(
                'Log out',
                style:
                    TextStyle(
                  color:
                      logoutRed,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (logout != true || !mounted) {
      return;
    }

    await AuthService.signOut();

    if (!mounted) {
      return;
    }

    // Back to the login screen, with no way to go "back"
    // into the signed-in app.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (
          context,
        ) =>
            const LoginScreen(),
      ),
      (Route<dynamic> route) => false,
    );
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return ColoredBox(
      color:
          backgroundColor,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics:
              const ClampingScrollPhysics(),
          // Room for the floating navigation bar.
          padding: EdgeInsets.fromLTRB(
            20,
            26,
            20,
            28 +
                MediaQuery.paddingOf(
                  context,
                ).bottom,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // =================================================
              // PROFILE HERO CARD
              // =================================================
              //
              // Photo (tap to change), name, email and the
              // health areas NutriPal checks for.

              _ProfileHeroCard(
                photo: widget.data.avatarPhoto,
                name: _displayName,
                email: _email,
                healthFocus: _healthFocus,
                savingPhoto: _savingPhoto,
                onEditPhoto: _openAvatarOptions,
              ),

              const SizedBox(
                height: 24,
              ),

              // =================================================
              // ACCOUNT
              // =================================================

              const Text(
                'Account',
                style:
                    TextStyle(
                  color:
                      darkPurple,
                  fontSize:
                      19,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              _MenuGroup(
                children: [
                  _ProfileMenuTile(
                    icon:
                        Icons.person_outline_rounded,
                    title:
                        'My Account',
                    subtitle:
                        'View account',
                    onTap:
                        _openMyAccount,
                  ),

                  const Divider(
                    height: 1,
                    color:
                        lightPurple,
                  ),

                  _ProfileMenuTile(
                    icon:
                        Icons.lock_outline_rounded,
                    title:
                        'Security',
                    subtitle:
                        'Change your password',
                    onTap:
                        _openSecurity,
                  ),
                ],
              ),

              const SizedBox(
                height: 22,
              ),

              // =================================================
              // YOUR SCANS
              // =================================================

              const Text(
                'Your Scans',
                style:
                    TextStyle(
                  color:
                      darkPurple,
                  fontSize:
                      19,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              _MenuGroup(
                children: [
                  _ProfileMenuTile(
                    icon:
                        Icons.history_rounded,
                    title:
                        'Scan History',
                    subtitle:
                        'Scans from the last 90 days',
                    onTap:
                        _openScanHistory,
                  ),
                ],
              ),

              const SizedBox(
                height: 22,
              ),

              // =================================================
              // HEALTH
              // =================================================

              const Text(
                'Health & Nutrition Goals',
                style:
                    TextStyle(
                  color:
                      darkPurple,
                  fontSize:
                      19,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              _MenuGroup(
                children: [
                  _ProfileMenuTile(
                    icon:
                        Icons.monitor_heart_outlined,
                    title:
                        'Health Conditions',
                    subtitle:
                        _healthConditions,
                    onTap:
                        _openHealthConditionsSettings,
                  ),

                  const Divider(
                    height: 1,
                    color:
                        lightPurple,
                  ),

                  _ProfileMenuTile(
                    icon:
                        Icons.track_changes_rounded,
                    title:
                        'Weight Management Goal',
                    subtitle:
                        _weightManagementSubtitle,
                    onTap:
                        _handleWeightManagementTap,
                  ),
                ],
              ),

              // =================================================
              // LOGOUT
              // =================================================
              //
              // Set apart from the menu groups (extra space and
              // a divider) and styled as an action button, not
              // a menu row, so it is not read as part of
              // Health & Nutrition Goals.

              const SizedBox(
                height: 30,
              ),

              const Divider(
                height: 1,
                thickness: 1,
                color:
                    lightPurple,
              ),

              const SizedBox(
                height: 24,
              ),

              _LogoutButton(
                onPressed: _logout,
                color: logoutRed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =======================================================
// LOGOUT BUTTON
// =======================================================
//
// A centred, soft-red action button. Unlike the menu rows
// (white card, icon on the left, arrow on the right) it
// has a filled tint, centred text and no arrow, so it
// reads as an action that ends the session. Tapping it
// still asks "Log out?" first.
// =======================================================

class _LogoutButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Color color;

  const _LogoutButton({
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color.withValues(
            alpha: 0.10,
          ),
          foregroundColor: color,
          overlayColor: color,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              16,
            ),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        icon: const Icon(
          Icons.logout_rounded,
          size: 22,
        ),
        label: const Text(
          'Log out',
        ),
      ),
    );
  }
}

// =======================================================
// MENU GROUP
// =======================================================

class _MenuGroup extends StatelessWidget {
  final List<Widget> children;

  const _MenuGroup({
    required this.children,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
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
              const Color(
            0xFFDCCFF0,
          ),
        ),
      ),
      child: Column(
        children:
            children,
      ),
    );
  }
}

// =======================================================
// PROFILE MENU TILE
// =======================================================

class _ProfileMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color:
          Colors.transparent,
      child: InkWell(
        onTap:
            onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFFF3ECFF,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                child: Icon(
                  icon,
                  color:
                      const Color(
                    0xFF4B2E83,
                  ),
                  size:
                      25,
                ),
              ),

              const SizedBox(
                width: 13,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          const TextStyle(
                        color:
                            Color(
                          0xFF38138C,
                        ),
                        fontSize:
                            16,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),

                    const SizedBox(
                      height: 2,
                    ),

                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        color:
                            Color(
                          0xFF67558E,
                        ),
                        fontSize:
                            13,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.chevron_right_rounded,
                color:
                    Color(
                  0xFF4B2E83,
                ),
                size:
                    25,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =======================================================
// AVATAR OPTION
// =======================================================

class _AvatarOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AvatarOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return InkWell(
      onTap:
          onTap,
      borderRadius:
          BorderRadius.circular(
        16,
      ),
      child: Container(
        padding:
            const EdgeInsets.all(
          14,
        ),
        decoration:
            BoxDecoration(
          color:
              Colors.white,
          borderRadius:
              BorderRadius.circular(
            16,
          ),
          border:
              Border.all(
            color:
                const Color(
              0xFFDCCFF0,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFFF3ECFF,
                ),
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
              child: Icon(
                icon,
                color:
                    const Color(
                  0xFF4B2E83,
                ),
                size:
                    24,
              ),
            ),

            const SizedBox(
              width: 13,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:
                        const TextStyle(
                      color:
                          Color(
                        0xFF38138C,
                      ),
                      fontSize:
                          15,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),

                  const SizedBox(
                    height: 2,
                  ),

                  Text(
                    subtitle,
                    style:
                        const TextStyle(
                      color:
                          Color(
                        0xFF67558E,
                      ),
                      fontSize:
                          12.5,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.chevron_right_rounded,
              color:
                  Color(
                0xFF4B2E83,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =======================================================
// PROFILE HERO CARD
// =======================================================
//
// Purple card at the top of Profile, in the same style as
// the "Scan a nutrition label" banner on Home.

class _ProfileHeroCard extends StatelessWidget {
  final Uint8List? photo;
  final String name;
  final String email;
  final List<(String, IconData)> healthFocus;
  final bool savingPhoto;
  final VoidCallback onEditPhoto;

  const _ProfileHeroCard({
    required this.photo,
    required this.name,
    required this.email,
    required this.healthFocus,
    required this.savingPhoto,
    required this.onEditPhoto,
  });

  static const TextStyle _label = TextStyle(
    color: Color(0xC7FFFFFF),
    fontSize: 12.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF38138C), Color(0xFF4B2E83), Color(0xFF67558E)],
          stops: <double>[0, 0.55, 1],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF4B2E83).withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles, as on the Home banner.
          Positioned(
            right: -60,
            top: -70,
            child: _circle(200, const Color(0xFFE4D9F7).withValues(alpha: 0.14)),
          ),
          Positioned(
            right: 40,
            bottom: -50,
            child: _circle(120, const Color(0xFFF3ECFF).withValues(alpha: 0.10)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _photo(),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('MY PROFILE', style: _label),
                          const SizedBox(height: 4),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (email.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xD9FFFFFF),
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text('YOUR HEALTH FOCUS', style: _label),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (String label, IconData icon) in healthFocus)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, color: Colors.white, size: 15),
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _circle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );

  Widget _photo() {
    return SizedBox(
      width: 86,
      height: 86,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: GestureDetector(
              onTap: onEditPhoto,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ProfileAvatar(
                    photo: photo,
                    size: 80,
                    borderWidth: 3,
                    borderColor: Colors.white,
                  ),

                  // While a new photo is being prepared.
                  if (savingPhoto)
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Color(0xFF4B2E83),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Semantics(
              button: true,
              label: 'Change profile picture',
              child: GestureDetector(
                onTap: onEditPhoto,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0F8F8A),
                    border: Border.all(color: const Color(0xFF4B2E83), width: 3),
                  ),
                  child: const Icon(Icons.edit_outlined, color: Colors.white, size: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
