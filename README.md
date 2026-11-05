# NutriPal

Nutrition-label scanning and portion calculations. For Azure Document
Intelligence Layout scanning, follow [the setup guide](docs/azure-layout-setup.md).
The guide covers Azure credentials, the local Python backend, Android emulator
and USB phone commands, and the calculation review process.

Run without a scan API URL to use on-device text recognition:

```sh
flutter pub get --enforce-lockfile
flutter run
```

Extraction behaviour and local regression checks are described in
[nutrition-label extraction](docs/nutrition-label-extraction.md).


Use a Flutter SDK compatible with the Dart constraint in `pubspec.yaml`.
The checks were run with Flutter 3.47.9 / Dart 3.13.7. Native scan support
requires Android or iOS.
