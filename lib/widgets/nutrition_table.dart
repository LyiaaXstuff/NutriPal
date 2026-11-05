import 'package:flutter/material.dart';

import '../models/nutrition_label_data.dart';

/// Displays the source table without regrouping or alphabetising nutrients.
class NutritionTable extends StatelessWidget {
  final NutritionLabelData data;
  const NutritionTable({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'No nutrient rows could be read. Retake the photo with the full label in focus.',
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (180 + data.columns.length * 140).toDouble();
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width < constraints.maxWidth ? constraints.maxWidth : width,
            child: Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: const {0: FixedColumnWidth(180)},
              border: const TableBorder(
                horizontalInside: BorderSide(color: Color(0xFFEDE7F6)),
              ),
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: Color(0xFFF0EAF8)),
                  children: [
                    _cell('Nutrient', heading: true),
                    for (final column in data.columns)
                      _cell(column.label, heading: true),
                  ],
                ),
                for (final row in data.rows)
                  TableRow(
                    key: ValueKey(row.id),
                    decoration: BoxDecoration(
                      color: row.needsReview
                          ? const Color(0xFFFFF9EC)
                          : Colors.white,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF38138C),
                              ),
                            ),
                            if (row.needsReview)
                              const Text(
                                'Check photo',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF90620E),
                                ),
                              ),
                          ],
                        ),
                      ),
                      for (final column in data.columns)
                        _cell(
                          row.cells[column.id]?.displayText ?? 'Not read',
                          review: row.cells[column.id]?.needsReview ?? true,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _cell(String text, {bool heading = false, bool review = false}) =>
      Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          text,
          style: TextStyle(
            color: review ? const Color(0xFF90620E) : const Color(0xFF4B2E83),
            fontWeight: heading ? FontWeight.w800 : FontWeight.w500,
            height: 1.4,
          ),
        ),
      );
}
