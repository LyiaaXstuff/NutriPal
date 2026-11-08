import 'dart:typed_data';

import 'package:flutter/material.dart';

// =======================================================
// PROFILE AVATAR
// =======================================================
//
// The round profile picture on Profile and the Home
// header: the user's photo when they have one, otherwise
// the NutriPal person icon.
// =======================================================

class ProfileAvatar extends StatelessWidget {
  final Uint8List? photo;
  final double size;
  final double borderWidth;

  // Purple ring by default; white on a purple background.
  final Color borderColor;

  const ProfileAvatar({
    super.key,
    required this.photo,
    required this.size,
    this.borderWidth = 2,
    this.borderColor = const Color(0xFF4B2E83),
  });

  @override
  Widget build(BuildContext context) {
    final Uint8List? bytes = photo;

    // The photo is clipped to the full circle and the
    // purple ring is painted ON TOP of it (foreground), so
    // the ring stays an even, crisp line. (Painting the
    // ring underneath let the photo's edge bleed over it.)
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFF3ECFF),
      ),
      foregroundDecoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: ClipOval(
        child: SizedBox.expand(
          child: bytes == null
          ? Icon(
              Icons.person_rounded,
              color: const Color(0xFFB79BEA),
              size: size * 0.7,
              semanticLabel: 'Profile picture',
            )
          : Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              semanticLabel: 'Profile picture',
              errorBuilder: (BuildContext context, Object error, StackTrace? stack) => Icon(
                Icons.person_rounded,
                color: const Color(0xFFB79BEA),
                size: size * 0.7,
              ),
            ),
        ),
      ),
    );
  }
}
