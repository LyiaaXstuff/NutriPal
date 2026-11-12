// =======================================================
// ENERGY REQUIREMENT (NASEM 2023 EER, adults 19+)
// =======================================================
//
// Pure Dart, no Flutter, so every number can be unit
// tested (test/energy_requirement_test.dart).
//
// Source: National Academies of Sciences, Engineering, and
// Medicine (2023). Dietary Reference Intakes for Energy.
//   Table 5-16, p. 100   adult EER equations
//   p. 101               used for every BMI category
//   pp. 152, 156         standard error of the prediction
//   Table 7-1, p. 148    examples of each activity level
//
// The EER is the energy needed to keep the current
// weight. For a weight goal NutriPal then applies a
// general, adjustable change (GoalEnergy below):
//   lose  500 kcal less by default (250 / 500 / 750),
//         never below 1,200 kcal (women) or 1,500 kcal
//         (men), and none when BMI is below 18.5
//   gain  300 kcal more by default (300 / 500)
// Only the energy target changes; the other limits stay
// based on the EER. A daily figure from the user's doctor
// or dietitian replaces all of this when one is entered.
//
// Knowledge base: GEN-19 (equations), GEN-20 (standard
// error), GEN-21 (activity levels), GEN-22 (maintenance,
// not weight change), WT-13 / WT-18 (deficit ranges,
// floors, provider targets), WT-08 (gain), WT-17 (low
// BMI); rule R-EN-02.
// =======================================================

// =======================================================
// ACTIVITY LEVELS (NASEM's four categories)
// =======================================================

class ActivityLevels {
  ActivityLevels._();

  // Stored values (Firestore users/{uid}.profile.weight).
  static const String inactive = 'Inactive';
  static const String lowActive = 'Low active';
  static const String active = 'Active';
  static const String veryActive = 'Very active';

  static const List<String> all = <String>[inactive, lowActive, active, veryActive];

  // Values saved before the switch from Mifflin-St Jeor.
  static const Map<String, String> _legacy = <String, String>{
    'sedentary': inactive,
    'lightly active': lowActive,
    'moderately active': active,
    'very active': veryActive,
  };

  /// One of [all], or null for an empty or unknown value.
  /// Older profiles ("Sedentary", "Lightly active"...) are
  /// mapped to the nearest NASEM level.
  static String? normalise(String? stored) {
    if (stored == null) return null;

    final String key = stored.trim().toLowerCase();

    for (final String level in all) {
      if (level.toLowerCase() == key) return level;
    }

    return _legacy[key];
  }
}

// =======================================================
// AGE (NutriPal is for adults aged 19 and over)
// =======================================================

class AdultAge {
  AdultAge._();

  /// The adult EER equations start at 19 years.
  static const int minimumYears = 19;

  /// Whole years on [today]. Time of day is ignored.
  static int yearsOn(DateTime born, DateTime today) {
    int years = today.year - born.year;

    if (today.month < born.month || (today.month == born.month && today.day < born.day)) {
      years--;
    }

    return years;
  }

  static bool isAdult(DateTime born, DateTime today) => yearsOn(born, today) >= minimumYears;

  /// The latest date of birth that is already 19 on
  /// [today]: the newest date the birthday picker allows.
  /// On 29 February the answer is 28 February, because the
  /// year 19 years back has no 29 February.
  static DateTime latestBirthDate(DateTime today) {
    final int year = today.year - minimumYears;
    final DateTime same = DateTime(year, today.month, today.day);

    // DateTime rolls 29 Feb into 1 Mar in a common year.
    if (same.month != today.month) {
      return DateTime(year, today.month + 1, 0);
    }

    return same;
  }
}

// =======================================================
// THE ESTIMATE
// =======================================================

class EnergyEstimate {
  /// Unrounded EER, used in every calculation.
  final double kcal;

  /// Standard error of the prediction for this sex.
  final double standardErrorKcal;

  const EnergyEstimate({required this.kcal, required this.standardErrorKcal});

  /// About 68% of people like this need between [lowKcal]
  /// and [highKcal] (EER plus or minus one standard error).
  double get lowKcal => kcal - standardErrorKcal;

  double get highKcal => kcal + standardErrorKcal;
}

class EnergyRequirement {
  EnergyRequirement._();

  // [intercept, age (years), height (cm), weight (kg)]
  // NASEM (2023) Table 5-16, adults 19 years and over.
  static const Map<String, Map<String, List<double>>> coefficients =
      <String, Map<String, List<double>>>{
    'male': <String, List<double>>{
      ActivityLevels.inactive: <double>[753.07, -10.83, 6.50, 14.10],
      ActivityLevels.lowActive: <double>[581.47, -10.83, 8.30, 14.94],
      ActivityLevels.active: <double>[1004.82, -10.83, 6.52, 15.91],
      ActivityLevels.veryActive: <double>[-517.88, -10.83, 15.61, 19.11],
    },
    'female': <String, List<double>>{
      ActivityLevels.inactive: <double>[584.90, -7.01, 5.72, 11.71],
      ActivityLevels.lowActive: <double>[575.77, -7.01, 6.60, 12.14],
      ActivityLevels.active: <double>[710.25, -7.01, 6.54, 12.34],
      ActivityLevels.veryActive: <double>[511.83, -7.01, 9.07, 12.56],
    },
  };

  // NASEM (2023) pp. 152 (women) and 156 (men).
  static const Map<String, double> standardErrorKcal = <String, double>{
    'male': 342,
    'female': 241,
  };

  // ---- daily figure from a doctor or dietitian ---------
  // Below 800 kcal is a very-low-calorie diet, which needs
  // medical supervision (MOH obesity CPG 2023; ADA 2026
  // 8.12), so NutriPal does not accept it [WT-18].
  static const double providerMinimumKcal = 800;
  static const double providerMaximumKcal = 5000;

  // Lower ends of the guideline weight-loss ranges
  // (1,200-1,500 kcal women, 1,500-1,800 kcal men) [WT-13].
  // A provider figure below these is still used, with a
  // short note.
  static const Map<String, double> providerNoteBelowKcal = <String, double>{
    'male': 1500,
    'female': 1200,
  };

  static String? _sexKey(String? sex) {
    final String? s = sex?.trim().toLowerCase();

    return s == 'male' || s == 'female' ? s : null;
  }

  /// The NASEM EER, or null when an input is missing, the
  /// user is under 19, or a measurement is not positive.
  static EnergyEstimate? estimate({
    required String? sex,
    required int? ageYears,
    required double? heightCm,
    required double? weightKg,
    required String? activity,
  }) {
    final String? s = _sexKey(sex);
    final String? level = ActivityLevels.normalise(activity);

    if (s == null || level == null) return null;
    if (ageYears == null || ageYears < AdultAge.minimumYears) return null;
    if (heightCm == null || weightKg == null || heightCm <= 0 || weightKg <= 0) return null;

    final List<double> c = coefficients[s]![level]!;

    return EnergyEstimate(
      kcal: c[0] + c[1] * ageYears + c[2] * heightCm + c[3] * weightKg,
      standardErrorKcal: standardErrorKcal[s]!,
    );
  }

  /// True when a doctor's or dietitian's figure can be
  /// used as the energy base.
  static bool providerTargetOk(double? kcal) =>
      kcal != null && kcal >= providerMinimumKcal && kcal <= providerMaximumKcal;

  /// True when an accepted provider figure is below the
  /// guideline weight-loss range for this sex.
  static bool providerTargetIsBelowGuideline(double kcal, String? sex) {
    final String? s = _sexKey(sex);

    return s != null && kcal < providerNoteBelowKcal[s]!;
  }
}

// =======================================================
// ENERGY FOR A WEIGHT GOAL
// =======================================================
//
// A general guide for judging products, not a diet plan.
//   lose  MOH obesity CPG 2023: 500-750 kcal a day less,
//         1,200-1,500 kcal (women) / 1,500-1,800 kcal
//         (men) [WT-13]. Default 500 = lower end.
//   gain  NHS: about 300-500 kcal a day more [WT-08].
//         Default 300 = lower end.
// The choices, defaults and the use of the floors are
// researcher-defined (rule R-EN-02).

class GoalEnergyResult {
  /// Energy target for judging each product's energy.
  final double kcal;

  /// Maintenance energy it was worked out from.
  final double maintenanceKcal;

  /// Amount the user chose or the default (positive), or
  /// 0 for "maintain" / no goal.
  final int requestedKcal;

  /// Applied change: negative for lose, positive for gain
  /// (smaller than requested when the floor applied).
  double get changeKcal => kcal - maintenanceKcal;

  /// The weight-loss floor stopped the full deficit (or
  /// any deficit, when maintenance is already below it).
  final bool floorApplied;

  /// The weight-loss floor for this sex (lose only).
  final double? floorKcal;

  /// No deficit because BMI is below 18.5.
  final bool lowBmi;

  const GoalEnergyResult({
    required this.kcal,
    required this.maintenanceKcal,
    required this.requestedKcal,
    this.floorApplied = false,
    this.floorKcal,
    this.lowBmi = false,
  });

  bool get adjusted => changeKcal.abs() >= 0.5;
}

class GoalEnergy {
  GoalEnergy._();

  static const List<int> loseOptions = <int>[250, 500, 750];
  static const List<int> gainOptions = <int>[300, 500];

  static const int defaultLoseKcal = 500;
  static const int defaultGainKcal = 300;

  /// Lowest daily energy NutriPal sets for weight loss
  /// (lower ends of the guideline ranges) [WT-13].
  static const Map<String, double> floorKcal = <String, double>{
    'male': 1500,
    'female': 1200,
  };

  /// Below this BMI no deficit is applied [WT-17].
  static const double lowBmi = 18.5;

  /// 'lose' | 'gain' | 'maintain' | null from a stored goal
  /// ("Lose weight") or an analysis goal ("lose").
  static String? goalKey(String? goal) {
    final String? g = goal?.trim().toLowerCase();

    if (g == null || g.isEmpty) return null;
    if (g.contains('lose')) return 'lose';
    if (g.contains('gain')) return 'gain';
    if (g.contains('maintain')) return 'maintain';

    return null;
  }

  /// The amount for this goal: the user's choice when it
  /// is one of the options, else the default; 0 for
  /// maintain or no goal.
  static int amountFor(String? goal, int? chosen) {
    switch (goalKey(goal)) {
      case 'lose':
        return loseOptions.contains(chosen) ? chosen! : defaultLoseKcal;
      case 'gain':
        return gainOptions.contains(chosen) ? chosen! : defaultGainKcal;
      default:
        return 0;
    }
  }

  static double? bmi(double? weightKg, double? heightCm) {
    if (weightKg == null || heightCm == null || weightKg <= 0 || heightCm <= 0) return null;

    final double m = heightCm / 100;

    return weightKg / (m * m);
  }

  /// Applies the goal to the maintenance energy.
  static GoalEnergyResult apply({
    required double maintenanceKcal,
    required String? goal,
    int? chosenKcal,
    String? sex,
    double? weightKg,
    double? heightCm,
  }) {
    final String? key = goalKey(goal);
    final int amount = amountFor(goal, chosenKcal);

    if (key == 'gain') {
      return GoalEnergyResult(
        kcal: maintenanceKcal + amount,
        maintenanceKcal: maintenanceKcal,
        requestedKcal: amount,
      );
    }

    if (key != 'lose') {
      return GoalEnergyResult(kcal: maintenanceKcal, maintenanceKcal: maintenanceKcal, requestedKcal: 0);
    }

    final double? b = bmi(weightKg, heightCm);

    if (b != null && b < lowBmi) {
      return GoalEnergyResult(
        kcal: maintenanceKcal,
        maintenanceKcal: maintenanceKcal,
        requestedKcal: amount,
        lowBmi: true,
      );
    }

    final double floor = floorKcal[sex?.trim().toLowerCase()] ?? floorKcal['female']!;
    final double wanted = maintenanceKcal - amount;

    // Never below the floor, and never above maintenance
    // (when maintenance itself is under the floor).
    final double target = wanted >= floor
        ? wanted
        : (maintenanceKcal < floor ? maintenanceKcal : floor);

    return GoalEnergyResult(
      kcal: target,
      maintenanceKcal: maintenanceKcal,
      requestedKcal: amount,
      floorApplied: target > wanted,
      floorKcal: floor,
    );
  }
}
