import 'package:flutter/material.dart';

import '../models/nutrition_label_data.dart';

class ExtractedNutritionReviewScreen extends StatelessWidget {
  final NutritionLabelData data;

  const ExtractedNutritionReviewScreen({
    super.key,
    required this.data,
  });

  static const Color primaryPurple =
      Color(0xFF4B2E83);

  static const Color darkPurple =
      Color(0xFF25104F);

  static const Color selectedTeal =
      Color(0xFF17B6B1);

  static const Color backgroundColor =
      Color(0xFFFCFAFF);

  static const Color secondaryText =
      Color(0xFF67558E);

  // =====================================================
  // FORMAT NUMBER
  // =====================================================

  static String _formatNumber(
    double value,
  ) {
    if (value ==
        value.roundToDouble()) {
      return value
          .toInt()
          .toString();
    }

    return value
        .toStringAsFixed(
          3,
        )
        .replaceFirst(
          RegExp(
            r'0+$',
          ),
          '',
        )
        .replaceFirst(
          RegExp(
            r'\.$',
          ),
          '',
        );
  }

  // =====================================================
  // SERVING SIZE
  // =====================================================

  String get _servingSizeText {
    if (data.servingSizeAmount ==
            null ||
        data.servingSizeUnit ==
            null) {
      return 'Not detected';
    }

    return '${_formatNumber(data.servingSizeAmount!)} '
        '${data.servingSizeUnit}';
  }

  // =====================================================
  // SERVINGS PER PACKAGE
  // =====================================================

  String get _servingsPerPackageText {
    if (data.servingsPerPackage ==
        null) {
      return 'Not detected';
    }

    return _formatNumber(
      data.servingsPerPackage!,
    );
  }

  // =====================================================
  // PHYSICAL SERVING
  // =====================================================

  String? get _physicalServingText {
    if (data.servingUnitAmount ==
            null ||
        data.servingUnitName ==
            null) {
      return null;
    }

    final double amount =
        data.servingUnitAmount!;

    String amountText;

    if ((amount - 0.5).abs() <
        0.001) {
      amountText =
          '½';
    } else if ((amount - 0.25).abs() <
        0.001) {
      amountText =
          '¼';
    } else if ((amount - 0.75).abs() <
        0.001) {
      amountText =
          '¾';
    } else {
      amountText =
          _formatNumber(
        amount,
      );
    }

    String name =
        data.servingUnitName!;

    if (amount > 1 &&
        !name.endsWith(
          's',
        )) {
      name =
          '${name}s';
    }

    return '$amountText $name';
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          backgroundColor,

      body:
          SafeArea(
        child:
            Column(
          children: [
            // =================================================
            // TOP BAR
            // =================================================

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                12,
                8,
                20,
                0,
              ),
              child:
                  SizedBox(
                height:
                    58,
                child:
                    Row(
                  children: [
                    SizedBox(
                      width:
                          48,
                      height:
                          48,
                      child:
                          IconButton(
                        onPressed:
                            () {
                          Navigator.pop(
                            context,
                          );
                        },
                        icon:
                            const Icon(
                          Icons
                              .arrow_back_ios_new_rounded,
                          color:
                              primaryPurple,
                          size:
                              25,
                        ),
                      ),
                    ),

                    const Expanded(
                      child:
                          Text(
                        'Review nutrition',
                        textAlign:
                            TextAlign.center,
                        style:
                            TextStyle(
                          color:
                              darkPurple,
                          fontSize:
                              23,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                    ),

                    const SizedBox(
                      width:
                          48,
                    ),
                  ],
                ),
              ),
            ),

            // =================================================
            // CONTENT
            // =================================================

            Expanded(
              child:
                  SingleChildScrollView(
                padding:
                    const EdgeInsets.fromLTRB(
                  22,
                  14,
                  22,
                  30,
                ),
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Check the extracted information',
                      style:
                          TextStyle(
                        color:
                            darkPurple,
                        fontSize:
                            25,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),

                    const SizedBox(
                      height:
                          8,
                    ),

                    const Text(
                      'Make sure the serving information and nutrient values match the product label.',
                      style:
                          TextStyle(
                        color:
                            secondaryText,
                        fontSize:
                            15,
                        height:
                            1.4,
                      ),
                    ),

                    const SizedBox(
                      height:
                          22,
                    ),

                    // =================================================
                    // SERVING INFORMATION
                    // =================================================

                    const _SectionTitle(
                      title:
                          'Serving information',
                    ),

                    const SizedBox(
                      height:
                          10,
                    ),

                    _ServingCard(
                      servingSize:
                          _servingSizeText,
                      servingsPerPackage:
                          _servingsPerPackageText,
                      servingEquivalent:
                          _physicalServingText,
                    ),

                    const SizedBox(
                      height:
                          26,
                    ),

                    // =================================================
                    // PER SERVING
                    // =================================================

                    if (data.hasPerServingValues) ...[
                      const _SectionTitle(
                        title:
                            'Per serving',
                      ),

                      const SizedBox(
                        height:
                            10,
                      ),

                      _NutritionCard(
                        values:
                            data.perServing!,
                      ),

                      const SizedBox(
                        height:
                            26,
                      ),
                    ],

                    // =================================================
                    // PER 100
                    // =================================================

                    if (data.hasPer100Values) ...[
                      _SectionTitle(
                        title:
                            data.per100Unit ==
                                    'ml'
                                ? 'Per 100 ml'
                                : data.per100Unit ==
                                        'g'
                                    ? 'Per 100 g'
                                    : 'Per 100',
                      ),

                      const SizedBox(
                        height:
                            10,
                      ),

                      _NutritionCard(
                        values:
                            data.per100!,
                      ),

                      const SizedBox(
                        height:
                            26,
                      ),
                    ],

                    // =================================================
                    // CALCULATION STATUS
                    // =================================================

                    if (data.canCalculatePortion)
                      Container(
                        width:
                            double.infinity,
                        padding:
                            const EdgeInsets.all(
                          16,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              const Color(
                            0xFFE8FAF8,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            18,
                          ),
                        ),
                        child:
                            const Row(
                          children: [
                            Icon(
                              Icons
                                  .check_circle_outline_rounded,
                              color:
                                  selectedTeal,
                              size:
                                  28,
                            ),

                            SizedBox(
                              width:
                                  12,
                            ),

                            Expanded(
                              child:
                                  Text(
                                'Enough information is available to calculate an intended portion.',
                                style:
                                    TextStyle(
                                  color:
                                      darkPurple,
                                  fontSize:
                                      14,
                                  height:
                                      1.35,
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        width:
                            double.infinity,
                        padding:
                            const EdgeInsets.all(
                          16,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              const Color(
                            0xFFFFF5DF,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            18,
                          ),
                        ),
                        child:
                            const Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color:
                                  Color(
                                0xFFE69A17,
                              ),
                            ),

                            SizedBox(
                              width:
                                  12,
                            ),

                            Expanded(
                              child:
                                  Text(
                                'Some serving information may be missing, so portion calculation may not be available.',
                                style:
                                    TextStyle(
                                  color:
                                      darkPurple,
                                  fontSize:
                                      14,
                                  height:
                                      1.35,
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
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
// SERVING CARD
// =======================================================

class _ServingCard extends StatelessWidget {
  final String servingSize;

  final String servingsPerPackage;

  final String? servingEquivalent;

  const _ServingCard({
    required this.servingSize,
    required this.servingsPerPackage,
    required this.servingEquivalent,
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
          20,
        ),
        border:
            Border.all(
          color:
              const Color(
            0xFFE4D9F7,
          ),
        ),
      ),
      child:
          Column(
        children: [
          _InfoRow(
            title:
                'Serving size',
            value:
                servingSize,
          ),

          const Divider(
            height:
                1,
            color:
                Color(
              0xFFEDE7F6,
            ),
          ),

          _InfoRow(
            title:
                'Servings per package',
            value:
                servingsPerPackage,
          ),

          if (servingEquivalent !=
              null) ...[
            const Divider(
              height:
                  1,
              color:
                  Color(
                0xFFEDE7F6,
              ),
            ),

            _InfoRow(
              title:
                  'Serving equivalent',
              value:
                  servingEquivalent!,
            ),
          ],
        ],
      ),
    );
  }
}

// =======================================================
// SECTION TITLE
// =======================================================

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({
    required this.title,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Text(
      title.toUpperCase(),
      style:
          const TextStyle(
        color:
            Color(
          0xFF4B2E83,
        ),
        fontSize:
            14,
        letterSpacing:
            0.6,
        fontWeight:
            FontWeight.w900,
      ),
    );
  }
}

// =======================================================
// INFO ROW
// =======================================================

class _InfoRow extends StatelessWidget {
  final String title;

  final String value;

  const _InfoRow({
    required this.title,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            17,
        vertical:
            16,
      ),
      child:
          Row(
        children: [
          Expanded(
            child:
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
                    FontWeight.w800,
              ),
            ),
          ),

          const SizedBox(
            width:
                15,
          ),

          Flexible(
            child:
                Text(
              value,
              textAlign:
                  TextAlign.right,
              style:
                  const TextStyle(
                color:
                    Color(
                  0xFF67558E,
                ),
                fontSize:
                    15,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =======================================================
// NUTRITION CARD
// =======================================================

class _NutritionCard extends StatelessWidget {
  final NutritionValues values;

  const _NutritionCard({
    required this.values,
  });

  static String _format(
    double value,
  ) {
    if (value ==
        value.roundToDouble()) {
      return value
          .toInt()
          .toString();
    }

    return value
        .toStringAsFixed(
          3,
        )
        .replaceFirst(
          RegExp(
            r'0+$',
          ),
          '',
        )
        .replaceFirst(
          RegExp(
            r'\.$',
          ),
          '',
        );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final List<_NutrientDisplayItem> items =
        [];

    // =====================================================
    // CORE NUTRIENTS
    // =====================================================

    if (values.energyKcal !=
        null) {
      items.add(
        _NutrientDisplayItem(
          name:
              'Energy',
          value:
              '${_format(values.energyKcal!)} kcal',
        ),
      );
    }

    if (values.energyKj !=
        null) {
      items.add(
        _NutrientDisplayItem(
          name:
              'Energy',
          value:
              '${_format(values.energyKj!)} kJ',
        ),
      );
    }

    if (values.proteinG !=
        null) {
      items.add(
        _NutrientDisplayItem(
          name:
              'Protein',
          value:
              '${_format(values.proteinG!)} g',
        ),
      );
    }

    if (values.totalFatG !=
        null) {
      items.add(
        _NutrientDisplayItem(
          name:
              'Total fat',
          value:
              '${_format(values.totalFatG!)} g',
        ),
      );
    }

    if (values.saturatedFatG !=
        null) {
      items.add(
        _NutrientDisplayItem(
          name:
              'Saturated fat',
          value:
              '${_format(values.saturatedFatG!)} g',
        ),
      );
    }

    if (values.transFatG !=
        null) {
      items.add(
        _NutrientDisplayItem(
          name:
              'Trans fat',
          value:
              '${_format(values.transFatG!)} g',
        ),
      );
    }

    if (values.carbohydrateG !=
        null) {
      items.add(
        _NutrientDisplayItem(
          name:
              'Carbohydrate',
          value:
              '${_format(values.carbohydrateG!)} g',
        ),
      );
    }

    if (values.sugarsG !=
        null) {
      items.add(
        _NutrientDisplayItem(
          name:
              'Sugars',
          value:
              '${_format(values.sugarsG!)} g',
        ),
      );
    }

    if (values.fibreG !=
        null) {
      items.add(
        _NutrientDisplayItem(
          name:
              'Fibre',
          value:
              '${_format(values.fibreG!)} g',
        ),
      );
    }

    if (values.sodiumMg !=
        null) {
      items.add(
        _NutrientDisplayItem(
          name:
              'Sodium',
          value:
              '${_format(values.sodiumMg!)} mg',
        ),
      );
    }

    if (values.cholesterolMg !=
        null) {
      items.add(
        _NutrientDisplayItem(
          name:
              'Cholesterol',
          value:
              '${_format(values.cholesterolMg!)} mg',
        ),
      );
    }

    // =====================================================
    // OTHER AVAILABLE NUTRIENTS
    // =====================================================

    final List<NutrientValue> other =
        values.otherNutrients.values
            .toList()
          ..sort(
            (
              NutrientValue a,
              NutrientValue b,
            ) =>
                a.name.compareTo(
              b.name,
            ),
          );

    for (final NutrientValue nutrient
        in other) {
      items.add(
        _NutrientDisplayItem(
          name:
              nutrient.name,
          value:
              '${_format(nutrient.amount)} ${nutrient.unit}',
        ),
      );
    }

    return Container(
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
            0xFFE4D9F7,
          ),
        ),
      ),
      child:
          Column(
        children: [
          for (int i = 0;
              i < items.length;
              i++) ...[
            _NutrientRow(
              name:
                  items[i].name,
              value:
                  items[i].value,
            ),

            if (i !=
                items.length -
                    1)
              const Divider(
                height:
                    1,
                indent:
                    16,
                endIndent:
                    16,
                color:
                    Color(
                  0xFFEDE7F6,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// =======================================================
// DISPLAY ITEM
// =======================================================

class _NutrientDisplayItem {
  final String name;

  final String value;

  const _NutrientDisplayItem({
    required this.name,
    required this.value,
  });
}

// =======================================================
// NUTRIENT ROW
// =======================================================

class _NutrientRow extends StatelessWidget {
  final String name;

  final String value;

  const _NutrientRow({
    required this.name,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            17,
        vertical:
            13,
      ),
      child:
          Row(
        children: [
          Expanded(
            child:
                Text(
              name,
              style:
                  const TextStyle(
                color:
                    Color(
                  0xFF38138C,
                ),
                fontSize:
                    14.5,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),

          const SizedBox(
            width:
                12,
          ),

          Text(
            value,
            style:
                const TextStyle(
              color:
                  Color(
                0xFF67558E,
              ),
              fontSize:
                  14.5,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}