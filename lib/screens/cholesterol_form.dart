import 'package:flutter/material.dart';

import '../models/profile_setup_data.dart';
import 'weight_management_form.dart';
import 'home_screen.dart';

class CholesterolForm
    extends StatefulWidget {
  final ProfileSetupData data;

  const CholesterolForm({
    super.key,
    required this.data,
  });

  @override
  State<CholesterolForm>
      createState() =>
          _CholesterolFormState();
}

class _CholesterolFormState
    extends State<CholesterolForm> {
  void _toggleLdl() {
    setState(() {
      widget.data.highLdl =
          !widget.data.highLdl;

      if (widget.data.highLdl) {
        widget.data.cholesterolNotSure =
            false;
      }
    });
  }

  void _toggleTriglycerides() {
    setState(() {
      widget.data.highTriglycerides =
          !widget.data
              .highTriglycerides;

      if (widget.data
          .highTriglycerides) {
        widget.data.cholesterolNotSure =
            false;
      }
    });
  }

  void _toggleNotSure() {
    setState(() {
      widget.data.cholesterolNotSure =
          !widget.data
              .cholesterolNotSure;

      if (widget.data
          .cholesterolNotSure) {
        widget.data.highLdl =
            false;

        widget.data.highTriglycerides =
            false;
      }
    });
  }

  bool get _hasSelection {
    return widget.data.highLdl ||
        widget.data.highTriglycerides ||
        widget.data.cholesterolNotSure;
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

              // SAME TITLE SIZE AS DIABETES
              const Text(
                'Let’s understand your\ncholesterol needs',
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
                'What are you currently managing?',
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
                    18,
              ),

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
                    _CheckboxOption(
                      label:
                          'High LDL cholesterol',
                      selected:
                          widget.data.highLdl,
                      onTap:
                          _toggleLdl,
                    ),

                    const _OptionDivider(),

                    _CheckboxOption(
                      label:
                          'High triglycerides',
                      selected:
                          widget.data
                              .highTriglycerides,
                      onTap:
                          _toggleTriglycerides,
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

              _SingleCheckboxCard(
                label:
                    'Not sure',
                selected:
                    widget.data
                        .cholesterolNotSure,
                onTap:
                    _toggleNotSure,
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

class _CheckboxOption
    extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CheckboxOption({
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

            _CheckboxIndicator(
              selected:
                  selected,
            ),
          ],
        ),
      ),
    );
  }
}

class _SingleCheckboxCard
    extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SingleCheckboxCard({
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

            _CheckboxIndicator(
              selected:
                  selected,
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckboxIndicator
    extends StatelessWidget {
  final bool selected;

  const _CheckboxIndicator({
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
          28,
      height:
          28,
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
                  size: 21,
                )
              : null,
    );
  }
}