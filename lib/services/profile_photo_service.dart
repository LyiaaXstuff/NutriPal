import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

// =======================================================
// PROFILE PHOTO SERVICE
// =======================================================
//
// Picks a photo from the phone's gallery and turns it into
// a small square profile picture:
//
//   - turned upright (phone photos often store rotation
//     separately)
//   - cropped automatically to a square that fits the
//     round frame: tall photos (selfies, portraits) keep
//     the upper part, where the face usually is; wide
//     photos are cropped from the middle
//   - resized to 320 x 320 px, JPEG (about 30-50 KB)
//
// The small size lets it live inside the user's Firestore
// profile (users/{uid}.avatar), so it follows the account
// to any phone and is deleted with the account.
// =======================================================

class ProfilePhotoException implements Exception {
  final String message;

  const ProfilePhotoException(this.message);

  @override
  String toString() => message;
}

class ProfilePhotoService {
  ProfilePhotoService._();

  static const int sizePx = 320;
  static const int jpegQuality = 82;

  // Where the square sits in a tall photo: 0 = top,
  // 0.5 = middle. 0.2 keeps the head in frame for most
  // selfies and portraits.
  static const double portraitTopBias = 0.2;

  /// The chosen photo as a small square JPEG, or null if
  /// the user closed the gallery without choosing.
  static Future<Uint8List?> pickFromGallery() async {
    final XFile? file;

    try {
      file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        // Smaller than the camera's full size, so it
        // loads and processes quickly.
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 95,
      );
    } catch (_) {
      throw const ProfilePhotoException(
        'NutriPal could not open your gallery. Please check the app’s photo permission.',
      );
    }

    if (file == null) return null;

    final Uint8List original = await file.readAsBytes();

    final Uint8List? square = await Isolate.run<Uint8List?>(() => toSquareJpeg(original));

    if (square == null) {
      throw const ProfilePhotoException('This photo could not be read. Please choose another one.');
    }

    return square;
  }

  /// Upright, centre-cropped, 320 px square JPEG; null if
  /// the bytes are not an image. Pure, so it is tested.
  static Uint8List? toSquareJpeg(Uint8List bytes) {
    img.Image? image = img.decodeImage(bytes);

    if (image == null) return null;

    image = img.bakeOrientation(image);

    final PhotoCrop crop = squareCrop(image.width, image.height);

    final img.Image square = img.copyResize(
      img.copyCrop(image, x: crop.x, y: crop.y, width: crop.size, height: crop.size),
      width: sizePx,
      height: sizePx,
      interpolation: img.Interpolation.average,
    );

    return img.encodeJpg(square, quality: jpegQuality);
  }

  /// The largest square that fits the photo: centred
  /// across the width, and in a tall photo placed near the
  /// top ([portraitTopBias]) so faces are not cut off.
  static PhotoCrop squareCrop(int width, int height) {
    final int size = width < height ? width : height;
    final int x = ((width - size) / 2).round();
    final int y = height > width
        ? ((height - size) * portraitTopBias).round()
        : ((height - size) / 2).round();

    return PhotoCrop(x: x, y: y, size: size);
  }
}

/// A square crop inside a photo, in pixels.
class PhotoCrop {
  final int x;
  final int y;
  final int size;

  const PhotoCrop({required this.x, required this.y, required this.size});
}
