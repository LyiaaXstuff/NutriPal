import '../models/nutrition_analysis.dart' show ProductForm;
import '../models/profile_setup_data.dart';
import '../models/scan_record.dart';

// =======================================================
// SCAN FLOW CONTEXT
// =======================================================
//
// Passed from the Home screen through the scan screens:
//
//   Scan product -> Confirm photo -> Analysing
//     -> (Quick verification, only if values look wrong)
//     -> Your nutrition insights
//
// Barcode scans skip Confirm photo. Finished scans are
// saved to history by the result screen
// (ScanHistoryService).
//
// Compare can start the same flow to scan a new product A
// or B. The result screen then shows "Use as product A/B",
// which hands the saved scan back to Compare and returns
// there. Compare only pairs two foods or two drinks, so
// compareForm is the type the new product must have (null
// when the other slot is empty).
// =======================================================

class ScanFlowContext {
  final ProfileSetupData profile;

  // 'A' or 'B' when scanning for Compare; null otherwise.
  final String? compareLetter;

  // Food or drink, to match the other chosen product.
  final ProductForm? compareForm;

  // Gives the saved scan back to the Compare screen.
  final void Function(ScanRecord record)? onCompareResult;

  // The route that shows Compare, to return to.
  final Object? compareRoute;

  const ScanFlowContext({
    required this.profile,
    this.compareLetter,
    this.compareForm,
    this.onCompareResult,
    this.compareRoute,
  });

  bool get forCompare => compareLetter != null && onCompareResult != null;
}
