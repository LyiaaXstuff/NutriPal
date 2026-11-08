import 'package:flutter/material.dart';

import '../models/profile_setup_data.dart';
import '../models/scan_record.dart';
import '../services/scan_history_service.dart';
import '../widgets/scan_record_card.dart';
import 'saved_scan_navigation.dart';

// =======================================================
// FAVOURITES (bottom-navigation tab)
// =======================================================
//
// Products the user saved on purpose. They are never
// removed by the 90-day history clean-up; only the user
// removes them (heart button, with Undo).
// =======================================================

class FavouritesScreen extends StatefulWidget {
  final ProfileSetupData profile;

  const FavouritesScreen({super.key, required this.profile});

  @override
  State<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends State<FavouritesScreen> {
  static const Color _background = Color(0xFFF7F2E9);
  static const Color _ink = Color(0xFF38138C);
  static const Color _muted = Color(0xFF67558E);
  static const Color _purple = Color(0xFF4B2E83);

  final ScanHistoryService _history = ScanHistoryService.instance;

  @override
  void initState() {
    super.initState();
    _history.cleanUpExpired();
  }

  Future<void> _unfavourite(ScanRecord r) async {
    await _history.setFavourite(r.id, false);

    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${r.productName} removed from favourites.'),
          backgroundColor: _purple,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: () {
              // Still in history: just favourite it again.
              // Already expired (old scan): put it back.
              if (_history.byId(r.id) != null) {
                _history.setFavourite(r.id, true);
              } else {
                _history.restore(r);
              }
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _background,
      child: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _history,
          builder: (BuildContext context, Widget? child) {
            final List<ScanRecord> favourites = _history.favourites;

            return ListView(
              // Room for the floating navigation bar.
              padding: EdgeInsets.fromLTRB(
                22,
                22,
                22,
                30 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                const Text(
                  'Favourites',
                  style: TextStyle(color: _ink, fontSize: 26, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Products you saved for later.',
                  style: TextStyle(color: _muted, fontSize: 14.5),
                ),
                const SizedBox(height: 18),
                if (!_history.isLoaded)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: CircularProgressIndicator(color: _purple)),
                  )
                else if (favourites.isEmpty)
                  const _EmptyFavourites()
                else
                  for (final ScanRecord r in favourites)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ScanRecordCard(
                        record: r,
                        showSummary: true,
                        onTap: () => openSavedScan(context, record: r, profile: widget.profile),
                        onFavouriteTap: () => _unfavourite(r),
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

class _EmptyFavourites extends StatelessWidget {
  const _EmptyFavourites();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCCFF0)),
      ),
      child: const Column(
        children: [
          CircleAvatar(
            radius: 31,
            backgroundColor: Color(0xFFF3ECFF),
            child: Icon(Icons.favorite_border_rounded, color: Color(0xFF4B2E83), size: 31),
          ),
          SizedBox(height: 14),
          Text(
            'No favourites yet',
            style: TextStyle(color: Color(0xFF38138C), fontSize: 18, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'Tap the heart on a result to keep a product here. '
            'Favourites are never removed automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF756D7E), fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }
}
