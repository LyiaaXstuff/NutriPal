import 'package:flutter/material.dart';

class NutripalNavigationBar extends StatelessWidget {
  final int selectedIndex;

  final VoidCallback onHomeTap;
  final VoidCallback onHistoryTap;
  final VoidCallback onScanTap;
  final VoidCallback onCompareTap;
  final VoidCallback onProfileTap;

  const NutripalNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onHomeTap,
    required this.onHistoryTap,
    required this.onScanTap,
    required this.onCompareTap,
    required this.onProfileTap,
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

  static const Color borderPurple =
      Color(0xFFDCCFF0);

  // Active state
  static const Color selectedTeal =
      Color(0xFF17B6B1);

  static const Color darkTeal =
      Color(0xFF0D9E9A);

  static const Color lightTeal =
      Color(0xFFE4F8F7);

  // =====================================================
  // LIQUID BLOB POSITION
  // =====================================================

  double _getBlobLeft({
    required int index,
    required double totalWidth,
  }) {
    const double scanSpace = 82;
    const double blobWidth = 56;

    final double availableWidth =
        totalWidth - scanSpace;

    final double itemWidth =
        availableWidth / 4;

    switch (index) {
      case 0:
        return (itemWidth / 2) -
            (blobWidth / 2);

      case 1:
        return (itemWidth * 1.5) -
            (blobWidth / 2);

      case 3:
        return (itemWidth * 2.5) +
            scanSpace -
            (blobWidth / 2);

      case 4:
        return (itemWidth * 3.5) +
            scanSpace -
            (blobWidth / 2);

      default:
        return (totalWidth / 2) -
            (blobWidth / 2);
    }
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
        14,
        0,
        14,
        12,
      ),
      child: SizedBox(
        height: 92,
        child: LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final double totalWidth =
                constraints.maxWidth;

            final bool showLiquidBlob =
                selectedIndex != 2;

            return Stack(
              clipBehavior: Clip.none,
              alignment:
                  Alignment.bottomCenter,
              children: [
                // =================================================
                // WHITE NAVIGATION BACKGROUND
                // =================================================
                Container(
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(
                      36,
                    ),
                    border: Border.all(
                      color: borderPurple,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            primaryPurple
                                .withValues(
                          alpha: 0.08,
                        ),
                        blurRadius: 18,
                        offset: const Offset(
                          0,
                          5,
                        ),
                      ),
                    ],
                  ),
                ),

                // =================================================
                // MOVING LIQUID BLOB
                // =================================================
                AnimatedPositioned(
                  duration: const Duration(
                    milliseconds: 450,
                  ),
                  curve:
                      Curves.easeInOutCubic,
                  left: _getBlobLeft(
                    index: selectedIndex,
                    totalWidth: totalWidth,
                  ),
                  bottom: 28,
                  child: AnimatedOpacity(
                    duration: const Duration(
                      milliseconds: 180,
                    ),
                    opacity:
                        showLiquidBlob
                            ? 1
                            : 0,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration:
                          BoxDecoration(
                        color: lightTeal,

                        // Slightly irregular shape
                        borderRadius:
                            const BorderRadius.only(
                          topLeft:
                              Radius.circular(
                            30,
                          ),
                          topRight:
                              Radius.circular(
                            23,
                          ),
                          bottomLeft:
                              Radius.circular(
                            21,
                          ),
                          bottomRight:
                              Radius.circular(
                            31,
                          ),
                        ),

                        border: Border.all(
                          color:
                              selectedTeal
                                  .withValues(
                            alpha: 0.20,
                          ),
                          width: 1.2,
                        ),

                        boxShadow: [
                          BoxShadow(
                            color:
                                selectedTeal
                                    .withValues(
                              alpha: 0.15,
                            ),
                            blurRadius: 12,
                            offset: const Offset(
                              0,
                              4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // =================================================
                // NAVIGATION ITEMS
                // =================================================
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 72,
                  child: Row(
                    children: [
                      // HOME
                      Expanded(
                        child:
                            _NavigationItem(
                          icon:
                              Icons.home_outlined,
                          activeIcon:
                              Icons.home_rounded,
                          label: 'Home',
                          selected:
                              selectedIndex ==
                                  0,
                          onTap:
                              onHomeTap,
                        ),
                      ),

                      // HISTORY
                      Expanded(
                        child:
                            _NavigationItem(
                          icon: Icons
                              .history_rounded,
                          activeIcon: Icons
                              .history_rounded,
                          label: 'History',
                          selected:
                              selectedIndex ==
                                  1,
                          onTap:
                              onHistoryTap,
                        ),
                      ),

                      // CENTER GAP
                      const SizedBox(
                        width: 82,
                      ),

                      // COMPARE
                      Expanded(
                        child:
                            _NavigationItem(
                          icon: Icons
                              .compare_arrows_rounded,
                          activeIcon: Icons
                              .compare_arrows_rounded,
                          label: 'Compare',
                          selected:
                              selectedIndex ==
                                  3,
                          onTap:
                              onCompareTap,
                        ),
                      ),

                      // PROFILE
                      Expanded(
                        child:
                            _NavigationItem(
                          icon: Icons
                              .person_outline_rounded,
                          activeIcon:
                              Icons.person_rounded,
                          label: 'Profile',
                          selected:
                              selectedIndex ==
                                  4,
                          onTap:
                              onProfileTap,
                        ),
                      ),
                    ],
                  ),
                ),

                // =================================================
                // CENTER SCAN BUTTON
                // =================================================
                Positioned(
                  top: -1,
                  child: GestureDetector(
                    onTap:
                        onScanTap,
                    child:
                        AnimatedContainer(
                      duration:
                          const Duration(
                        milliseconds: 380,
                      ),
                      curve:
                          Curves.easeInOutCubic,

                      width:
                          selectedIndex == 2
                              ? 80
                              : 76,

                      height:
                          selectedIndex == 2
                              ? 80
                              : 76,

                      transform:
                          Matrix4.translationValues(
                        0,
                        selectedIndex == 2
                            ? -5
                            : 0,
                        0,
                      ),

                      decoration:
                          BoxDecoration(
                        shape:
                            BoxShape.circle,

                        // Purple normally
                        // Teal when selected
                        gradient:
                            LinearGradient(
                          begin:
                              Alignment.topLeft,
                          end:
                              Alignment.bottomRight,
                          colors:
                              selectedIndex ==
                                      2
                                  ? const [
                                      selectedTeal,
                                      darkTeal,
                                    ]
                                  : const [
                                      mediumPurple,
                                      primaryPurple,
                                      darkPurple,
                                    ],
                        ),

                        border: Border.all(
                          color:
                              backgroundColor,
                          width: 5,
                        ),

                        boxShadow: [
                          BoxShadow(
                            color:
                                (selectedIndex ==
                                            2
                                        ? selectedTeal
                                        : primaryPurple)
                                    .withValues(
                              alpha: 0.28,
                            ),
                            blurRadius: 15,
                            offset: const Offset(
                              0,
                              5,
                            ),
                          ),
                        ],
                      ),

                      child:
                          const Column(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .center,
                        children: [
                          Icon(
                            Icons
                                .camera_alt_outlined,
                            color:
                                Colors.white,
                            size: 28,
                          ),

                          SizedBox(
                            height: 1,
                          ),

                          Text(
                            'Scan',
                            style: TextStyle(
                              color:
                                  Colors.white,
                              fontSize: 12,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// =======================================================
// INDIVIDUAL NAVIGATION ITEM
// =======================================================

class _NavigationItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;

  final String label;

  final bool selected;

  final VoidCallback onTap;

  const _NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const Color staticPurple =
      Color(0xFF67558E);

  static const Color selectedTeal =
      Color(0xFF17B6B1);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(
          30,
        ),
        child: AnimatedContainer(
          duration: const Duration(
            milliseconds: 350,
          ),
          curve:
              Curves.easeInOutCubic,

          transform:
              Matrix4.translationValues(
            0,
            selected ? -5 : 0,
            0,
          ),

          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              // =========================
              // ICON
              // =========================
              AnimatedSwitcher(
                duration:
                    const Duration(
                  milliseconds: 230,
                ),
                transitionBuilder: (
                  child,
                  animation,
                ) {
                  return ScaleTransition(
                    scale: animation,
                    child: child,
                  );
                },
                child: Icon(
                  selected
                      ? activeIcon
                      : icon,
                  key:
                      ValueKey(
                    selected,
                  ),
                  color:
                      selected
                          ? selectedTeal
                          : staticPurple,
                  size:
                      selected
                          ? 27
                          : 25,
                ),
              ),

              const SizedBox(
                height: 3,
              ),

              // =========================
              // LABEL
              // =========================
              AnimatedDefaultTextStyle(
                duration:
                    const Duration(
                  milliseconds: 250,
                ),
                style: TextStyle(
                  color:
                      selected
                          ? selectedTeal
                          : staticPurple,
                  fontSize: 11.5,
                  fontWeight:
                      selected
                          ? FontWeight.w800
                          : FontWeight.w500,
                ),
                child:
                    Text(
                  label,
                ),
              ),

              // =========================
              // ACTIVE DOT
              // =========================
              AnimatedContainer(
                duration:
                    const Duration(
                  milliseconds: 300,
                ),
                curve:
                    Curves.easeInOutCubic,
                margin:
                    const EdgeInsets.only(
                  top: 2,
                ),
                width:
                    selected ? 5 : 0,
                height:
                    selected ? 5 : 0,
                decoration:
                    const BoxDecoration(
                  shape:
                      BoxShape.circle,
                  color:
                      selectedTeal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}