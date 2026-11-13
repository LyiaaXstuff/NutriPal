import 'dart:typed_data';

import '../services/energy_requirement.dart';
import 'nutrition_targets.dart';

class ProfileSetupData {
  // =====================================================
  // BASIC PROFILE INFORMATION
  // =====================================================

  String nickname;

  String fullName;

  String email;

  DateTime? dateOfBirth;

  // =====================================================
  // HEALTH CONDITIONS
  // =====================================================

  bool diabetes;

  bool hypertension;

  bool highCholesterol;

  bool weightManagement;

  bool generalNutrition;

  // Diabetes and high LDL cholesterol have no follow-up
  // questions: one Diabetes card and one LDL cholesterol
  // card are shown for everyone who selects them. Only
  // weight management asks follow-up questions.
  //
  // highCholesterol keeps its saved name (conditions.
  // highCholesterol) for older profiles; on screen it is
  // "High LDL cholesterol".

  // =====================================================
  // WEIGHT MANAGEMENT
  // =====================================================

  String? weightGoal;

  // Possible values:
  // Lose weight
  // Maintain weight
  // Gain weight

  String? genderForEnergyEstimate;

  // Possible values:
  // Male
  // Female

  double? currentWeight;

  String weightUnit;

  double? height;

  String heightUnit;

  String? activityLevel;

  // Possible values (NASEM 2023 activity levels, see
  // ActivityLevels in services/energy_requirement.dart):
  // Inactive
  // Low active
  // Active
  // Very active
  //
  // Older profiles saved "Sedentary", "Lightly active",
  // "Moderately active"; fromJson maps them to the nearest
  // NASEM level.

  // For "Lose weight" and "Gain weight" NutriPal applies a
  // fixed amount to the maintenance estimate internally
  // (500 kcal less / 300 kcal more, GoalEnergy in
  // services/energy_requirement.dart). It is not a user
  // setting: a user with their own figure enters it as
  // providerEnergyKcal below.

  // =====================================================
  // DAILY ENERGY FROM THE USER'S DOCTOR OR DIETITIAN
  // =====================================================
  //
  // providerEnergyKcal (800-5,000 kcal) replaces the NASEM
  // estimate and the weight-goal amount, and is shown as
  // "Set by your healthcare provider". Entered on the
  // Weight Management Goal screen.

  double? providerEnergyKcal;

  // =====================================================
  // NUTRITION TARGETS (Profile > Nutrition Targets)
  // =====================================================
  //
  // Optional carbohydrate, protein, fat, sugar, sodium,
  // saturated fat and fibre targets. Each one replaces
  // NutriPal's default for that nutrient.

  NutritionTargets nutritionTargets;

  // =====================================================
  // NUTRITION PERSONALITY
  // =====================================================

  String? nutritionPersonality;

  // Later, after the assessment, examples could be:
  // Nutrition Explorer
  // Balanced Planner
  // Label Detective
  // etc.

  // =====================================================
  // PROFILE AVATAR
  // =====================================================

  String? avatarPath;

  // The profile picture as a small square JPEG (see
  // ProfilePhotoService). Saved separately from toJson()
  // as users/{uid}.avatar, so a profile save never
  // re-uploads the photo.
  Uint8List? avatarPhoto;

  // This can later store:
  // - NutriPal mascot asset path
  // - uploaded gallery image path
  // - Firebase Storage URL

  // =====================================================
  // CONSTRUCTOR
  // =====================================================

  ProfileSetupData({
    // BASIC PROFILE
    this.nickname = '',
    this.fullName = '',
    this.email = '',
    this.dateOfBirth,

    // HEALTH CONDITIONS
    this.diabetes = false,
    this.hypertension = false,
    this.highCholesterol = false,
    this.weightManagement = false,
    this.generalNutrition = false,

    // WEIGHT MANAGEMENT
    this.weightGoal,
    this.genderForEnergyEstimate,
    this.currentWeight,
    this.weightUnit = 'kg',
    this.height,
    this.heightUnit = 'cm',
    this.activityLevel,

    // PROVIDER ENERGY
    this.providerEnergyKcal,

    // NUTRITION TARGETS
    NutritionTargets? nutritionTargets,

    // NUTRITION PERSONALITY
    this.nutritionPersonality,

    // AVATAR
    this.avatarPath,
  }) : nutritionTargets = nutritionTargets ?? NutritionTargets();

  // =====================================================
  // OPTIONAL HELPER
  // =====================================================

  bool get hasAnyHealthCondition {
    return diabetes ||
        hypertension ||
        highCholesterol ||
        weightManagement;
  }

  // =====================================================
  // OPTIONAL HELPER
  // =====================================================

  bool get hasNutritionPersonality {
    return nutritionPersonality != null &&
        nutritionPersonality!.trim().isNotEmpty;
  }

  // =====================================================
  // SAVE / LOAD (Firestore users/{uid}.profile)
  // =====================================================
  //
  // Not saved:
  //   email       comes from Firebase Auth when loading.
  //   avatarPath  a file on this phone only.
  //
  // dateOfBirth is saved as "yyyy-mm-dd" so it never moves
  // a day because of time zones.

  // 2: nutritionTargets added; sodium and carbohydrate
  //    moved there from providerLimits; the weight-goal
  //    energy change is no longer saved.
  // 3: the diabetes type and the cholesterol sub-type
  //    (LDL / triglycerides / not sure) are no longer
  //    asked or saved.
  static const int schemaVersion = 3;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schema': schemaVersion,
        'nickname': nickname,
        'fullName': fullName,
        'dateOfBirth': dateOfBirth == null ? null : _dateOnly(dateOfBirth!),
        'conditions': <String, dynamic>{
          'diabetes': diabetes,
          'hypertension': hypertension,
          'highCholesterol': highCholesterol,
          'weightManagement': weightManagement,
          'generalNutrition': generalNutrition,
        },
        // No longer asked (schema 3); cleared on save.
        'diabetesType': null,
        'cholesterol': null,
        'weight': <String, dynamic>{
          'goal': weightGoal,
          'sex': genderForEnergyEstimate,
          'currentWeight': currentWeight,
          'weightUnit': weightUnit,
          'height': height,
          'heightUnit': heightUnit,
          'activityLevel': activityLevel,
          // Older profiles saved a chosen amount; it is no
          // longer used, so clear it.
          'energyChangeKcal': null,
        },
        'providerLimits': <String, dynamic>{
          // Moved to nutritionTargets (schema 2).
          'sodiumMg': null,
          'carbsPerMealG': null,
          'energyKcal': providerEnergyKcal,
        },
        'nutritionTargets': nutritionTargets.toJson(),
        'nutritionPersonality': nutritionPersonality,
      };

  /// Reads a saved profile. Missing or broken fields fall
  /// back to the defaults instead of failing.
  static ProfileSetupData fromJson(
    Map<String, dynamic> json, {
    String email = '',
  }) {
    Map<String, dynamic> group(String key) {
      final Object? value = json[key];

      return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
    }

    String text(Object? v, [String fallback = '']) => v is String ? v : fallback;
    String? textOrNull(Object? v) => v is String && v.trim().isNotEmpty ? v : null;
    bool flag(Object? v) => v == true;
    double? number(Object? v) => v is num ? v.toDouble() : null;

    final Map<String, dynamic> conditions = group('conditions');
    final Map<String, dynamic> weight = group('weight');
    final Map<String, dynamic> limits = group('providerLimits');

    return ProfileSetupData(
      nickname: text(json['nickname']),
      fullName: text(json['fullName']),
      email: email,
      dateOfBirth: _parseDate(json['dateOfBirth']),
      diabetes: flag(conditions['diabetes']),
      hypertension: flag(conditions['hypertension']),
      highCholesterol: flag(conditions['highCholesterol']),
      weightManagement: flag(conditions['weightManagement']),
      generalNutrition: flag(conditions['generalNutrition']),
      weightGoal: textOrNull(weight['goal']),
      genderForEnergyEstimate: textOrNull(weight['sex']),
      currentWeight: number(weight['currentWeight']),
      weightUnit: text(weight['weightUnit'], 'kg'),
      height: number(weight['height']),
      heightUnit: text(weight['heightUnit'], 'cm'),
      activityLevel: ActivityLevels.normalise(textOrNull(weight['activityLevel'])),
      providerEnergyKcal: number(limits['energyKcal']),
      nutritionTargets: NutritionTargets.fromJson(group('nutritionTargets'), legacy: limits),
      nutritionPersonality: textOrNull(json['nutritionPersonality']),
    );
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDate(Object? value) {
    if (value is! String) return null;

    final RegExpMatch? m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value);

    if (m == null) return null;

    return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
  }
}