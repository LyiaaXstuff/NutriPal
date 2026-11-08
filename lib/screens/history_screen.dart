import 'package:flutter/material.dart';

import '../models/profile_setup_data.dart';
import '../models/scan_record.dart';
import '../services/scan_history_service.dart';
import '../widgets/nutripal_ui.dart';
import '../widgets/scan_record_card.dart';
import 'saved_scan_navigation.dart';

// =======================================================
// SCAN HISTORY
// =======================================================
//
// Every scan that has not expired, newest first. Reached
// from Home (Recent scans -> View all) and Profile (Scan
// history); it is not a bottom-navigation tab.
//
// Scans are kept for 90 days unless saved as a favourite.
// Opening this screen also runs the clean-up.
// =======================================================

class HistoryScreen extends StatefulWidget {
  final ProfileSetupData profile;

  const HistoryScreen({super.key, required this.profile});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ScanHistoryService _history = ScanHistoryService.instance;

  @override
  void initState() {
    super.initState();
    _history.cleanUpExpired();
  }

  String _note(ScanRecord r) {
    if (r.isFavourite) return 'Favourite · kept until you remove it';

    final int days = _history.policy.daysLeft(r, _history.now) ?? 0;

    if (days <= 1) return 'Removed from history tomorrow';

    return 'Kept for $days more days';
  }

  void _message(String text, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          action: action,
          backgroundColor: NpColors.purple,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _toggleFavourite(ScanRecord r) async {
    final ScanRecord? updated = await _history.toggleFavourite(r.id);

    if (!mounted || updated == null) return;

    _message(updated.isFavourite ? 'Added to favourites.' : 'Removed from favourites.');
  }

  Future<bool> _confirmRemove(ScanRecord r) async {
    if (r.isFavourite) {
      _message('Remove it from Favourites first.');
      return false;
    }

    return true;
  }

  Future<void> _remove(ScanRecord r) async {
    final bool removed = await _history.deleteScan(r.id);

    if (!mounted || !removed) return;

    _message(
      'Removed from history.',
      action: SnackBarAction(
        label: 'Undo',
        textColor: Colors.white,
        onPressed: () => _history.restore(r),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NpColors.background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _history,
          builder: (BuildContext context, Widget? child) {
            final List<ScanRecord> records = _history.history;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
              children: [
                // Same header as My Account and Security:
                // back arrow on the left, title centred.
                SizedBox(
                  height: 46,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          tooltip: 'Back',
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Color(0xFF38138C),
                            size: 24,
                          ),
                        ),
                      ),
                      const Text(
                        'Scan History',
                        style: TextStyle(
                          color: Color(0xFF38138C),
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: NpColors.lilac,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule_rounded, color: NpColors.purple, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Scans are kept for ${_history.policy.retentionDays} days '
                          'unless saved as a favourite.',
                          style: const TextStyle(fontSize: 13.5, height: 1.4, color: NpColors.bodyInk),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (!_history.isLoaded)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: CircularProgressIndicator(color: NpColors.purple)),
                  )
                else if (records.isEmpty)
                  const _EmptyHistory()
                else
                  for (final ScanRecord r in records)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Dismissible(
                        key: ValueKey<String>('history-${r.id}'),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) => _confirmRemove(r),
                        onDismissed: (_) => _remove(r),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 22),
                          decoration: BoxDecoration(
                            color: NpColors.errorBg,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(Icons.delete_outline_rounded, color: NpColors.errorInk),
                        ),
                        child: ScanRecordCard(
                          record: r,
                          note: _note(r),
                          onTap: () => openSavedScan(context, record: r, profile: widget.profile),
                          onFavouriteTap: () => _toggleFavourite(r),
                        ),
                      ),
                    ),
                if (records.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Swipe left to remove a scan. Favourites stay until you un-favourite them.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: NpColors.muted),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return const NpCard(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        children: [
          CircleAvatar(
            radius: 31,
            backgroundColor: NpColors.lilac,
            child: Icon(Icons.history_rounded, color: NpColors.purple, size: 31),
          ),
          SizedBox(height: 14),
          Text(
            'No scans in the last 90 days',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: NpColors.ink),
          ),
          SizedBox(height: 6),
          Text(
            'Products you scan will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.4, color: NpColors.muted),
          ),
        ],
      ),
    );
  }
}
