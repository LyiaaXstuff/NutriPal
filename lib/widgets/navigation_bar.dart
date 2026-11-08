import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

// =======================================================
// NUTRIPAL NAVIGATION BAR (floating glass)
// =======================================================
//
// Floating, detached pill with a frosted-glass surface:
// the page scrolls behind it and shows through blurred.
// The Home screen sets Scaffold(extendBody: true) so the
// content can go behind the bar; pages add
// MediaQuery.paddingOf(context).bottom to their bottom
// padding so the last item is never hidden.
// =======================================================

class NutripalNavigationBar extends StatelessWidget {
  final int selectedIndex;

  final VoidCallback onHomeTap;
  final VoidCallback onFavouritesTap;
  final VoidCallback onScanTap;
  final VoidCallback onCompareTap;
  final VoidCallback onProfileTap;

  const NutripalNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onHomeTap,
    required this.onFavouritesTap,
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
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      // Detached from the screen edges.
      minimum: const EdgeInsets.fromLTRB(
        18,
        0,
        18,
        16,
      ),
      child: SizedBox(
        height: 92,
        child: LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            return Stack(
              clipBehavior: Clip.none,
              alignment:
                  Alignment.bottomCenter,
              children: [
                // =================================================
                // FLOATING SHADOW (outside the clip)
                // =================================================
                Container(
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(
                      36,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            primaryPurple
                                .withValues(
                          alpha: 0.12,
                        ),
                        blurRadius: 30,
                        offset: const Offset(
                          0,
                          12,
                        ),
                      ),
                    ],
                  ),
                ),

                // =================================================
                // FROSTED GLASS SURFACE
                // =================================================
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(
                    36,
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 12,
                      sigmaY: 12,
                    ),
                    child: Container(
                      height: 72,
                      decoration:
                          BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(
                          36,
                        ),

                        // Milky glass with a light
                        // top edge.
                        gradient:
                            LinearGradient(
                          begin: Alignment
                              .topCenter,
                          end: Alignment
                              .bottomCenter,
                          colors: [
                            Colors.white
                                .withValues(
                              alpha: 0.30,
                            ),
                            const Color(
                              0xFFF3ECFF,
                            ).withValues(
                              alpha: 0.20,
                            ),
                          ],
                        ),

                        border: Border.all(
                          color: Colors.white
                              .withValues(
                            alpha: 0.6,
                          ),
                          width: 1.2,
                        ),
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

                      // FAVOURITES
                      // (History moved to Home ->
                      // Recent scans -> View all.)
                      Expanded(
                        child:
                            _NavigationItem(
                          icon: Icons
                              .favorite_border_rounded,
                          activeIcon: Icons
                              .favorite_rounded,
                          label: 'Favourites',
                          selected:
                              selectedIndex ==
                                  1,
                          onTap:
                              onFavouritesTap,
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

                        // Glass ring around the
                        // scan button.
                        border: Border.all(
                          color: Colors.white
                              .withValues(
                            alpha: 0.9,
                          ),
                          width: 4,
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
        // Selected = teal icon, bold label and a dot.
        // No lifting or bouncing.
        child: SizedBox(
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
                  return FadeTransition(
                    opacity: animation,
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
                  size: 25,
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
                // Shrinks a long label (Favourites)
                // on narrow phones instead of wrapping.
                child:
                    FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                  ),
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