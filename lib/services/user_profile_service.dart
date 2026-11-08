import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/profile_setup_data.dart';

// =======================================================
// USER PROFILE SERVICE (Cloud Firestore)
// =======================================================
//
// Saves the profile and health settings so they are the
// same after logging out, on a new phone, or after
// reinstalling:
//
//   users/{uid}
//     profile        ProfileSetupData.toJson()
//     setupComplete  true once the setup forms are done
//     avatar         profile picture, small JPEG as base64
//                    (optional)
//     updatedAt      server time
//
// Only the signed-in owner can read or write it
// (firestore.rules). Firestore keeps an offline copy, so
// saving works without internet and is sent later.
// =======================================================

class UserProfileException implements Exception {
  final String message;

  const UserProfileException(this.message);

  @override
  String toString() => message;
}

class UserProfileService {
  UserProfileService._();

  static const String usersCollection = 'users';

  static bool get _available => Firebase.apps.isNotEmpty;

  static String? get _uid => _available ? FirebaseAuth.instance.currentUser?.uid : null;

  static DocumentReference<Map<String, dynamic>> userDoc(String uid) =>
      FirebaseFirestore.instance.collection(usersCollection).doc(uid);

  // =====================================================
  // SAVE
  // =====================================================

  /// Saves the whole profile for the signed-in user.
  ///
  /// Returns straight away: Firestore applies the change
  /// on the phone at once and uploads it when online.
  static void save(ProfileSetupData data) {
    final String? uid = _uid;

    if (uid == null) {
      _log('not signed in; profile not saved');
      return;
    }

    userDoc(uid)
        .set(
          <String, dynamic>{
            'profile': data.toJson(),
            'setupComplete': true,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        )
        .catchError((Object error) => _log('profile save failed: $error'));
  }

  // =====================================================
  // LOAD
  // =====================================================

  /// The signed-in user's profile, or null when they have
  /// not finished the setup forms yet.
  ///
  /// Throws [UserProfileException] when it cannot be read
  /// (for example offline on a new phone), so the app
  /// never mistakes "could not load" for "no profile".
  static Future<ProfileSetupData?> load() async {
    final User? user = _available ? FirebaseAuth.instance.currentUser : null;

    if (user == null) {
      throw const UserProfileException('Please log in again.');
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot;

    try {
      snapshot = await userDoc(user.uid).get().timeout(const Duration(seconds: 15));
    } catch (error) {
      _log('profile load failed: $error');

      throw const UserProfileException(
        'Could not load your NutriPal profile. '
        'Please check your internet connection and try again.',
      );
    }

    final Map<String, dynamic>? doc = snapshot.data();

    if (doc == null || doc['setupComplete'] != true || doc['profile'] is! Map) {
      return null;
    }

    final ProfileSetupData data = ProfileSetupData.fromJson(
      Map<String, dynamic>.from(doc['profile'] as Map),
      email: user.email ?? '',
    );

    data.avatarPhoto = decodeAvatar(doc['avatar']);

    return data;
  }

  // =====================================================
  // PROFILE PICTURE
  // =====================================================

  /// Saves (or, with null, removes) the profile picture.
  /// Returns straight away, like [save].
  static void saveAvatar(Uint8List? jpeg) {
    final String? uid = _uid;

    if (uid == null) {
      _log('not signed in; profile picture not saved');
      return;
    }

    userDoc(uid)
        .set(
          <String, dynamic>{
            'avatar': jpeg == null ? FieldValue.delete() : base64Encode(jpeg),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        )
        .catchError((Object error) => _log('profile picture save failed: $error'));
  }

  /// The stored picture, or null if missing or unreadable.
  static Uint8List? decodeAvatar(Object? value) {
    if (value is! String || value.isEmpty) return null;

    try {
      return base64Decode(value);
    } catch (_) {
      return null;
    }
  }

  // =====================================================
  // DELETE (account deletion)
  // =====================================================

  /// Deletes users/{uid}. Must run while still signed in
  /// (before the Firebase Auth account is deleted).
  static Future<void> delete(String uid) async {
    if (!_available) return;

    await userDoc(uid).delete().timeout(const Duration(seconds: 20));
  }

  static void _log(String message) {
    if (kDebugMode) debugPrint('[NutriPal profile] $message');
  }
}
