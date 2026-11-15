# EER Coefficient Check (NASEM 2023, Table 5-16)

**Purpose:** Confirm that every coefficient in `energy_requirement.dart` (`EnergyRequirement.coefficients`) matches the official NASEM (2023) *Dietary Reference Intakes for Energy*, Table 5-16, p. 100 (adults 19 years and over).

**Equation used in code:**
EER (kcal/day) = Intercept + (Age coef x age in years) + (Height coef x height in cm) + (Weight coef x weight in kg)

**Source checked:** National Academies of Sciences, Engineering, and Medicine (2023). *Dietary Reference Intakes for Energy*. Washington, DC: The National Academies Press. PDF, 543 pages.

Checked by: Claude (AI), from the PDF text, 15 Nov 2026. Spot-checked by student: ____________ (date: ________)

**Result: all 8 equations, both standard errors and the age limit match the report exactly.**

## Coefficients (NASEM Table 5-16, p. 100)

| Sex | Activity level | Code: Intercept | Code: Age | Code: Height | Code: Weight | NASEM: Intercept | NASEM: Age | NASEM: Height | NASEM: Weight | Match |
|---|---|---|---|---|---|---|---|---|---|---|
| Male | Inactive | 753.07 | -10.83 | 6.50 | 14.10 | 753.07 | -10.83 | 6.50 | 14.10 | Y |
| Male | Low active | 581.47 | -10.83 | 8.30 | 14.94 | 581.47 | -10.83 | 8.30 | 14.94 | Y |
| Male | Active | 1004.82 | -10.83 | 6.52 | 15.91 | 1,004.82 | -10.83 | 6.52 | 15.91 | Y |
| Male | Very active | -517.88 | -10.83 | 15.61 | 19.11 | -517.88 | -10.83 | 15.61 | 19.11 | Y |
| Female | Inactive | 584.90 | -7.01 | 5.72 | 11.71 | 584.90 | -7.01 | 5.72 | 11.71 | Y |
| Female | Low active | 575.77 | -7.01 | 6.60 | 12.14 | 575.77 | -7.01 | 6.60 | 12.14 | Y |
| Female | Active | 710.25 | -7.01 | 6.54 | 12.34 | 710.25 | -7.01 | 6.54 | 12.34 | Y |
| Female | Very active | 511.83 | -7.01 | 9.07 | 12.56 | 511.83 | -7.01 | 9.07 | 12.56 | Y |

## Standard error of the predicted value (SEPV)

| Sex | Code (kcal) | NASEM page | NASEM value (kcal) | Match |
|---|---|---|---|---|
| Male | 342 | p. 156 | 342 ("The SEPV for men aged 19 years or older is 342 kcal") | Y |
| Female | 241 | p. 152 | 241 ("For women aged 19 years or more, the SEPV is 241 kcal/d") | Y |

## Other rules in the same file

| Rule | Code value | Where it comes from | Confirmed |
|---|---|---|---|
| Minimum age for adult equations | 19 years | NASEM Table 5-16, p. 100 (age group "19+ years") | Y |
| Provider figure minimum | 800 kcal | MOH obesity CPG 2023 / ADA [WT-18]; not in this report | Check KB source |
| Provider figure maximum | 5,000 kcal | No source found; developer-defined | Developer-defined |
| Provider note below | 1,200 kcal (F) / 1,500 kcal (M) | MOH obesity CPG 2023 [WT-13]; not in this report | Check KB source |

## Hand-calculated examples (expected values for unit tests)

Cases A and B are worked examples printed in the NASEM report itself, so they are the strongest test cases. Cases 1 and 2 were calculated by hand with the confirmed coefficients.

| Case | Sex | Age | Height (cm) | Weight (kg) | Activity | Hand calculation | Expected EER (kcal) | Source | App result | Match |
|---|---|---|---|---|---|---|---|---|---|---|
| A | Female | 22 | 165 | 63 | Low active | 575.77 - 7.01(22) + 6.60(165) + 12.14(63) | 2,275 (exact 2275.37) | NASEM p. 152 worked example | | |
| B | Male | 45 | 175 | 100 | Low active | 581.47 - 10.83(45) + 8.30(175) + 14.94(100) | 3,041 (exact 3040.62) | NASEM p. 156 worked example | | |
| 1 | Female | 30 | 160 | 60 | Low active | 575.77 - 7.01(30) + 6.60(160) + 12.14(60) | 2149.87 | Hand calculation | | |
| 2 | Male | 30 | 175 | 70 | Inactive | 753.07 - 10.83(30) + 6.50(175) + 14.10(70) | 2552.67 | Hand calculation | | |

Also from NASEM p. 152: for case A, about 68% of women like her need 2,034 to 2,516 kcal/day (EER plus or minus 241). This can test the app's `lowKcal` / `highKcal` range (expect about 2034.37 and 2516.37 before rounding).

## Result

Coefficient rows matching: 8 of 8
Standard errors matching: 2 of 2
Hand-calculated examples matching the app: ___ of 4 (fill in after running the app or unit tests)
