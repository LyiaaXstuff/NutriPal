import 'package:flutter/material.dart';

import '../models/profile_setup_data.dart';
import '../services/user_profile_service.dart';
import 'energy_details_form.dart';
import 'weight_management_form.dart';
import 'home_screen.dart';

class HealthConditionsForm
    extends StatefulWidget {
  final ProfileSetupData data;

  const HealthConditionsForm({
    super.key,
    required this.data,
  });

  @override
  State<HealthConditionsForm>
      createState() =>
          _HealthConditionsFormState();
}

class _HealthConditionsFormState
    extends State<HealthConditionsForm> {
  // =====================================================
  // CLEAR CONDITIONAL DATA
  // =====================================================
  //
  // Weight management has follow-up questions (goal, body
  // details, activity). High LDL cholesterol without weight
  // management asks the same details except the goal, for
  // the saturated fat and trans fat limits. Diabetes and
  // hypertension have none.

  // The weight goal only (weight management turned off).
  void _clearWeightGoal() {
    widget.data.weightGoal =
        null;
  }

  // Everything the energy estimate needs. Used when no
  // selected area needs it.
  void _clearWeightData() {
    widget.data.weightGoal =
        null;

    widget.data.providerEnergyKcal =
        null;

    widget.data
            .genderForEnergyEstimate =
        null;

    widget.data.currentWeight =
        null;

    widget.data.weightUnit =
        'kg';

    widget.data.height =
        null;

    widget.data.heightUnit =
        'cm';

    widget.data.activityLevel =
        null;
  }

  // =====================================================
  // TOGGLE CONDITION
  // =====================================================

  void _toggleCondition(
    String condition,
  ) {
    setState(() {
      widget.data.generalNutrition =
          false;

      switch (condition) {
        case 'diabetes':
          widget.data.diabetes =
              !widget.data.diabetes;

          break;

        case 'hypertension':
          widget.data.hypertension =
              !widget.data.hypertension;

          break;

        case 'cholesterol':
          widget.data.highCholesterol =
              !widget.data
                  .highCholesterol;

          // No area needs the energy details any more.
          if (!widget.data.highCholesterol &&
              !widget.data.weightManagement) {
            _clearWeightData();
          }

          break;

        case 'weight':
          widget.data.weightManagement =
              !widget.data
                  .weightManagement;

          if (!widget.data
              .weightManagement) {
            // Keep the body details when LDL cholesterol
            // still needs them.
            if (widget.data.highCholesterol) {
              _clearWeightGoal();
            } else {
              _clearWeightData();
            }
          }

          break;
      }
    });
  }

  // =====================================================
  // NONE OF ABOVE
  // =====================================================

  void _toggleNone() {
    setState(() {
      widget.data.generalNutrition =
          !widget.data
              .generalNutrition;

      if (widget.data
          .generalNutrition) {
        widget.data.diabetes =
            false;

        widget.data.hypertension =
            false;

        widget.data.highCholesterol =
            false;

        widget.data.weightManagement =
            false;

        _clearWeightData();
      }
    });
  }

  bool get _hasSelection {
    return widget.data.diabetes ||
        widget.data.hypertension ||
        widget.data.highCholesterol ||
        widget.data.weightManagement ||
        widget.data.generalNutrition;
  }

  // =====================================================
  // HOME
  // =====================================================

  void _goToHome() {
    // Setup finished: save the profile to Firestore.
    UserProfileService.save(widget.data);

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) =>
            HomeScreen(
          data: widget.data,
        ),
      ),
      (
        route,
      ) =>
          false,
    );
  }

  // =====================================================
  // CONTINUE
  // =====================================================

  void _continue() {
    if (!_hasSelection) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text(
            'Please select at least one option.',
          ),
        ),
      );

      return;
    }

    // NONE OF ABOVE
    if (widget.data
        .generalNutrition) {
      _goToHome();

      return;
    }

    // WEIGHT: the only area with follow-up questions
    if (widget.data
        .weightManagement) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              WeightManagementForm(
            data:
                widget.data,
          ),
        ),
      );

      return;
    }

    // HIGH LDL CHOLESTEROL WITHOUT WEIGHT MANAGEMENT:
    // the same details as weight management, no goal.
    if (widget.data
        .highCholesterol) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              EnergyDetailsForm(
            data:
                widget.data,
          ),
        ),
      );

      return;
    }

    // DIABETES AND HYPERTENSION: no follow-up questions.
    _goToHome();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          const Color(
        0xFFF7F2E9,
      ),

      body:
          SafeArea(
        bottom:
            false,
        child:
            SingleChildScrollView(
          physics:
              const ClampingScrollPhysics(),
          padding:
              const EdgeInsets.fromLTRB(
            18,
            12,
            18,
            14,
          ),
          child:
              Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // =========================
              // HEADER
              // =========================
              SizedBox(
                height:
                    36,
                child:
                    Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .spaceBetween,
                  children: [
                    SizedBox(
                      width:
                          28,
                      height:
                          28,
                      child:
                          IconButton(
                        onPressed: () {
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
                              .arrow_back_rounded,
                          color:
                              Color(
                            0xFF4B2E83,
                          ),
                          size:
                              28,
                        ),
                      ),
                    ),

                    const Text(
                      'STEP 2',
                      style:
                          TextStyle(
                        color:
                            Color(
                          0xFF67558E,
                        ),
                        fontSize:
                            18,
                        fontWeight:
                            FontWeight.w800,
                        letterSpacing:
                            0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height:
                    12,
              ),

              // =========================
              // PROGRESS
              // =========================
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
                child:
                    const LinearProgressIndicator(
                  value:
                      0.66,
                  minHeight:
                      9,
                  backgroundColor:
                      Color(
                    0xFFE4D9F7,
                  ),
                  valueColor:
                      AlwaysStoppedAnimation<
                          Color>(
                    Color(
                      0xFF4B2E83,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height:
                    14,
              ),

              // =========================
              // TITLE + MASCOT
              // =========================
              Row(
                children: [
                  // Two lines. A little more room for the
                  // title; on very narrow phones it shrinks
                  // slightly instead of wrapping to a third
                  // line.
                  const Expanded(
                    flex:
                        7,
                    child:
                        FittedBox(
                      fit:
                          BoxFit.scaleDown,
                      alignment:
                          Alignment.centerLeft,
                      child:
                          Text(
                        'What matters\nto you',
                        style:
                            TextStyle(
                          color:
                              Color(
                            0xFF38138C,
                          ),
                          fontSize:
                              34,
                          height:
                              1.03,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                    ),
                  ),

                  Expanded(
                    flex:
                        4,
                    child:
                        SizedBox(
                      height:
                          135,
                      child:
                          Image.asset(
                        'assets/images/NutriPal Mascot10.png',
                        fit:
                            BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height:
                    8,
              ),

              const Text(
                'Which health areas would you like NutriPal to support?',
                style:
                    TextStyle(
                  color:
                      Color(
                    0xFF38138C,
                  ),
                  fontSize:
                      19,
                  height:
                      1.25,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              const SizedBox(
                height:
                    4,
              ),

              const Text(
                'Select all that apply.',
                style:
                    TextStyle(
                  color:
                      Color(
                    0xFF756D7E,
                  ),
                  fontSize:
                      18,
                ),
              ),

              const SizedBox(
                height:
                    12,
              ),

              _SelectionCard(
                label:
                    'Diabetes',
                icon:
                    Icons.water_drop_outlined,
                selected:
                    widget.data.diabetes,
                onTap: () {
                  _toggleCondition(
                    'diabetes',
                  );
                },
              ),

              const SizedBox(
                height:
                    8,
              ),

              _SelectionCard(
                label:
                    'Hypertension',
                icon:
                    Icons.monitor_heart_outlined,
                selected:
                    widget.data.hypertension,
                onTap: () {
                  _toggleCondition(
                    'hypertension',
                  );
                },
              ),

              const SizedBox(
                height:
                    8,
              ),

              _SelectionCard(
                label:
                    'High LDL cholesterol',
                icon:
                    Icons.favorite_border_rounded,
                selected:
                    widget.data
                        .highCholesterol,
                onTap: () {
                  _toggleCondition(
                    'cholesterol',
                  );
                },
              ),

              const SizedBox(
                height:
                    8,
              ),

              _SelectionCard(
                label:
                    'Weight management',
                icon:
                    Icons.monitor_weight_outlined,
                selected:
                    widget.data
                        .weightManagement,
                onTap: () {
                  _toggleCondition(
                    'weight',
                  );
                },
              ),

              const SizedBox(
                height:
                    12,
              ),

              const Row(
                children: [
                  Expanded(
                    child:
                        Divider(
                      color:
                          Color(
                        0xFFD8CDEA,
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
                          0xFF8B7BA5,
                        ),
                        fontSize:
                            15,
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
                        0xFFD8CDEA,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height:
                    12,
              ),

              _SelectionCard(
                label:
                    'None of the above',
                icon:
                    Icons.remove_circle_outline,
                selected:
                    widget.data
                        .generalNutrition,
                onTap:
                    _toggleNone,
              ),
            ],
          ),
        ),
      ),

      // =========================
      // CONTINUE
      // =========================
      bottomNavigationBar:
          SafeArea(
        top:
            false,
        child:
            Container(
          color:
              const Color(
            0xFFF7F2E9,
          ),
          padding:
              const EdgeInsets.fromLTRB(
            18,
            8,
            18,
            12,
          ),
          child:
              SizedBox(
            width:
                double.infinity,
            height:
                54,
            child:
                ElevatedButton(
              onPressed:
                  _continue,
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
                    28,
                  ),
                ),
              ),
              child:
                  const Text(
                'Continue',
                style:
                    TextStyle(
                  fontSize:
                      20,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionCard
    extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SelectionCard({
    required this.label,
    required this.icon,
    required this.selected,
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
        18,
      ),
      child:
          AnimatedContainer(
        duration:
            const Duration(
          milliseconds:
              200,
        ),
        padding:
            const EdgeInsets.symmetric(
          horizontal:
              18,
          vertical:
              11,
        ),
        decoration:
            BoxDecoration(
          color:
              selected
                  ? const Color(
                      0xFFF3ECFF,
                    )
                  : Colors.white,
          borderRadius:
              BorderRadius.circular(
            18,
          ),
          border:
              Border.all(
            color:
                selected
                    ? const Color(
                        0xFF4B2E83,
                      )
                    : const Color(
                        0xFFDCCFF0,
                      ),
            width:
                selected
                    ? 1.8
                    : 1.2,
          ),
        ),
        child:
            Row(
          children: [
            Icon(
              icon,
              size:
                  26,
              color:
                  const Color(
                0xFF4B2E83,
              ),
            ),

            const SizedBox(
              width:
                  15,
            ),

            Expanded(
              child:
                  Text(
                label,
                style:
                    TextStyle(
                  color:
                      selected
                          ? const Color(
                              0xFF4B2E83,
                            )
                          : const Color(
                              0xFF514A61,
                            ),
                  fontSize:
                      17,
                  fontWeight:
                      selected
                          ? FontWeight.w800
                          : FontWeight.w500,
                ),
              ),
            ),

            AnimatedContainer(
              duration:
                  const Duration(
                milliseconds:
                    200,
              ),
              width:
                  27,
              height:
                  27,
              decoration:
                  BoxDecoration(
                color:
                    selected
                        ? const Color(
                            0xFF4B2E83,
                          )
                        : Colors.white,
                borderRadius:
                    BorderRadius.circular(
                  7,
                ),
                border:
                    Border.all(
                  color:
                      selected
                          ? const Color(
                              0xFF4B2E83,
                            )
                          : const Color(
                              0xFFB9ADCB,
                            ),
                  width:
                      2,
                ),
              ),
              child:
                  selected
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 20,
                        )
                      : null,
            ),
          ],
        ),
      ),
    );
  }
}