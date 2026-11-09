import 'package:flutter/material.dart';

import '../models/nutrition_analysis.dart';

// =======================================================
// NUTRIPAL UI KIT (scan and analysis screens)
// =======================================================
//
// Colours and small widgets shared by Confirm photo,
// Analysing, Quick verification, Your nutrition insights,
// Edit nutrients and Ask NutriPal.
// =======================================================

class NpColors {
  NpColors._();

  static const Color purple = Color(0xFF4B2E83);
  static const Color teal = Color(0xFF17B6B1);
  static const Color background = Color(0xFFF7F2E9);

  static const Color ink = Color(0xFF24124F);
  static const Color bodyInk = Color(0xFF3A2668);
  static const Color muted = Color(0xFF6B5E86);

  static const Color card = Colors.white;
  static const Color cardBorder = Color(0xFFEDE4F7);
  static const Color softBorder = Color(0xFFE5DAF3);
  static const Color lilac = Color(0xFFF3EEFB);
  static const Color track = Color(0xFFEFE8F8);

  static const Color okBg = Color(0xFFDDF5F3);
  static const Color okInk = Color(0xFF0E6F6B);
  static const Color link = Color(0xFF0E7C78);

  static const Color selectedBg = Color(0xFFE3F7F6);
  static const Color selectedInk = Color(0xFF0B4F4C);

  static const Color warnBg = Color(0xFFFFF1D6);
  static const Color warnInk = Color(0xFF8A5200);

  static const Color errorBg = Color(0xFFFBE1DE);
  static const Color errorInk = Color(0xFF9B1C14);
}

class LevelStyle {
  final Color background;
  final Color ink;
  final Color bar;

  const LevelStyle(this.background, this.ink, this.bar);

  static LevelStyle of(NutrientLevel? level) => switch (level) {
        NutrientLevel.low =>
          const LevelStyle(Color(0xFFDDF4E7), Color(0xFF155E39), Color(0xFF2BA36A)),
        NutrientLevel.moderate =>
          const LevelStyle(Color(0xFFFFF1D6), Color(0xFF8A5200), Color(0xFFE09B1F)),
        NutrientLevel.high =>
          const LevelStyle(Color(0xFFFBE1DE), Color(0xFF9B1C14), Color(0xFFD2453B)),
        null => const LevelStyle(Color(0xFFEFE8F8), NpColors.muted, Color(0xFFB9AED0)),
      };
}

/// Round 44 px button used in the top bars.
class NpCircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const NpCircleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(side: BorderSide(color: NpColors.softBorder)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: NpColors.purple, size: 20),
          ),
        ),
      ),
    );
  }
}

/// Title row: left button, centred title, right widget.
class NpTopBar extends StatelessWidget {
  final String title;
  final Widget? leading;
  final Widget? trailing;

  const NpTopBar({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        leading ?? const SizedBox(width: 44, height: 44),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            // Same title style as every other screen.
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF38138C),
            ),
          ),
        ),
        trailing ?? const SizedBox(width: 44, height: 44),
      ],
    );
  }
}

class NpCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const NpCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: NpColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: NpColors.cardBorder),
      ),
      child: child,
    );
  }
}

class NpPill extends StatelessWidget {
  final String text;
  final Color background;
  final Color ink;

  const NpPill({
    super.key,
    required this.text,
    required this.background,
    required this.ink,
  });

  factory NpPill.level(NutrientLevel? level) {
    final LevelStyle s = LevelStyle.of(level);

    return NpPill(
      text: level?.label ?? 'Not enough info',
      background: s.background,
      ink: s.ink,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
      ),
    );
  }
}

class NpPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;
  final IconData? icon;

  const NpPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = NpColors.purple,
    this.textColor = Colors.white,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          disabledBackgroundColor: color.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        onPressed: onPressed,
        // Shrinks slightly in a narrow button instead of
        // cutting the label off with "...".
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Text(label, maxLines: 1),
            ],
          ),
        ),
      ),
    );
  }
}

class NpOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const NpOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: NpColors.purple,
          side: const BorderSide(color: NpColors.purple, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        onPressed: onPressed,
        child: Text(label, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

/// Round tick / cross / spinner used in check lists.
class NpCheckIcon extends StatelessWidget {
  // true = ok, false = problem, null = still checking.
  final bool? ok;

  const NpCheckIcon({super.key, required this.ok});

  @override
  Widget build(BuildContext context) {
    if (ok == null) {
      return const SizedBox(
        width: 28,
        height: 28,
        child: Padding(
          padding: EdgeInsets.all(5),
          child: CircularProgressIndicator(strokeWidth: 2.6, color: NpColors.purple),
        ),
      );
    }

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: ok! ? NpColors.okBg : NpColors.warnBg,
        shape: BoxShape.circle,
      ),
      child: Icon(
        ok! ? Icons.check_rounded : Icons.priority_high_rounded,
        size: 16,
        color: ok! ? NpColors.okInk : NpColors.warnInk,
      ),
    );
  }
}

const String npDisclaimer =
    "General guidance based on your label and profile, not a diagnosis or "
    "medical advice. Follow your doctor's or dietitian's advice.";
