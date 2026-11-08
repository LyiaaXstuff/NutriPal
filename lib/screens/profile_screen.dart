import 'package:flutter/material.dart';

import '../models/profile_setup_data.dart';
import '../services/auth_service.dart';
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
  // COMING SOON
  // =====================================================

  void _showComingSoon(
    String feature,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$feature will be connected next.',
        ),
        backgroundColor:
            primaryPurple,
        behavior:
            SnackBarBehavior.floating,
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

                const Text(
                  'Upload your own picture from your device.',
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

                    _showComingSoon(
                      'Gallery upload',
                    );
                  },
                ),
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
            10,
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
              // PROFILE IMAGE
              // =================================================

              Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: Stack(
                        children: [
                          Align(
                            alignment:
                                Alignment.center,
                            child: Container(
                              width: 84,
                              height: 84,
                              decoration:
                                  BoxDecoration(
                                shape:
                                    BoxShape.circle,
                                color:
                                    selectedPurple,
                                border:
                                    Border.all(
                                  color:
                                      primaryPurple,
                                  width:
                                      2.2,
                                ),
                              ),
                              child:
                                  const Icon(
                                Icons.person_rounded,
                                color:
                                    Color(
                                  0xFFB79BEA,
                                ),
                                size:
                                    60,
                              ),
                            ),
                          ),

                          Positioned(
                            right: 1,
                            bottom: 7,
                            child:
                                GestureDetector(
                              onTap:
                                  _openAvatarOptions,
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration:
                                    BoxDecoration(
                                  shape:
                                      BoxShape.circle,
                                  color:
                                      primaryPurple,
                                  border:
                                      Border.all(
                                    color:
                                        backgroundColor,
                                    width:
                                        3,
                                  ),
                                ),
                                child:
                                    const Icon(
                                  Icons.edit_outlined,
                                  color:
                                      Colors.white,
                                  size:
                                      16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Text(
                      _displayName,
                      style:
                          const TextStyle(
                        color:
                            darkPurple,
                        fontSize:
                            21,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 20,
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