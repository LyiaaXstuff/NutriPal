import 'package:flutter/material.dart';

import '../models/profile_setup_data.dart';
import '../widgets/navigation_bar.dart';
import 'profile_screen.dart';
import 'scan_screen.dart';

class HomeScreen extends StatefulWidget {
  final ProfileSetupData? data;
  final String? userName;

  const HomeScreen({
    super.key,
    this.data,
    this.userName,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// =======================================================
// RECENT SCAN MODEL
// =======================================================

class RecentScanItem {
  final String productName;
  final DateTime scannedAt;
  final IconData icon;

  const RecentScanItem({
    required this.productName,
    required this.scannedAt,
    required this.icon,
  });
}

// =======================================================
// HOME SCREEN STATE
// =======================================================

class _HomeScreenState extends State<HomeScreen> {
  // =====================================================
  // NUTRIPAL COLOURS
  // =====================================================

  static const Color backgroundColor =
      Color(0xFFF7F2E9);

  static const Color primaryPurple =
      Color(0xFF4B2E83);

  // =====================================================
  // DATA
  // =====================================================

  late final ProfileSetupData _data;

  // 0 = Home
  // 1 = History
  // 3 = Compare
  // 4 = Profile
  //
  // Scan is an action rather than a tab.
  int _selectedIndex = 0;

  final List<RecentScanItem> _recentScans = [];

  // =====================================================
  // INIT
  // =====================================================

  @override
  void initState() {
    super.initState();

    _data = widget.data ?? ProfileSetupData();

    if (_data.nickname.trim().isEmpty &&
        widget.userName != null &&
        widget.userName!.trim().isNotEmpty) {
      _data.nickname = widget.userName!.trim();
    }
  }

  // =====================================================
  // SELECT TAB
  // =====================================================

  void _selectTab(int index) {
    if (_selectedIndex == index) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  // =====================================================
  // DISPLAY NAME
  // =====================================================

  String get _displayName {
    if (_data.nickname.trim().isEmpty) {
      return 'NutriPal User';
    }

    return _data.nickname.trim();
  }

  // =====================================================
  // OPEN SCANNER
  // =====================================================

  Future<void> _openScanner() async {
    final String? imagePath =
        await Navigator.of(context).push<String>(
      PageRouteBuilder<String>(
        transitionDuration: const Duration(
          milliseconds: 220,
        ),
        reverseTransitionDuration: const Duration(
          milliseconds: 180,
        ),
        pageBuilder: (
          context,
          animation,
          secondaryAnimation,
        ) {
          return const ScanScreen();
        },

        // Fade only.
        // No default left/right page slide.
        transitionsBuilder: (
          context,
          animation,
          secondaryAnimation,
          child,
        ) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          );
        },
      ),
    );

    if (imagePath == null || !mounted) {
      return;
    }

    // Later:
    // Send imagePath to OCR / nutrition-label extraction.

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Image captured. Nutrition label processing will be connected next.',
        ),
        backgroundColor: primaryPurple,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // =====================================================
  // BUILD CURRENT PAGE
  // =====================================================

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      // =================================================
      // HOME
      // =================================================
      case 0:
        return _HomeTab(
          key: const ValueKey('home'),
          displayName: _displayName,
          recentScans: _recentScans,
          onProfileTap: () {
            _selectTab(4);
          },
          onScanTap: _openScanner,
        );

      // =================================================
      // HISTORY
      // =================================================
      case 1:
        return const _SimpleTabPage(
          key: ValueKey('history'),
          icon: Icons.history_rounded,
          title: 'History',
          description:
              'Your scanned products will appear here.',
        );

      // =================================================
      // COMPARE
      // =================================================
      case 3:
        return const _SimpleTabPage(
          key: ValueKey('compare'),
          icon: Icons.compare_arrows_rounded,
          title: 'Compare',
          description:
              'Compare scanned products and their nutrition information here.',
        );

      // =================================================
      // PROFILE
      // =================================================
      case 4:
        return ProfileScreen(
          key: const ValueKey('profile'),
          data: _data,
        );

      default:
        return const SizedBox();
    }
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      // =================================================
      // SMOOTH MAIN TAB TRANSITION
      // =================================================
      body: AnimatedSwitcher(
        duration: const Duration(
          milliseconds: 320,
        ),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,

        // Fade only.
        // No page slide.
        transitionBuilder: (
          Widget child,
          Animation<double> animation,
        ) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },

        child: _buildCurrentPage(),
      ),

      // =================================================
      // PERMANENT NAVIGATION BAR
      // =================================================
      bottomNavigationBar: NutripalNavigationBar(
        selectedIndex: _selectedIndex,

        onHomeTap: () {
          _selectTab(0);
        },

        onHistoryTap: () {
          _selectTab(1);
        },

        // Opens scanner.
        // Does not change the current main tab.
        onScanTap: _openScanner,

        onCompareTap: () {
          _selectTab(3);
        },

        onProfileTap: () {
          _selectTab(4);
        },
      ),
    );
  }
}

// =======================================================
// HOME TAB
// =======================================================

class _HomeTab extends StatelessWidget {
  final String displayName;
  final List<RecentScanItem> recentScans;

  final VoidCallback onProfileTap;
  final VoidCallback onScanTap;

  const _HomeTab({
    super.key,
    required this.displayName,
    required this.recentScans,
    required this.onProfileTap,
    required this.onScanTap,
  });

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

  // =====================================================
  // MESSAGE
  // =====================================================

  void _showMessage(
    BuildContext context,
    String message,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
        ),
        backgroundColor: primaryPurple,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // =====================================================
  // FORMAT DATE
  // =====================================================

  String _formatDate(DateTime date) {
    const List<String> months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final int hour = date.hour == 0
        ? 12
        : date.hour > 12
            ? date.hour - 12
            : date.hour;

    final String minute =
        date.minute.toString().padLeft(
              2,
              '0',
            );

    final String period =
        date.hour >= 12 ? 'PM' : 'AM';

    return '${date.day} '
        '${months[date.month - 1]} '
        '${date.year}, '
        '$hour:$minute $period';
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final List<RecentScanItem> recent =
        recentScans.take(3).toList();

    return ColoredBox(
      color: backgroundColor,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            22,
            22,
            22,
            30,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // =================================================
              // HEADER
              // =================================================
              Row(
                children: [
                  // =============================================
                  // PROFILE AVATAR
                  // =============================================
                  GestureDetector(
                    onTap: onProfileTap,
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selectedPurple,
                        border: Border.all(
                          color: primaryPurple,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Color(
                          0xFFB79BEA,
                        ),
                        size: 40,
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 14,
                  ),

                  // =============================================
                  // GREETING
                  // =============================================
                  Expanded(
                    child: Text(
                      'Hi, $displayName!',
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: darkPurple,
                        fontSize: 25,
                        height: 1.05,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                  ),

                  // =============================================
                  // NOTIFICATIONS
                  // =============================================
                  IconButton(
                    onPressed: () {
                      _showMessage(
                        context,
                        'Notifications will be connected next.',
                      );
                    },
                    icon: const Icon(
                      Icons
                          .notifications_none_rounded,
                      color: darkPurple,
                      size: 32,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 26,
              ),

              // =================================================
              // SCAN BANNER
              // =================================================
              Container(
                width: double.infinity,
                height: 218,
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(
                    24,
                  ),
                  gradient:
                      const LinearGradient(
                    begin:
                        Alignment.topLeft,
                    end:
                        Alignment.bottomRight,
                    colors: [
                      darkPurple,
                      primaryPurple,
                      mediumPurple,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          primaryPurple.withValues(
                        alpha: 0.16,
                      ),
                      blurRadius: 14,
                      offset: const Offset(
                        0,
                        6,
                      ),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior:
                      Clip.hardEdge,
                  children: [
                    // =============================================
                    // LARGE DECORATIVE CIRCLE
                    // =============================================
                    Positioned(
                      right: -45,
                      bottom: -70,
                      child: Container(
                        width: 210,
                        height: 210,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              lightPurple.withValues(
                            alpha: 0.16,
                          ),
                        ),
                      ),
                    ),

                    // =============================================
                    // SMALL DECORATIVE CIRCLE
                    // =============================================
                    Positioned(
                      right: 52,
                      top: 20,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              selectedPurple.withValues(
                            alpha: 0.12,
                          ),
                        ),
                      ),
                    ),

                    // =============================================
                    // NUTRITION LABEL ILLUSTRATION
                    // =============================================
                    Positioned(
                      right: 20,
                      top: 35,
                      child: Transform.rotate(
                        angle: 0.11,
                        child:
                            const _NutritionLabelIllustration(),
                      ),
                    ),

                    // =============================================
                    // TEXT & BUTTON
                    // =============================================
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(
                        22,
                        22,
                        22,
                        18,
                      ),
                      child: SizedBox(
                        width:
                            MediaQuery.of(context)
                                    .size
                                    .width *
                                0.52,
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Scan a nutrition label',
                              style: TextStyle(
                                color:
                                    Colors.white,
                                fontSize: 25,
                                height: 1.05,
                                fontWeight:
                                    FontWeight.w900,
                              ),
                            ),

                            const SizedBox(
                              height: 9,
                            ),

                            Text(
                              'Get personalised insights\nbefore buying or eating.',
                              style: TextStyle(
                                color:
                                    Colors.white
                                        .withValues(
                                  alpha: 0.88,
                                ),
                                fontSize: 16,
                                height: 1.30,
                              ),
                            ),

                            const Spacer(),

                            // =====================================
                            // SCAN NOW
                            // =====================================
                            SizedBox(
                              width:
                                  double.infinity,
                              height: 48,
                              child:
                                  ElevatedButton.icon(
                                onPressed:
                                    onScanTap,
                                icon: const Icon(
                                  Icons
                                      .camera_alt_outlined,
                                  size: 26,
                                ),
                                label:
                                    const Text(
                                  'Scan now',
                                  style:
                                      TextStyle(
                                    fontSize: 17,
                                    fontWeight:
                                        FontWeight.w800,
                                  ),
                                ),
                                style:
                                    ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.white,
                                  foregroundColor:
                                      primaryPurple,
                                  elevation: 0,
                                  shape:
                                      RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(
                                      16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 24,
              ),

              // =================================================
              // RECENT SCANS
              // =================================================
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Recent scans',
                      style: TextStyle(
                        color: darkPurple,
                        fontSize: 22,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                  ),

                  if (recentScans.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        _showMessage(
                          context,
                          'Scan history will be connected next.',
                        );
                      },
                      style:
                          TextButton.styleFrom(
                        foregroundColor:
                            primaryPurple,
                      ),
                      child: const Row(
                        children: [
                          Text(
                            'View all',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),

                          SizedBox(
                            width: 2,
                          ),

                          Icon(
                            Icons
                                .chevron_right_rounded,
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(
                height: 8,
              ),

              // =================================================
              // EMPTY / RECENT LIST
              // =================================================
              if (recent.isEmpty)
                const _EmptyRecentScans()
              else
                ...List.generate(
                  recent.length,
                  (index) {
                    final RecentScanItem scan =
                        recent[index];

                    return Padding(
                      padding: EdgeInsets.only(
                        bottom:
                            index ==
                                    recent.length -
                                        1
                                ? 0
                                : 10,
                      ),
                      child:
                          _RecentScanCard(
                        title:
                            scan.productName,
                        date:
                            _formatDate(
                          scan.scannedAt,
                        ),
                        icon:
                            scan.icon,
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// =======================================================
// EMPTY RECENT SCANS
// =======================================================

class _EmptyRecentScans
    extends StatelessWidget {
  const _EmptyRecentScans();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 28,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color: const Color(
            0xFFDCCFF0,
          ),
        ),
      ),
      child: const Column(
        children: [
          CircleAvatar(
            radius: 31,
            backgroundColor:
                Color(
              0xFFF3ECFF,
            ),
            child: Icon(
              Icons
                  .document_scanner_outlined,
              color: Color(
                0xFF4B2E83,
              ),
              size: 31,
            ),
          ),

          SizedBox(
            height: 14,
          ),

          Text(
            'No scans yet',
            style: TextStyle(
              color: Color(
                0xFF38138C,
              ),
              fontSize: 18,
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          SizedBox(
            height: 6,
          ),

          Text(
            'Your recently scanned products will appear here.',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              color: Color(
                0xFF756D7E,
              ),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// =======================================================
// RECENT SCAN CARD
// =======================================================

class _RecentScanCard
    extends StatelessWidget {
  final String title;
  final String date;
  final IconData icon;

  const _RecentScanCard({
    required this.title,
    required this.date,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(
        10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color: const Color(
            0xFFDCCFF0,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(
                0xFFF3ECFF,
              ),
              borderRadius:
                  BorderRadius.circular(
                13,
              ),
            ),
            child: Icon(
              icon,
              color: const Color(
                0xFF4B2E83,
              ),
              size: 30,
            ),
          ),

          const SizedBox(
            width: 14,
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
                    color: Color(
                      0xFF38138C,
                    ),
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  date,
                  style:
                      const TextStyle(
                    color: Color(
                      0xFF67558E,
                    ),
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),

          const Icon(
            Icons.chevron_right_rounded,
            color: Color(
              0xFF4B2E83,
            ),
          ),
        ],
      ),
    );
  }
}

// =======================================================
// NUTRITION LABEL ILLUSTRATION
// =======================================================

class _NutritionLabelIllustration
    extends StatelessWidget {
  const _NutritionLabelIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 105,
      height: 145,
      padding: const EdgeInsets.all(
        10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        border: Border.all(
          color: const Color(
            0xFFE4D9F7,
          ),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Nutrition Facts',
            style: TextStyle(
              color: Color(
                0xFF38138C,
              ),
              fontSize: 10,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          const SizedBox(
            height: 7,
          ),

          Container(
            height: 7,
            decoration: BoxDecoration(
              color: const Color(
                0xFF4B2E83,
              ),
              borderRadius:
                  BorderRadius.circular(
                5,
              ),
            ),
          ),

          const SizedBox(
            height: 7,
          ),

          _line(0.75),
          _line(0.90),
          _line(0.67),
          _line(0.84),
          _line(0.72),
        ],
      ),
    );
  }

  Widget _line(double width) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 6,
      ),
      child:
          FractionallySizedBox(
        widthFactor: width,
        child: Container(
          height: 6,
          decoration: BoxDecoration(
            color: const Color(
              0xFFE4D9F7,
            ),
            borderRadius:
                BorderRadius.circular(
              4,
            ),
          ),
        ),
      ),
    );
  }
}

// =======================================================
// HISTORY / COMPARE PLACEHOLDER
// =======================================================

class _SimpleTabPage
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _SimpleTabPage({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(
        0xFFF7F2E9,
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding:
                const EdgeInsets.all(
              30,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width: 78,
                  height: 78,
                  decoration:
                      const BoxDecoration(
                    shape:
                        BoxShape.circle,
                    color: Color(
                      0xFFF3ECFF,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color:
                        const Color(
                      0xFF4B2E83,
                    ),
                    size: 38,
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),

                Text(
                  title,
                  style:
                      const TextStyle(
                    color: Color(
                      0xFF38138C,
                    ),
                    fontSize: 25,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Text(
                  description,
                  textAlign:
                      TextAlign.center,
                  style:
                      const TextStyle(
                    color: Color(
                      0xFF67558E,
                    ),
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}