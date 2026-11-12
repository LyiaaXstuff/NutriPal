import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/profile_setup_data.dart';
import '../services/auth_service.dart';
import '../services/energy_requirement.dart';
import '../services/name_rules.dart';
import 'health_conditions_form.dart';

class UserProfileForm extends StatefulWidget {
  final ProfileSetupData? data;

  const UserProfileForm({
    super.key,
    this.data,
  });

  @override
  State<UserProfileForm> createState() =>
      _UserProfileFormState();
}

class _UserProfileFormState
    extends State<UserProfileForm> {
  late final ProfileSetupData _data;

  late final TextEditingController _nameController;

  final FocusNode _nameFocusNode =
      FocusNode();

  DateTime? _selectedDateOfBirth;

  @override
  void initState() {
    super.initState();

    _data =
        widget.data ??
        ProfileSetupData();

    // Email of the signed-in account (shown in My Account).
    if (_data.email.trim().isEmpty) {
      _data.email = AuthService.currentEmail ?? '';
    }

    _nameController =
        TextEditingController(
      text: _data.nickname,
    );

    _selectedDateOfBirth =
        _data.dateOfBirth;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();

    super.dispose();
  }

  // =====================================================
  // DATE OF BIRTH - SCROLL WHEEL
  // =====================================================

  Future<void> _selectDateOfBirth() async {
    FocusScope.of(context).unfocus();

    final DateTime today =
        DateTime.now();

    // NutriPal is for adults aged 19 and over (the NASEM
    // energy equations start at 19), so the newest date
    // the wheel allows is the day someone turns 19 today.
    final DateTime latestBirthDate =
        AdultAge.latestBirthDate(
      today,
    );

    DateTime tempDate =
        _selectedDateOfBirth ??
        DateTime(
          latestBirthDate.year - 6,
          latestBirthDate.month,
          latestBirthDate.day,
        );

    // The wheel must start inside its range (an older
    // profile may hold a date under 19).
    if (tempDate.isAfter(
      latestBirthDate,
    )) {
      tempDate =
          latestBirthDate;
    }

    // Click (if Touch sounds is on) + light vibration as
    // each wheel moves.
    final _WheelTicker ticker =
        _WheelTicker();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor:
          Colors.transparent,
      isScrollControlled:
          true,
      builder: (
        BuildContext sheetContext,
      ) {
        return StatefulBuilder(
          builder: (
            BuildContext context,
            StateSetter setSheetState,
          ) {
            return SafeArea(
              top: false,
              child: Container(
                padding:
                    const EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  20,
                ),
                decoration:
                    const BoxDecoration(
                  color:
                      Color(
                    0xFFF7F2E9,
                  ),
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
                    // =========================
                    // DRAG INDICATOR
                    // =========================
                    Container(
                      width:
                          44,
                      height:
                          5,
                      decoration:
                          BoxDecoration(
                        color:
                            const Color(
                          0xFFD8CDEA,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          20,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    // =========================
                    // HEADER
                    // =========================
                    Row(
                      children: [
                        const Expanded(
                          child:
                              Text(
                            'Select your birthday',
                            style:
                                TextStyle(
                              color:
                                  Color(
                                0xFF38138C,
                              ),
                              fontSize:
                                  21,
                              fontWeight:
                                  FontWeight.w800,
                            ),
                          ),
                        ),

                        IconButton(
                          onPressed: () {
                            Navigator.pop(
                              sheetContext,
                            );
                          },
                          icon:
                              const Icon(
                            Icons.close_rounded,
                            color:
                                Color(
                              0xFF4B2E83,
                            ),
                            size:
                                28,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 2,
                    ),

                    const Align(
                      alignment:
                          Alignment.centerLeft,
                      child:
                          Text(
                        'Scroll to choose your date of birth. NutriPal is for adults aged 19 and over.',
                        style:
                            TextStyle(
                          color:
                              Color(
                            0xFF756D7E,
                          ),
                          fontSize:
                              14,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    // =========================
                    // DAY / MONTH / YEAR
                    // SCROLL WHEEL
                    // =========================
                    Container(
                      height:
                          210,
                      decoration:
                          BoxDecoration(
                        color:
                            Colors.white,
                        borderRadius:
                            BorderRadius.circular(
                          20,
                        ),
                        border:
                            Border.all(
                          color:
                              const Color(
                            0xFFD8CDEA,
                          ),
                          width:
                              1.3,
                        ),
                      ),
                      child:
                          ClipRRect(
                        borderRadius:
                            BorderRadius.circular(
                          20,
                        ),
                        child:
                            CupertinoTheme(
                          data:
                              const CupertinoThemeData(
                            textTheme:
                                CupertinoTextThemeData(
                              dateTimePickerTextStyle:
                                  TextStyle(
                                color:
                                    Color(
                                  0xFF38138C,
                                ),
                                fontSize:
                                    20,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                          ),
                          child:
                              NotificationListener<
                                  ScrollUpdateNotification>(
                            onNotification:
                                ticker.onScroll,
                            child:
                                CupertinoDatePicker(
                            mode:
                                CupertinoDatePickerMode.date,

                            initialDateTime:
                                tempDate,

                            minimumDate:
                                DateTime(
                              1900,
                              1,
                              1,
                            ),

                            maximumDate:
                                latestBirthDate,

                            dateOrder:
                                DatePickerDateOrder.dmy,

                            onDateTimeChanged: (
                              DateTime newDate,
                            ) {
                              setSheetState(() {
                                tempDate =
                                    newDate;
                              });
                            },
                          ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    // =========================
                    // SELECTED DATE PREVIEW
                    // =========================
                    Container(
                      width:
                          double.infinity,
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal:
                            16,
                        vertical:
                            12,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            const Color(
                          0xFFF1EBFA,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          15,
                        ),
                      ),
                      child:
                          Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons
                                .cake_outlined,
                            color:
                                Color(
                              0xFF4B2E83,
                            ),
                            size:
                                21,
                          ),

                          const SizedBox(
                            width:
                                9,
                          ),

                          Text(
                            _formatTempDate(
                              tempDate,
                            ),
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
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    // =========================
                    // CONFIRM
                    // =========================
                    SizedBox(
                      width:
                          double.infinity,
                      height:
                          54,
                      child:
                          ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectedDateOfBirth =
                                tempDate;

                            _data.dateOfBirth =
                                tempDate;
                          });

                          Navigator.pop(
                            sheetContext,
                          );
                        },
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(
                            0xFF4B2E83,
                          ),
                          foregroundColor:
                              Colors.white,
                          elevation:
                              0,
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              27,
                            ),
                          ),
                        ),
                        child:
                            const Text(
                          'Confirm birthday',
                          style:
                              TextStyle(
                            fontSize:
                                17,
                            fontWeight:
                                FontWeight.w800,
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
      },
    );
  }

  // =====================================================
  // FORMAT DATE
  // =====================================================

  String _formattedDate() {
    if (_selectedDateOfBirth ==
        null) {
      return 'Select date of birth';
    }

    return _formatTempDate(
      _selectedDateOfBirth!,
    );
  }

  String _formatTempDate(
    DateTime date,
  ) {
    const List<String> months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${date.day} '
        '${months[date.month - 1]} '
        '${date.year}';
  }

  // =====================================================
  // CONTINUE
  // =====================================================

  void _continue() {
    FocusScope.of(context).unfocus();

    // Letters, spaces, ' and - only (no numbers or other symbols).
    final String? nameProblem =
        NameRules.validate(_nameController.text);

    if (nameProblem != null) {
      _showMessage(nameProblem);

      return;
    }

    final String name =
        NameRules.normalize(_nameController.text);

    if (_selectedDateOfBirth ==
        null) {
      _showMessage(
        'Please select your date of birth.',
      );

      return;
    }

    if (!AdultAge.isAdult(
      _selectedDateOfBirth!,
      DateTime.now(),
    )) {
      _showMessage(
        'NutriPal is for adults aged 19 and over.',
      );

      return;
    }

    _data.nickname =
        name;

    _data.dateOfBirth =
        _selectedDateOfBirth;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            HealthConditionsForm(
          data: _data,
        ),
      ),
    );
  }

  void _showMessage(
    String message,
  ) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content:
            Text(
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
        FocusScope.of(context)
            .unfocus();
      },
      child: Scaffold(
        backgroundColor:
            const Color(
          0xFFF7F2E9,
        ),

        body: SafeArea(
          bottom: false,
          child:
              SingleChildScrollView(
            keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior
                    .onDrag,
            physics:
                const ClampingScrollPhysics(),
            padding:
                const EdgeInsets.fromLTRB(
              28,
              12,
              28,
              20,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                // =========================
                // STEP
                // =========================
                const SizedBox(
                  height: 36,
                  child: Align(
                    alignment:
                        Alignment.centerRight,
                    child: Text(
                      'STEP 1',
                      style: TextStyle(
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
                  ),
                ),

                const SizedBox(
                  height: 12,
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
                        0.33,
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
                  height: 28,
                ),

                // =========================
                // INTRO
                // =========================
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.center,
                  children: [
                    const Expanded(
                      flex:
                          6,
                      child:
                          Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            'Let’s get to\nknow you',
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
                                  FontWeight
                                      .w900,
                            ),
                          ),

                          SizedBox(
                            height:
                                14,
                          ),

                          Text(
                            'Tell us a little about you.',
                            style:
                                TextStyle(
                              color:
                                  Color(
                                0xFF756D7E,
                              ),
                              fontSize:
                                  16,
                              height:
                                  1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      width:
                          8,
                    ),

                    Expanded(
                      flex:
                          5,
                      child:
                          SizedBox(
                        height:
                            165,
                        child:
                            Center(
                          child:
                              Image.asset(
                            'assets/images/NutriPal Mascot9.png',
                            width:
                                160,
                            height:
                                160,
                            fit:
                                BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 24,
                ),

                // =========================
                // NAME LABEL
                // =========================
                const Row(
                  children: [
                    Flexible(
                      child:
                          Text(
                        'What should we call you?',
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
                    ),

                    SizedBox(
                      width:
                          5,
                    ),

                    Text(
                      '*',
                      style:
                          TextStyle(
                        color:
                            Colors.red,
                        fontSize:
                            21,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height:
                      10,
                ),

                // =========================
                // NAME FIELD
                // =========================
                TextField(
                  controller:
                      _nameController,

                  focusNode:
                      _nameFocusNode,

                  textCapitalization:
                      TextCapitalization.words,

                  textInputAction:
                      TextInputAction.done,

                  // Letters, spaces, ' and - only.
                  inputFormatters:
                      NameRules.inputFormatters,

                  onChanged: (
                    value,
                  ) {
                    _data.nickname =
                        NameRules.normalize(value);
                  },

                  style:
                      const TextStyle(
                    color:
                        Color(
                      0xFF514A61,
                    ),
                    fontSize:
                        17,
                  ),

                  decoration:
                      InputDecoration(
                    filled:
                        true,

                    fillColor:
                        Colors.white,

                    prefixIcon:
                        const Icon(
                      Icons
                          .person_outline_rounded,
                      color:
                          Color(
                        0xFF67558E,
                      ),
                      size:
                          28,
                    ),

                    hintText:
                        'Name or nickname',

                    hintStyle:
                        const TextStyle(
                      color:
                          Color(
                        0xFF756D7E,
                      ),
                      fontSize:
                          17,
                    ),

                    contentPadding:
                        const EdgeInsets
                            .symmetric(
                      vertical:
                          18,
                      horizontal:
                          18,
                    ),

                    enabledBorder:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        18,
                      ),
                      borderSide:
                          const BorderSide(
                        color:
                            Color(
                          0xFFD8CDEA,
                        ),
                        width:
                            1.4,
                      ),
                    ),

                    focusedBorder:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        18,
                      ),
                      borderSide:
                          const BorderSide(
                        color:
                            Color(
                          0xFF4B2E83,
                        ),
                        width:
                            1.8,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  height:
                      24,
                ),

                // =========================
                // DOB LABEL
                // =========================
                const Row(
                  children: [
                    Text(
                      'When is your birthday?',
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

                    SizedBox(
                      width:
                          5,
                    ),

                    Text(
                      '*',
                      style:
                          TextStyle(
                        color:
                            Colors.red,
                        fontSize:
                            21,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height:
                      10,
                ),

                // =========================
                // DOB FIELD
                // =========================
                InkWell(
                  onTap:
                      _selectDateOfBirth,

                  borderRadius:
                      BorderRadius.circular(
                    18,
                  ),

                  child:
                      Container(
                    width:
                        double.infinity,

                    padding:
                        const EdgeInsets.symmetric(
                      horizontal:
                          18,
                      vertical:
                          17,
                    ),

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
                          0xFFD8CDEA,
                        ),
                        width:
                            1.4,
                      ),
                    ),

                    child:
                        Row(
                      children: [
                        const Icon(
                          Icons
                              .cake_outlined,
                          color:
                              Color(
                            0xFF67558E,
                          ),
                          size:
                              27,
                        ),

                        const SizedBox(
                          width:
                              14,
                        ),

                        Expanded(
                          child:
                              Text(
                            _formattedDate(),
                            style:
                                TextStyle(
                              color:
                                  _selectedDateOfBirth ==
                                          null
                                      ? const Color(
                                          0xFF756D7E,
                                        )
                                      : const Color(
                                          0xFF514A61,
                                        ),
                              fontSize:
                                  17,
                            ),
                          ),
                        ),

                        // Scroll-wheel style indicator
                        const Icon(
                          Icons
                              .unfold_more_rounded,
                          color:
                              Color(
                            0xFF4B2E83,
                          ),
                          size:
                              27,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(
                  height:
                      25,
                ),
              ],
            ),
          ),
        ),

        // =========================
        // FIXED BOTTOM
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
              28,
              10,
              28,
              14,
            ),

            child:
                Column(
              mainAxisSize:
                  MainAxisSize.min,

              children: [
                const Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_rounded,
                      color:
                          Color(
                        0xFF38138C,
                      ),
                      size:
                          21,
                    ),

                    SizedBox(
                      width:
                          10,
                    ),

                    Expanded(
                      child:
                          Text(
                        'Your information is securely stored and used only for personalisation.',
                        style:
                            TextStyle(
                          color:
                              Color(
                            0xFF67558E,
                          ),
                          fontSize:
                              13,
                          height:
                              1.35,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height:
                      10,
                ),

                SizedBox(
                  width:
                      double.infinity,
                  height:
                      56,

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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =======================================================
// WHEEL TICK (birthday picker)
// =======================================================
//
// Plays the phone's click sound and a light "selection"
// vibration each time the day, month or year wheel moves
// to a new value, like a real dial.
//
// The click follows the phone's own setting: it only
// plays when "Touch sounds" is turned on in Android
// Settings; otherwise the user only feels the vibration.
// =======================================================

class _WheelTicker {
  // Last item shown in the middle of each wheel.
  final Map<int, int> _lastItem = <int, int>{};

  DateTime _lastTick = DateTime.fromMillisecondsSinceEpoch(0);

  // A fast fling passes many items; this keeps the clicks
  // from blurring into a buzz.
  static const Duration _minGap = Duration(milliseconds: 35);

  bool onScroll(ScrollUpdateNotification notification) {
    final ScrollMetrics metrics = notification.metrics;

    if (metrics is! FixedExtentMetrics) return false;

    final int wheel = identityHashCode(notification.context);
    final int item = metrics.itemIndex;
    final int? previous = _lastItem[wheel];

    _lastItem[wheel] = item;

    // First report from a wheel is where it starts: no click.
    if (previous == null || previous == item) return false;

    final DateTime now = DateTime.now();

    if (now.difference(_lastTick) < _minGap) return false;

    _lastTick = now;

    SystemSound.play(SystemSoundType.click);
    HapticFeedback.selectionClick();

    // Let the picker handle the scroll as usual.
    return false;
  }
}
