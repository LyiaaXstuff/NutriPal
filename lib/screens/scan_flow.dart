import '../models/profile_setup_data.dart';

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
// =======================================================

class ScanFlowContext {
  final ProfileSetupData profile;

  const ScanFlowContext({
    required this.profile,
  });
}
