import 'package:flutter/material.dart';

import '../models/profile_setup_data.dart';
import '../models/scan_record.dart';
import 'nutrition_insights_screen.dart';
import 'scan_flow.dart';

/// Reopens a saved scan (Recent scans, History,
/// Favourites) on "Your nutrition insights". The result is
/// recalculated with the user's current profile, so it
/// reflects any profile changes since the scan.
Future<void> openSavedScan(
  BuildContext context, {
  required ScanRecord record,
  required ProfileSetupData profile,
}) {
  return Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (BuildContext context) => NutritionInsightsScreen(
        data: record.label,
        imagePath: record.thumbnailPath,
        flow: ScanFlowContext(profile: profile),
        savedRecordId: record.id,
        savedProductName: record.productName,
      ),
    ),
  );
}
