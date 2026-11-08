import 'dart:typed_data';

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

  // =====================================================
  // DIABETES
  // =====================================================

  String? diabetesType;

  // Possible values:
  // Prediabetes
  // Type 1 diabetes
  // Type 2 diabetes
  // Not sure

  // =====================================================
  // HIGH CHOLESTEROL
  // =====================================================

  bool highLdl;

  bool highTriglycerides;

  bool cholesterolNotSure;

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

  // Possible values:
  // Sedentary
  // Lightly active
  // Moderately active
  // Very active

  // =====================================================
  // LIMITS FROM THE USER'S DOCTOR OR DIETITIAN (optional)
  // =====================================================
  //
  // When set, these replace NutriPal's default targets in
  // the nutrition analysis (rules document, Layer 2).

  double? providerSodiumLimitMg;

  double? providerCarbsPerMealG;

  double? providerEnergyKcal;

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

    // DIABETES
    this.diabetesType,

    // CHOLESTEROL
    this.highLdl = false,
    this.highTriglycerides = false,
    this.cholesterolNotSure = false,

    // WEIGHT MANAGEMENT
    this.weightGoal,
    this.genderForEnergyEstimate,
    this.currentWeight,
    this.weightUnit = 'kg',
    this.height,
    this.heightUnit = 'cm',
    this.activityLevel,

    // PROVIDER LIMITS
    this.providerSodiumLimitMg,
    this.providerCarbsPerMealG,
    this.providerEnergyKcal,

    // NUTRITION PERSONALITY
    this.nutritionPersonality,

    // AVATAR
    this.avatarPath,
  });

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

  static const int schemaVersion = 1;

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
        'diabetesType': diabetesType,
        'cholesterol': <String, dynamic>{
          'highLdl': highLdl,
          'highTriglycerides': highTriglycerides,
          'notSure': cholesterolNotSure,
        },
        'weight': <String, dynamic>{
          'goal': weightGoal,
          'sex': genderForEnergyEstimate,
          'currentWeight': currentWeight,
          'weightUnit': weightUnit,
          'height': height,
          'heightUnit': heightUnit,
          'activityLevel': activityLevel,
        },
        'providerLimits': <String, dynamic>{
          'sodiumMg': providerSodiumLimitMg,
          'carbsPerMealG': providerCarbsPerMealG,
          'energyKcal': providerEnergyKcal,
        },
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
    final Map<String, dynamic> cholesterol = group('cholesterol');
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
      diabetesType: textOrNull(json['diabetesType']),
      highLdl: flag(cholesterol['highLdl']),
      highTriglycerides: flag(cholesterol['highTriglycerides']),
      cholesterolNotSure: flag(cholesterol['notSure']),
      weightGoal: textOrNull(weight['goal']),
      genderForEnergyEstimate: textOrNull(weight['sex']),
      currentWeight: number(weight['currentWeight']),
      weightUnit: text(weight['weightUnit'], 'kg'),
      height: number(weight['height']),
      heightUnit: text(weight['heightUnit'], 'cm'),
      activityLevel: textOrNull(weight['activityLevel']),
      providerSodiumLimitMg: number(limits['sodiumMg']),
      providerCarbsPerMealG: number(limits['carbsPerMealG']),
      providerEnergyKcal: number(limits['energyKcal']),
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