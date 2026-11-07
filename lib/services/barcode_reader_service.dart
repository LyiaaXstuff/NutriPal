import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

// =======================================================
// BARCODE READER (on-device, ML Kit)
// =======================================================
//
// Finds the product barcode in a photo. Only retail
// product formats are read (EAN-13, EAN-8, UPC-A, UPC-E),
// so QR codes and other codes on the pack are ignored.
// =======================================================

class BarcodeReaderService {
  BarcodeReaderService._();

  static const List<BarcodeFormat> _productFormats = <BarcodeFormat>[
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
    BarcodeFormat.upca,
    BarcodeFormat.upce,
  ];

  /// Digits of the product barcode, or null if none found.
  static Future<String?> read(String imagePath) async {
    final BarcodeScanner scanner = BarcodeScanner(formats: _productFormats);

    try {
      final List<Barcode> barcodes =
          await scanner.processImage(InputImage.fromFilePath(imagePath));

      for (final Barcode barcode in barcodes) {
        final String digits =
            (barcode.rawValue ?? '').replaceAll(RegExp(r'\D'), '');

        if (digits.length >= 8) return digits;
      }

      return null;
    } finally {
      await scanner.close();
    }
  }
}
