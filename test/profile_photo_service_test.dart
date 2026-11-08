import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nutripal/services/profile_photo_service.dart';
import 'package:nutripal/services/user_profile_service.dart';

void main() {
  group('Profile picture', () {
    test('a wide photo becomes a 320 px square JPEG', () {
      final img.Image wide = img.Image(width: 1200, height: 600);
      final Uint8List png = img.encodePng(wide);

      final Uint8List? jpeg = ProfilePhotoService.toSquareJpeg(png);

      expect(jpeg, isNotNull);

      final img.Image result = img.decodeJpg(jpeg!)!;

      expect(result.width, ProfilePhotoService.sizePx);
      expect(result.height, ProfilePhotoService.sizePx);

      // Small enough for the Firestore rule (< 300,000
      // characters as base64).
      expect(base64Encode(jpeg).length, lessThan(300000));
    });

    test('tall photos keep the top part, wide photos the middle', () {
      // 1000 x 2000 selfie: square of 1000, 20% down the
      // spare 1000 px.
      final PhotoCrop tall = ProfilePhotoService.squareCrop(1000, 2000);
      expect(tall.size, 1000);
      expect(tall.x, 0);
      expect(tall.y, 200);

      // 2000 x 1000 landscape: centred.
      final PhotoCrop wide = ProfilePhotoService.squareCrop(2000, 1000);
      expect(wide.size, 1000);
      expect(wide.x, 500);
      expect(wide.y, 0);

      // Already square: nothing cut.
      final PhotoCrop square = ProfilePhotoService.squareCrop(800, 800);
      expect((square.x, square.y, square.size), (0, 0, 800));
    });

    test('bytes that are not an image give null', () {
      expect(ProfilePhotoService.toSquareJpeg(Uint8List.fromList(<int>[1, 2, 3, 4])), isNull);
    });

    test('the stored text reads back to the same bytes', () {
      final Uint8List bytes = Uint8List.fromList(<int>[255, 216, 255, 224, 0, 16]);

      expect(UserProfileService.decodeAvatar(base64Encode(bytes)), bytes);
      expect(UserProfileService.decodeAvatar(null), isNull);
      expect(UserProfileService.decodeAvatar('not base64 !!'), isNull);
    });
  });
}
