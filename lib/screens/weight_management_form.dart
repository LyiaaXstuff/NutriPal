import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/profile_setup_data.dart';
import 'home_screen.dart';

class WeightManagementForm extends StatefulWidget {
  final ProfileSetupData data;

  const WeightManagementForm({
    super.key,
    required this.data,
  });

  @override
  State<WeightManagementForm> createState() =>
      _WeightManagementFormState();
}

class _WeightManagementFormState
    extends State<WeightManagementForm> {
  late final TextEditingController _weightController;
  late final TextEditingController _heightController;

  // =====================================================
  // INIT
  // =====================================================

  @override
  void initState() {
    super.initState();

    _normaliseUnitsToMetric();

    _weightController = TextEditingController(
      text: widget.data.currentWeight != null
          ? _formatNumber(
              widget.data.currentWeight!,
            )
          : '',
    );

    _heightController = TextEditingController(
      text: widget.data.height != null
          ? _formatNumber(
              widget.data.height!,
            )
          : '',
    );
  }

  // =====================================================
  // DISPOSE
  // =====================================================

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();

    super.dispose();
  }

  // =====================================================
  // STANDARDISE UNITS
  // =====================================================

  void _normaliseUnitsToMetric() {
    if (widget.data.weightUnit == 'lb' &&
        widget.data.currentWeight != null) {
      widget.data.currentWeight =
          widget.data.currentWeight! * 0.45359237;
    }

    if (widget.data.heightUnit == 'in' &&
        widget.data.height != null) {
      widget.data.height =
          widget.data.height! * 2.54;
    }

    widget.data.weightUnit = 'kg';
    widget.data.heightUnit = 'cm';
  }

  // =====================================================
  // FORMAT NUMBER
  // =====================================================

  String _formatNumber(
    double value,
  ) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(1);
  }

  // =====================================================
  // SELECT GOAL
  // =====================================================

  void _selectGoal(
    String goal,
  ) {
    setState(() {
      widget.data.weightGoal = goal;
    });
  }

  // =====================================================
  // SELECT GENDER
  // =====================================================

  void _selectGender(
    String gender,
  ) {
    setState(() {
      widget.data.genderForEnergyEstimate = gender;
    });
  }

  // =====================================================
  // SELECT ACTIVITY
  // =====================================================

  void _selectActivity(
    String activity,
  ) {
    setState(() {
      widget.data.activityLevel = activity;
    });
  }

  // =====================================================
  // WEIGHT CHANGE
  // =====================================================

  void _onWeightChanged(
    String value,
  ) {
    widget.data.currentWeight =
        double.tryParse(
      value,
    );
  }

  // =====================================================
  // HEIGHT CHANGE
  // =====================================================

  void _onHeightChanged(
    String value,
  ) {
    widget.data.height =
        double.tryParse(
      value,
    );
  }

  // =====================================================
  // CONTINUE
  // =====================================================

  void _continue() {
    FocusScope.of(context).unfocus();

    widget.data.currentWeight =
        double.tryParse(
      _weightController.text.trim(),
    );

    widget.data.height =
        double.tryParse(
      _heightController.text.trim(),
    );

    widget.data.weightUnit = 'kg';
    widget.data.heightUnit = 'cm';

    if (widget.data.weightGoal == null) {
      _showMessage(
        'Please select your weight goal.',
      );

      return;
    }

    if (widget.data.genderForEnergyEstimate == null) {
      _showMessage(
        'Please select your gender.',
      );

      return;
    }

    if (widget.data.currentWeight == null ||
        widget.data.currentWeight! <= 0) {
      _showMessage(
        'Please enter your current weight.',
      );

      return;
    }

    if (widget.data.height == null ||
        widget.data.height! <= 0) {
      _showMessage(
        'Please enter your height.',
      );

      return;
    }

    if (widget.data.activityLevel == null) {
      _showMessage(
        'Please select your activity level.',
      );

      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) =>
            HomeScreen(
          data: widget.data,
        ),
      ),
      (route) => false,
    );
  }

  // =====================================================
  // MESSAGE
  // =====================================================

  void _showMessage(
    String message,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
        ),
      ),
    );
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor:
            const Color(
          0xFFF7F2E9,
        ),

        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior
                    .onDrag,
            physics:
                const ClampingScrollPhysics(),
            padding:
                const EdgeInsets.fromLTRB(
              24,
              10,
              24,
              16,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                // =========================================
                // HEADER
                // =========================================
                SizedBox(
                  height: 34,
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: IconButton(
                          onPressed: () {
                            Navigator.pop(
                              context,
                            );
                          },
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color:
                                Color(
                              0xFF4B2E83,
                            ),
                            size: 28,
                          ),
                        ),
                      ),

                      const Text(
                        'STEP 3',
                        style: TextStyle(
                          color:
                              Color(
                            0xFF67558E,
                          ),
                          fontSize: 18,
                          fontWeight:
                              FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),

                // =========================================
                // PROGRESS BAR
                // =========================================
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                  child:
                      const LinearProgressIndicator(
                    value: 1,
                    minHeight: 8,
                    backgroundColor:
                        Color(
                      0xFFE4D9F7,
                    ),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(
                      Color(
                        0xFF4B2E83,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),

                // =========================================
                // TITLE
                // =========================================
                const Text(
                  'Your weight plan',
                  style: TextStyle(
                    color:
                        Color(
                      0xFF38138C,
                    ),
                    fontSize: 34,
                    height: 1.05,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),

                // =================================================
                // 1. WEIGHT GOAL
                // =================================================
                const _SectionHeader(
                  number: '1',
                  title: 'WEIGHT GOAL',
                ),

                const SizedBox(
                  height: 6,
                ),

                const Text(
                  'What is your weight goal?',
                  style: TextStyle(
                    color:
                        Color(
                      0xFF38138C,
                    ),
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Row(
                  children: [
                    Expanded(
                      child: _GoalCard(
                        label:
                            'Lose weight',
                        selected:
                            widget.data.weightGoal ==
                                'Lose weight',
                        onTap: () {
                          _selectGoal(
                            'Lose weight',
                          );
                        },
                      ),
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    Expanded(
                      child: _GoalCard(
                        label:
                            'Maintain\nweight',
                        selected:
                            widget.data.weightGoal ==
                                'Maintain weight',
                        onTap: () {
                          _selectGoal(
                            'Maintain weight',
                          );
                        },
                      ),
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    Expanded(
                      child: _GoalCard(
                        label:
                            'Gain weight',
                        selected:
                            widget.data.weightGoal ==
                                'Gain weight',
                        onTap: () {
                          _selectGoal(
                            'Gain weight',
                          );
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 18,
                ),

                // =================================================
                // 2. BODY INFORMATION
                // =================================================
                const _SectionHeader(
                  number: '2',
                  title:
                      'BODY INFORMATION',
                ),

                const SizedBox(
                  height: 10,
                ),

                // =========================================
                // GENDER
                // =========================================
                const Text(
                  'Gender',
                  style: TextStyle(
                    color:
                        Color(
                      0xFF38138C,
                    ),
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Row(
                  children: [
                    Expanded(
                      child: _GenderCard(
                        label: 'Male',
                        icon:
                            Icons.male_rounded,
                        selected:
                            widget.data
                                    .genderForEnergyEstimate ==
                                'Male',
                        onTap: () {
                          _selectGender(
                            'Male',
                          );
                        },
                      ),
                    ),

                    const SizedBox(
                      width: 10,
                    ),

                    Expanded(
                      child: _GenderCard(
                        label: 'Female',
                        icon:
                            Icons.female_rounded,
                        selected:
                            widget.data
                                    .genderForEnergyEstimate ==
                                'Female',
                        onTap: () {
                          _selectGender(
                            'Female',
                          );
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 14,
                ),

                // =========================================
                // BODY MEASUREMENTS
                // =========================================
                const Text(
                  'Body measurements',
                  style: TextStyle(
                    color:
                        Color(
                      0xFF38138C,
                    ),
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Row(
                  children: [
                    // =====================================
                    // CURRENT WEIGHT
                    // =====================================
                    Expanded(
                      child: _BodyInputCard(
                        icon: Icons
                            .monitor_weight_outlined,
                        rotateIcon: false,
                        label:
                            'Current weight',
                        controller:
                            _weightController,
                        onChanged:
                            _onWeightChanged,
                        unit: 'kg',
                      ),
                    ),

                    const SizedBox(
                      width: 10,
                    ),

                    // =====================================
                    // HEIGHT
                    // =====================================
                    Expanded(
                      child: _BodyInputCard(
                        icon:
                            Icons.straighten_rounded,
                        rotateIcon: true,
                        label: 'Height',
                        controller:
                            _heightController,
                        onChanged:
                            _onHeightChanged,
                        unit: 'cm',
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 18,
                ),

                // =================================================
                // 3. ACTIVITY LEVEL
                // =================================================
                const _SectionHeader(
                  number: '3',
                  title:
                      'ACTIVITY LEVEL',
                ),

                const SizedBox(
                  height: 6,
                ),

                const Text(
                  'What is your usual activity level?',
                  style: TextStyle(
                    color:
                        Color(
                      0xFF38138C,
                    ),
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(
                  height: 9,
                ),

                Row(
                  children: [
                    Expanded(
                      child: _ActivityCard(
                        icon: Icons
                            .self_improvement_rounded,
                        title:
                            'Sedentary',
                        description:
                            'Little or no exercise',
                        selected:
                            widget.data.activityLevel ==
                                'Sedentary',
                        onTap: () {
                          _selectActivity(
                            'Sedentary',
                          );
                        },
                      ),
                    ),

                    const SizedBox(
                      width: 10,
                    ),

                    Expanded(
                      child: _ActivityCard(
                        icon: Icons
                            .directions_walk_rounded,
                        title:
                            'Lightly active',
                        description:
                            'Light exercise 1–3 days/week',
                        selected:
                            widget.data.activityLevel ==
                                'Lightly active',
                        onTap: () {
                          _selectActivity(
                            'Lightly active',
                          );
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 9,
                ),

                Row(
                  children: [
                    Expanded(
                      child: _ActivityCard(
                        icon: Icons
                            .directions_run_rounded,
                        title:
                            'Moderately active',
                        description:
                            'Moderate exercise 3–5 days/week',
                        selected:
                            widget.data.activityLevel ==
                                'Moderately active',
                        onTap: () {
                          _selectActivity(
                            'Moderately active',
                          );
                        },
                      ),
                    ),

                    const SizedBox(
                      width: 10,
                    ),

                    Expanded(
                      child: _ActivityCard(
                        icon: Icons
                            .sports_handball_rounded,
                        title:
                            'Very active',
                        description:
                            'Hard exercise 6–7 days/week',
                        selected:
                            widget.data.activityLevel ==
                                'Very active',
                        onTap: () {
                          _selectActivity(
                            'Very active',
                          );
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 14,
                ),
              ],
            ),
          ),
        ),

        // =================================================
        // CONTINUE
        // =================================================
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            color:
                const Color(
              0xFFF7F2E9,
            ),
            padding:
                const EdgeInsets.fromLTRB(
              24,
              8,
              24,
              12,
            ),
            child: SizedBox(
              width:
                  double.infinity,
              height: 54,
              child: ElevatedButton(
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
                  elevation: 4,
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
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =======================================================
// SECTION HEADER
// =======================================================

class _SectionHeader extends StatelessWidget {
  final String number;
  final String title;

  const _SectionHeader({
    required this.number,
    required this.title,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment:
              Alignment.center,
          decoration:
              const BoxDecoration(
            shape:
                BoxShape.circle,
            color:
                Color(
              0xFF5B3B9E,
            ),
          ),
          child: Text(
            number,
            style:
                const TextStyle(
              color:
                  Colors.white,
              fontSize: 14,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ),

        const SizedBox(
          width: 10,
        ),

        Text(
          title,
          style:
              const TextStyle(
            color:
                Color(
              0xFF4B2E83,
            ),
            fontSize: 15,
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// =======================================================
// GOAL CARD
// =======================================================

class _GoalCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GoalCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(
        13,
      ),
      child: AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 200,
        ),
        height: 62,
        padding:
            const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 6,
        ),
        decoration:
            BoxDecoration(
          color: selected
              ? const Color(
                  0xFFF3ECFF,
                )
              : Colors.white,
          borderRadius:
              BorderRadius.circular(
            13,
          ),
          border: Border.all(
            color: selected
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
        child: Stack(
          children: [
            // RADIO INDICATOR
            Positioned(
              top: 0,
              right: 0,
              child:
                  _RadioIndicator(
                selected:
                    selected,
                size: 17,
              ),
            ),

            // GOAL TEXT
            Center(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 6,
                ),
                child: Text(
                  label,
                  textAlign:
                      TextAlign.center,
                  style:
                      TextStyle(
                    color: selected
                        ? const Color(
                            0xFF4B2E83,
                          )
                        : const Color(
                            0xFF514A61,
                          ),
                    fontSize: 12.5,
                    height: 1.05,
                    fontWeight:
                        selected
                            ? FontWeight
                                .w800
                            : FontWeight
                                .w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =======================================================
// GENDER CARD
// =======================================================

class _GenderCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _GenderCard({
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
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(
        13,
      ),
      child: AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 200,
        ),
        height: 60,
        padding:
            const EdgeInsets.symmetric(
          horizontal: 12,
        ),
        decoration:
            BoxDecoration(
          color: selected
              ? const Color(
                  0xFFF3ECFF,
                )
              : Colors.white,
          borderRadius:
              BorderRadius.circular(
            13,
          ),
          border: Border.all(
            color: selected
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
        child: Row(
          children: [
            Icon(
              icon,
              color:
                  const Color(
                0xFF4B2E83,
              ),
              size: 26,
            ),

            const SizedBox(
              width: 7,
            ),

            Expanded(
              child: Text(
                label,
                style:
                    TextStyle(
                  color: selected
                      ? const Color(
                          0xFF4B2E83,
                        )
                      : const Color(
                          0xFF514A61,
                        ),
                  fontSize: 14,
                  fontWeight:
                      selected
                          ? FontWeight
                              .w800
                          : FontWeight
                              .w600,
                ),
              ),
            ),

            _RadioIndicator(
              selected: selected,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// =======================================================
// BODY INPUT CARD
// =======================================================

class _BodyInputCard extends StatelessWidget {
  final IconData icon;
  final bool rotateIcon;
  final String label;

  final TextEditingController controller;

  final ValueChanged<String> onChanged;

  final String unit;

  const _BodyInputCard({
    required this.icon,
    this.rotateIcon = false,
    required this.label,
    required this.controller,
    required this.onChanged,
    required this.unit,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      height: 72,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.white,
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        border: Border.all(
          color:
              const Color(
            0xFFDCCFF0,
          ),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          rotateIcon
              ? RotatedBox(
                  quarterTurns: 1,
                  child: Icon(
                    icon,
                    color:
                        const Color(
                      0xFF4B2E83,
                    ),
                    size: 26,
                  ),
                )
              : Icon(
                  icon,
                  color:
                      const Color(
                    0xFF4B2E83,
                  ),
                  size: 26,
                ),

          const SizedBox(
            width: 7,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style:
                      const TextStyle(
                    color:
                        Color(
                      0xFF67558E,
                    ),
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: TextField(
                          controller:
                              controller,
                          keyboardType:
                              const TextInputType
                                  .numberWithOptions(
                            decimal:
                                true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter
                                .allow(
                              RegExp(
                                r'^\d*\.?\d{0,2}',
                              ),
                            ),
                          ],
                          onChanged:
                              onChanged,
                          style:
                              const TextStyle(
                            color:
                                Color(
                              0xFF38138C,
                            ),
                            fontSize: 16,
                            fontWeight:
                                FontWeight.w700,
                          ),
                          decoration:
                              InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor:
                                const Color(
                              0xFFFCFAFF,
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(
                              horizontal:
                                  8,
                              vertical:
                                  8,
                            ),
                            enabledBorder:
                                OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                8,
                              ),
                              borderSide:
                                  const BorderSide(
                                color:
                                    Color(
                                  0xFFE2D8F1,
                                ),
                              ),
                            ),
                            focusedBorder:
                                OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                8,
                              ),
                              borderSide:
                                  const BorderSide(
                                color:
                                    Color(
                                  0xFF4B2E83,
                                ),
                                width:
                                    1.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      width: 7,
                    ),

                    // FIXED UNIT
                    Text(
                      unit,
                      style:
                          const TextStyle(
                        color:
                            Color(
                          0xFF67558E,
                        ),
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),

                    const SizedBox(
                      width: 2,
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
}

// =======================================================
// ACTIVITY CARD
// =======================================================

class _ActivityCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _ActivityCard({
    required this.icon,
    required this.title,
    required this.description,
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
        14,
      ),
      child: AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 200,
        ),
        height: 86,
        padding:
            const EdgeInsets.all(
          9,
        ),
        decoration:
            BoxDecoration(
          color: selected
              ? const Color(
                  0xFFF3ECFF,
                )
              : Colors.white,
          borderRadius:
              BorderRadius.circular(
            14,
          ),
          border: Border.all(
            color: selected
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
        child: Stack(
          children: [
            Positioned(
              top: 0,
              right: 0,
              child:
                  _RadioIndicator(
                selected:
                    selected,
                size: 20,
              ),
            ),

            Row(
              children: [
                Icon(
                  icon,
                  color:
                      const Color(
                    0xFF4B2E83,
                  ),
                  size: 29,
                ),

                const SizedBox(
                  width: 7,
                ),

                Expanded(
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.only(
                          right: 18,
                        ),
                        child: Text(
                          title,
                          style:
                              TextStyle(
                            color: selected
                                ? const Color(
                                    0xFF4B2E83,
                                  )
                                : const Color(
                                    0xFF514A61,
                                  ),
                            fontSize: 13,
                            fontWeight:
                                selected
                                    ? FontWeight
                                        .w800
                                    : FontWeight
                                        .w600,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 2,
                      ),

                      Text(
                        description,
                        style:
                            const TextStyle(
                          color:
                              Color(
                            0xFF67558E,
                          ),
                          fontSize: 10.5,
                          height: 1.15,
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
    );
  }
}

// =======================================================
// RADIO INDICATOR
// =======================================================

class _RadioIndicator extends StatelessWidget {
  final bool selected;
  final double size;

  const _RadioIndicator({
    required this.selected,
    this.size = 24,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return AnimatedContainer(
      duration:
          const Duration(
        milliseconds: 200,
      ),
      width: size,
      height: size,
      padding: EdgeInsets.all(
        size * 0.18,
      ),
      decoration:
          BoxDecoration(
        shape:
            BoxShape.circle,
        color:
            Colors.white,
        border:
            Border.all(
          color: selected
              ? const Color(
                  0xFF4B2E83,
                )
              : const Color(
                  0xFFB9ADCB,
                ),
          width: 2,
        ),
      ),
      child: AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 200,
        ),
        decoration:
            BoxDecoration(
          shape:
              BoxShape.circle,
          color: selected
              ? const Color(
                  0xFF4B2E83,
                )
              : Colors.transparent,
        ),
      ),
    );
  }
}