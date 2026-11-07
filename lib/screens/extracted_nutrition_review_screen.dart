import 'package:flutter/material.dart';

import '../models/nutrition_label_data.dart';

class ExtractedNutritionReviewScreen
    extends StatelessWidget {
  final NutritionLabelData data;

  const ExtractedNutritionReviewScreen({
    super.key,
    required this.data,
  });

  // =====================================================
  // COLOURS
  // =====================================================

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

  String? get _servingEquivalentText {
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

    String unitName =
        data.servingUnitName!;

    if (amount > 1 &&
        !unitName.endsWith(
          's',
        )) {
      unitName =
          '${unitName}s';
    }

    return '$amountText $unitName';
  }

  // =====================================================
  // WHERE THE VALUES CAME FROM
  // =====================================================

  String _sourceSummary() {
    final int rows =
        data.nutrients.length;

    switch (data.extractionMethod) {
      case NutritionExtractionMethod.ai:
        return '$rows nutrient rows extracted from this label by NutriPal AI '
            '(checked against on-device reading).';
      case NutritionExtractionMethod.barcode:
        return '$rows nutrients found for barcode ${data.barcode ?? ''} '
            'in Open Food Facts.';
      case NutritionExtractionMethod.onDevice:
        return '$rows nutrient rows extracted from this label on your phone.';
    }
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
                        onPressed: () {
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
            // BODY
            // =================================================

            Expanded(
              child:
                  SingleChildScrollView(
                padding:
                    const EdgeInsets.fromLTRB(
                  22,
                  14,
                  22,
                  32,
                ),
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    // ===========================================
                    // HEADING
                    // ===========================================

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
                      'Make sure each nutrient and value matches the original nutrition label.',
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

                    // ===========================================
                    // PRODUCT (barcode scans)
                    // ===========================================

                    if (data.productName != null ||
                        data.productBrand != null) ...[
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
                              Colors.white,
                          borderRadius:
                              BorderRadius.circular(
                            18,
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
                            Row(
                          children: [
                            const Icon(
                              Icons
                                  .qr_code_scanner_rounded,
                              color:
                                  selectedTeal,
                              size:
                                  30,
                            ),
                            const SizedBox(
                              width:
                                  14,
                            ),
                            Expanded(
                              child:
                                  Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data.productName ??
                                        'Unnamed product',
                                    style:
                                        const TextStyle(
                                      color:
                                          darkPurple,
                                      fontSize:
                                          17,
                                      fontWeight:
                                          FontWeight.w800,
                                    ),
                                  ),
                                  if (data.productBrand != null)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(
                                        top:
                                            3,
                                      ),
                                      child:
                                          Text(
                                        data.productBrand!,
                                        style:
                                            const TextStyle(
                                          color:
                                              secondaryText,
                                          fontSize:
                                              14,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(
                        height:
                            22,
                      ),
                    ],

                    // ===========================================
                    // SERVING INFORMATION
                    // ===========================================

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
                          _servingEquivalentText,
                    ),

                    const SizedBox(
                      height:
                          26,
                    ),

                    // ===========================================
                    // NO COLUMNS
                    // ===========================================

                    if (data.columns.isEmpty)
                      const _WarningCard(
                        text:
                            'NutriPal detected nutrition text but could not determine the nutrition value columns.',
                      ),

                    // ===========================================
                    // EACH DETECTED COLUMN
                    // ===========================================

                    for (int columnIndex = 0;
                        columnIndex <
                            data.columns.length;
                        columnIndex++) ...[
                      _SectionTitle(
                        title:
                            data
                                .columns[
                                  columnIndex
                                ]
                                .label,
                      ),

                      const SizedBox(
                        height:
                            10,
                      ),

                      _DynamicNutritionCard(
                        data:
                            data,
                        columnIndex:
                            columnIndex,
                      ),

                      const SizedBox(
                        height:
                            26,
                      ),
                    ],

                    // ===========================================
                    // PORTION CALCULATION STATUS
                    // ===========================================

                    if (data.canCalculatePortion)
                      const _ReadyCard()
                    else
                      const _WarningCard(
                        text:
                            'Some serving or nutrition-column information is missing. NutriPal should not calculate the intended portion until the missing information is confirmed.',
                      ),

                    const SizedBox(
                      height:
                          18,
                    ),

                    // ===========================================
                    // DEVELOPMENT INFO
                    // ===========================================

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
                          0xFFF2EDFA,
                        ),
                        borderRadius:
                            BorderRadius.circular(
                          18,
                        ),
                      ),
                      child:
                          Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            _sourceSummary(),
                            style:
                                const TextStyle(
                              color:
                                  secondaryText,
                              fontSize:
                                  13.5,
                              height:
                                  1.4,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),

                          // Corrections and values to double-check.
                          for (final String note
                              in data.notes)
                            Padding(
                              padding:
                                  const EdgeInsets.only(
                                top:
                                    8,
                              ),
                              child:
                                  Text(
                                '• $note',
                                style:
                                    const TextStyle(
                                  color:
                                      secondaryText,
                                  fontSize:
                                      12.5,
                                  height:
                                      1.4,
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
// DYNAMIC NUTRITION CARD
// =======================================================

class _DynamicNutritionCard
    extends StatelessWidget {
  final NutritionLabelData data;

  final int columnIndex;

  const _DynamicNutritionCard({
    required this.data,
    required this.columnIndex,
  });

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

  @override
  Widget build(
    BuildContext context,
  ) {
    // =====================================================
    // SAME NUTRIENTS IN EVERY COLUMN, LABEL ORDER
    // =====================================================
    //
    // Every section (per serving, per 100 g / ml) lists
    // the same nutrients in the same order. A value that
    // could not be read shows "Not detected" instead of
    // the row disappearing.
    // =====================================================

    final List<NutrientRow> nutrientRows =
        List<NutrientRow>.of(
      data.nutrients,
    )..sort(
            (
              NutrientRow a,
              NutrientRow b,
            ) {
              return a.order.compareTo(
                b.order,
              );
            },
          );

    List<NutritionValue> valuesFor(
      NutrientRow row,
    ) {
      if (columnIndex >=
          row.valuesByColumn.length) {
        return const [];
      }

      return row.valuesByColumn[
          columnIndex];
    }

    final bool columnHasValues =
        nutrientRows.any(
      (
        NutrientRow row,
      ) {
        return valuesFor(
          row,
        ).isNotEmpty;
      },
    );

    if (nutrientRows.isEmpty ||
        !columnHasValues) {
      return const _WarningCard(
        text:
            'No nutrient values were extracted for this column.',
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
              i <
                  nutrientRows.length;
              i++) ...[
            _NutrientRowWidget(
              name:
                  nutrientRows[i]
                      .name,

              // Label wording when it differs from the
              // standard name ("Natrium" -> Sodium).
              labelName:
                  nutrientRows[i]
                          .hasDifferentLabelName
                      ? nutrientRows[i]
                          .labelName
                      : null,

              missing:
                  valuesFor(
                nutrientRows[i],
              ).isEmpty,

              value:
                  valuesFor(
                nutrientRows[i],
              ).isEmpty
                      ? 'Not detected'
                      : valuesFor(
                nutrientRows[i],
              )
                      .map(
                        (
                          NutritionValue value,
                        ) {
                          return '${_formatNumber(value.amount)} '
                              '${value.unit}';
                        },
                      )
                      .join(
                        ' / ',
                      ),
            ),

            if (i !=
                nutrientRows.length -
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
// NUTRIENT ROW
// =======================================================

class _NutrientRowWidget
    extends StatelessWidget {
  final String name;

  final String value;

  // True when this column has no value for the nutrient.
  final bool missing;

  // Wording printed on the label, shown under the name
  // when it differs from it.
  final String? labelName;

  const _NutrientRowWidget({
    required this.name,
    required this.value,
    this.missing = false,
    this.labelName,
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
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
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
                    height:
                        1.25,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                if (labelName != null)
                  Padding(
                    padding:
                        const EdgeInsets.only(
                      top:
                          2,
                    ),
                    child:
                        Text(
                      'On label: $labelName',
                      style:
                          const TextStyle(
                        color:
                            Color(
                          0xFF8A7BA8,
                        ),
                        fontSize:
                            12,
                        height:
                            1.25,
                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(
            width:
                12,
          ),

          Flexible(
            child:
                Text(
              value,
              textAlign:
                  TextAlign.right,
              style:
                  TextStyle(
                color:
                    missing
                        ? const Color(
                            0xFFB08A3E,
                          )
                        : const Color(
                            0xFF67558E,
                          ),
                fontSize:
                    missing
                        ? 13.5
                        : 14.5,
                height:
                    1.25,
                fontStyle:
                    missing
                        ? FontStyle.italic
                        : FontStyle.normal,
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
// READY CARD
// =======================================================

class _ReadyCard extends StatelessWidget {
  const _ReadyCard();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
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
                Color(
              0xFF17B6B1,
            ),
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
                    Color(
                  0xFF25104F,
                ),
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
    );
  }
}

// =======================================================
// WARNING CARD
// =======================================================

class _WarningCard extends StatelessWidget {
  final String text;

  const _WarningCard({
    required this.text,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
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
          Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color:
                Color(
              0xFFE69A17,
            ),
          ),

          const SizedBox(
            width:
                12,
          ),

          Expanded(
            child:
                Text(
              text,
              style:
                  const TextStyle(
                color:
                    Color(
                  0xFF25104F,
                ),
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
    );
  }
}