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
}