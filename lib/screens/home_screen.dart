import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/profile_setup_data.dart';
import '../models/scan_record.dart';
import '../services/scan_history_service.dart';
import '../widgets/navigation_bar.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/scan_record_card.dart';
import 'compare_screen.dart';
import 'favourites_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'saved_scan_navigation.dart';
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
// HOME SCREEN STATE
// =======================================================

class _HomeScreenState extends State<HomeScreen> {
  // =====================================================
  // NUTRIPAL COLOURS
  // =====================================================

  static const Color backgroundColor =
      Color(0xFFF7F2E9);

  // =====================================================
  // DATA
  // =====================================================

  late final ProfileSetupData _data;

  // 0 = Home
  // 1 = Favourites
  // 3 = Compare
  // 4 = Profile
  //
  // Scan is an action rather than a tab. History is not a
  // tab: Home -> Recent scans -> View all (or Profile ->
  // Scan history).
  int _selectedIndex = 0;

  // Recent scans, History and Favourites (90-day history,
  // favourites kept until removed).
  final ScanHistoryService _history =
      ScanHistoryService.instance;

  // How many scans Home shows before "View all".
  static const int _recentCount = 5;

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

    // Loads this user's saved scans and removes the ones
    // older than 90 days (favourites are kept).
    _history.load();
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

  // =====================================================
  // HISTORY / SAVED SCANS
  // =====================================================

  void _openHistory() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (
          BuildContext context,
        ) {
          return HistoryScreen(
            profile: _data,
          );
        },
      ),
    );
  }

  void _openSavedScan(ScanRecord record) {
    openSavedScan(
      context,
      record: record,
      profile: _data,
    );
  }

  Future<void> _toggleFavourite(ScanRecord record) async {
    final ScanRecord? updated =
        await _history.toggleFavourite(record.id);

    if (!mounted || updated == null) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            updated.isFavourite
                ? 'Added to favourites.'
                : 'Removed from favourites.',
          ),
          backgroundColor: const Color(0xFF4B2E83),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _openScanner() async {
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
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
          return ScanScreen(
            profile: _data,
          );
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

    // Finished scans are saved to history by the result
    // screen; Home updates through ScanHistoryService.
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
        return ListenableBuilder(
          key: const ValueKey('home'),
          listenable: _history,
          builder: (
            BuildContext context,
            Widget? child,
          ) {
            return _HomeTab(
              displayName: _displayName,
              avatarPhoto: _data.avatarPhoto,
              recentScans:
                  _history.recent(_recentCount),
              onProfileTap: () {
                _selectTab(4);
              },
              onScanTap: _openScanner,
              onViewAll: _openHistory,
              onOpenScan: _openSavedScan,
              onFavouriteTap: _toggleFavourite,
            );
          },
        );

      // =================================================
      // FAVOURITES
      // =================================================
      case 1:
        return FavouritesScreen(
          key: const ValueKey('favourites'),
          profile: _data,
        );

      // =================================================
      // COMPARE
      // =================================================
      case 3:
        return CompareScreen(
          key: const ValueKey('compare'),
          profile: _data,
          onScanTap: _openScanner,
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

      // Pages scroll behind the floating glass bar.
      extendBody: true,

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

        onFavouritesTap: () {
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

  // Profile picture (null = NutriPal person icon).
  final Uint8List? avatarPhoto;

  // Latest few scans only; the full list is History.
  final List<ScanRecord> recentScans;

  final VoidCallback onProfileTap;
  final VoidCallback onScanTap;
  final VoidCallback onViewAll;
  final ValueChanged<ScanRecord> onOpenScan;
  final ValueChanged<ScanRecord> onFavouriteTap;

  const _HomeTab({
    required this.displayName,
    required this.avatarPhoto,
    required this.recentScans,
    required this.onProfileTap,
    required this.onScanTap,
    required this.onViewAll,
    required this.onOpenScan,
    required this.onFavouriteTap,
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

  // Left/right page padding (the carousel bleeds past it).
  static const double _pagePadding = 22;

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
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final List<ScanRecord> recent =
        recentScans;

    return ColoredBox(
      color: backgroundColor,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          // Room for the floating navigation bar.
          padding: EdgeInsets.fromLTRB(
            _pagePadding,
            22,
            _pagePadding,
            30 +
                MediaQuery.paddingOf(
                  context,
                ).bottom,
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
                    child: ProfileAvatar(
                      photo: avatarPhoto,
                      size: 58,
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
                  // White round button with a soft
                  // purple outline.
                  Material(
                    color: Colors.white,
                    shape: const CircleBorder(
                      side: BorderSide(
                        color: lightPurple,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      tooltip: 'Notifications',
                      onPressed: () {
                        _showMessage(
                          context,
                          'Notifications will be connected next.',
                        );
                      },
                      constraints:
                          const BoxConstraints.tightFor(
                        width: 48,
                        height: 48,
                      ),
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons
                            .notifications_none_rounded,
                        color: darkPurple,
                        size: 25,
                      ),
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
                      onPressed: onViewAll,
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
              // EMPTY / RECENT CAROUSEL
              // =================================================
              //
              // Swipe sideways; the row runs to the screen
              // edges so the next card peeks in.
              if (recent.isEmpty)
                const _EmptyRecentScans()
              else
                _RecentScansCarousel(
                  scans: recent,
                  sidePadding: _pagePadding,
                  onOpenScan: onOpenScan,
                  onFavouriteTap: onFavouriteTap,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// =======================================================
// RECENT SCANS CAROUSEL
// =======================================================

class _RecentScansCarousel extends StatelessWidget {
  final List<ScanRecord> scans;

  // The page padding, so the row can reach the screen
  // edges while the first card still lines up with the
  // title.
  final double sidePadding;

  final ValueChanged<ScanRecord> onOpenScan;
  final ValueChanged<ScanRecord> onFavouriteTap;

  const _RecentScansCarousel({
    required this.scans,
    required this.sidePadding,
    required this.onOpenScan,
    required this.onFavouriteTap,
  });

  @override
  Widget build(BuildContext context) {
    // +2 so the tile's 1 px border is not clipped.
    const double height = ScanRecordTile.height + 2;

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) {
          final double fullWidth = box.maxWidth + sidePadding * 2;

          return OverflowBox(
            minWidth: fullWidth,
            maxWidth: fullWidth,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: sidePadding,
                vertical: 1,
              ),
              itemCount: scans.length,
              separatorBuilder: (BuildContext context, int index) =>
                  const SizedBox(width: 12),
              itemBuilder: (BuildContext context, int index) {
                final ScanRecord scan = scans[index];

                return ScanRecordTile(
                  record: scan,
                  onTap: () => onOpenScan(scan),
                  onFavouriteTap: () => onFavouriteTap(scan),
                );
              },
            ),
          );
        },
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
