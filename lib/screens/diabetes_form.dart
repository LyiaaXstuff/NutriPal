import 'package:flutter/material.dart';

import '../models/profile_setup_data.dart';
import 'cholesterol_form.dart';
import 'weight_management_form.dart';
import 'home_screen.dart';

class DiabetesForm
    extends StatefulWidget {
  final ProfileSetupData data;

  const DiabetesForm({
    super.key,
    required this.data,
  });

  @override
  State<DiabetesForm>
      createState() =>
          _DiabetesFormState();
}

class _DiabetesFormState
    extends State<DiabetesForm> {
  void _selectType(
    String type,
  ) {
    setState(() {
      widget.data.diabetesType =
          type;
    });
  }

  void _goToHome() {
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

  void _continue() {
    if (widget.data.diabetesType ==
        null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text(
            'Please select one option.',
          ),
        ),
      );

      return;
    }

    // NEXT = CHOLESTEROL
    if (widget.data
        .highCholesterol) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              CholesterolForm(
            data:
                widget.data,
          ),
        ),
      );

      return;
    }

    // NEXT = WEIGHT
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
                      'STEP 3',
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

              ClipRRect(
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
                child:
                    const LinearProgressIndicator(
                  value:
                      1,
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
                    28,
              ),

              const Text(
                'Your diabetes profile',
                style:
                    TextStyle(
                  color:
                      Color(
                    0xFF38138C,
                  ),
                  fontSize:
                      37,
                  height:
                      1.05,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(
                height:
                    22,
              ),

              const Text(
                'Which best describes your condition?',
                style:
                    TextStyle(
                  color:
                      Color(
                    0xFF38138C,
                  ),
                  fontSize:
                      19,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              const SizedBox(
                height:
                    5,
              ),

              const Text(
                'Select one option.',
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
                    18,
              ),

              // =========================
              // MAIN OPTIONS
              // =========================
              Container(
                width:
                    double.infinity,
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
                    width:
                        1.2,
                  ),
                ),
                child:
                    Column(
                  children: [
                    _RadioOption(
                      label:
                          'Prediabetes',
                      selected:
                          widget.data.diabetesType ==
                              'Prediabetes',
                      onTap: () {
                        _selectType(
                          'Prediabetes',
                        );
                      },
                    ),

                    const _OptionDivider(),

                    _RadioOption(
                      label:
                          'Type 1 diabetes',
                      selected:
                          widget.data.diabetesType ==
                              'Type 1 diabetes',
                      onTap: () {
                        _selectType(
                          'Type 1 diabetes',
                        );
                      },
                    ),

                    const _OptionDivider(),

                    _RadioOption(
                      label:
                          'Type 2 diabetes',
                      selected:
                          widget.data.diabetesType ==
                              'Type 2 diabetes',
                      onTap: () {
                        _selectType(
                          'Type 2 diabetes',
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height:
                    18,
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
                    18,
              ),

              _SingleRadioCard(
                label:
                    'Not sure',
                selected:
                    widget.data.diabetesType ==
                        'Not sure',
                onTap: () {
                  _selectType(
                    'Not sure',
                  );
                },
              ),
            ],
          ),
        ),
      ),

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

class _OptionDivider
    extends StatelessWidget {
  const _OptionDivider();

  @override
  Widget build(
    BuildContext context,
  ) {
    return const Padding(
      padding:
          EdgeInsets.symmetric(
        horizontal:
            18,
      ),
      child:
          Divider(
        height:
            1,
        thickness:
            1,
        color:
            Color(
          0xFFE2D8F1,
        ),
      ),
    );
  }
}

class _RadioOption
    extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RadioOption({
    required this.label,
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
              20,
          vertical:
              18,
        ),
        color:
            selected
                ? const Color(
                    0xFFF3ECFF,
                  )
                : Colors.transparent,
        child:
            Row(
          children: [
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

            _RadioIndicator(
              selected:
                  selected,
            ),
          ],
        ),
      ),
    );
  }
}

class _SingleRadioCard
    extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SingleRadioCard({
    required this.label,
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
              20,
          vertical:
              18,
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

            _RadioIndicator(
              selected:
                  selected,
            ),
          ],
        ),
      ),
    );
  }
}

class _RadioIndicator
    extends StatelessWidget {
  final bool selected;

  const _RadioIndicator({
    required this.selected,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return AnimatedContainer(
      duration:
          const Duration(
        milliseconds:
            200,
      ),
      width:
          30,
      height:
          30,
      padding:
          const EdgeInsets.all(
        5,
      ),
      decoration:
          BoxDecoration(
        shape:
            BoxShape.circle,
        color:
            Colors.white,
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
              2.2,
        ),
      ),
      child:
          AnimatedContainer(
        duration:
            const Duration(
          milliseconds:
              200,
        ),
        decoration:
            BoxDecoration(
          shape:
              BoxShape.circle,
          color:
              selected
                  ? const Color(
                      0xFF4B2E83,
                    )
                  : Colors.transparent,
        ),
      ),
    );
  }
}