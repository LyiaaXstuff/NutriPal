import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/nutrition_label_data.dart';
import '../services/barcode_reader_service.dart';
import '../services/food_database_service.dart';
import '../services/nutrition_label_ocr_service.dart';
import '../widgets/progress_dialog.dart';
import 'extracted_nutrition_review_screen.dart';
import 'scan_preview_screen.dart';

enum ScanMode {
  nutritionLabel,
  barcode,
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({
    super.key,
  });

  @override
  State<ScanScreen> createState() =>
      _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with WidgetsBindingObserver {
  // =====================================================
  // NUTRIPAL COLOURS
  // =====================================================

  static const Color primaryPurple =
      Color(0xFF4B2E83);

  static const Color darkPurple =
      Color(0xFF38138C);

  static const Color selectedTeal =
      Color(0xFF17B6B1);

  // =====================================================
  // CAMERA
  // =====================================================

  CameraController? _cameraController;

  final ImagePicker _imagePicker =
      ImagePicker();

  bool _isCameraReady = false;

  bool _isInitializing = true;

  bool _isCapturing = false;

  String? _cameraError;

  FlashMode _flashMode =
      FlashMode.off;

  ScanMode _scanMode =
      ScanMode.nutritionLabel;

  // =====================================================
  // INIT
  // =====================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(
      this,
    );

    _initializeCamera();
  }

  // =====================================================
  // DISPOSE
  // =====================================================

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(
      this,
    );

    _cameraController?.dispose();

    super.dispose();
  }

  // =====================================================
  // APP LIFECYCLE
  // =====================================================

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    final CameraController? controller =
        _cameraController;

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    if (state ==
        AppLifecycleState.inactive) {
      controller.dispose();

      _cameraController = null;

      if (mounted) {
        setState(() {
          _isCameraReady =
              false;
        });
      }
    } else if (state ==
        AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  // =====================================================
  // INITIALISE CAMERA
  // =====================================================

  Future<void> _initializeCamera() async {
    if (mounted) {
      setState(() {
        _isInitializing =
            true;

        _cameraError =
            null;
      });
    }

    try {
      final List<CameraDescription> cameras =
          await availableCameras();

      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _cameraError =
                'No camera was found on this device.';

            _isInitializing =
                false;
          });
        }

        return;
      }

      CameraDescription camera =
          cameras.first;

      for (final CameraDescription item
          in cameras) {
        if (item.lensDirection ==
            CameraLensDirection.back) {
          camera =
              item;

          break;
        }
      }

      await _cameraController?.dispose();

      final CameraController controller =
          CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio:
            false,
        imageFormatGroup:
            ImageFormatGroup.jpeg,
      );

      _cameraController =
          controller;

      await controller.initialize();

      await controller.lockCaptureOrientation(
        DeviceOrientation.portraitUp,
      );

      await controller.setFlashMode(
        FlashMode.off,
      );

      if (!mounted) {
        await controller.dispose();

        return;
      }

      setState(() {
        _flashMode =
            FlashMode.off;

        _isCameraReady =
            true;

        _isInitializing =
            false;
      });
    } on CameraException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isCameraReady =
            false;

        _isInitializing =
            false;

        switch (error.code) {
          case 'CameraAccessDenied':
            _cameraError =
                'Camera permission was denied. Allow camera access to scan nutrition labels.';
            break;

          case 'CameraAccessDeniedWithoutPrompt':
            _cameraError =
                'Camera access is disabled. Enable camera access in your device settings.';
            break;

          case 'CameraAccessRestricted':
            _cameraError =
                'Camera access is restricted on this device.';
            break;

          default:
            _cameraError =
                'NutriPal could not open the camera.';
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isCameraReady =
            false;

        _isInitializing =
            false;

        _cameraError =
            'NutriPal could not open the camera.';
      });
    }
  }

  // =====================================================
  // FLASH
  // =====================================================

  Future<void> _toggleFlash() async {
    final CameraController? controller =
        _cameraController;

    if (controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    try {
      if (_flashMode ==
          FlashMode.off) {
        await controller.setFlashMode(
          FlashMode.torch,
        );

        if (mounted) {
          setState(() {
            _flashMode =
                FlashMode.torch;
          });
        }
      } else {
        await controller.setFlashMode(
          FlashMode.off,
        );

        if (mounted) {
          setState(() {
            _flashMode =
                FlashMode.off;
          });
        }
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Flash is not available on this camera.',
      );
    }
  }

  // =====================================================
  // OPEN NUTRITION PREVIEW
  // =====================================================

  Future<void> _openNutritionPreview(
    String imagePath,
  ) async {
    if (!mounted) {
      return;
    }

    final String? confirmedImagePath =
        await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (
          BuildContext context,
        ) {
          return ScanPreviewScreen(
            imagePath:
                imagePath,

            // ===========================================
            // REAL OCR + LABEL VALIDATION
            // ===========================================

            onValidate:
                NutritionLabelOcrService
                    .validateStatus,
          );
        },
      ),
    );

    if (!mounted) {
      return;
    }

    // ===================================================
    // RETAKE / BACK
    // ===================================================
    //
    // If null is returned, user pressed:
    //
    // Retake
    // Back
    //
    // Stay on the camera screen.
    // ===================================================

    if (confirmedImagePath ==
        null) {
      return;
    }

    // ===================================================
    // CONFIRMED IMAGE
    // ===================================================
    //
    // Later we will replace this with:
    //
    // nutrient extraction
    // portion selection
    // personalised insights
    //
    // For now, return the confirmed image to the
    // previous screen.
    // ===================================================

    Navigator.pop(
      context,
      confirmedImagePath,
    );
  }

  // =====================================================
  // BARCODE -> FOOD DATABASE
  // =====================================================
  //
  // 1. Read the product barcode in the photo (on-device).
  // 2. Look it up in Open Food Facts.
  // 3. Show its nutrition facts on the review screen.
  //
  // If the product is not in the database (or has no
  // nutrition facts), offer to scan the nutrition label.
  // =====================================================

  Future<void> _lookUpBarcodePhoto(
    String imagePath,
  ) async {
    final String? code;

    try {
      code = await runWithProgress<String?>(
        context,
        () => BarcodeReaderService.read(imagePath),
      );
    } catch (_) {
      _showMessage(
        'NutriPal could not read the barcode. Please try again.',
      );

      return;
    }

    if (!mounted) {
      return;
    }

    if (code == null) {
      _showMessage(
        'No barcode found. Hold the barcode flat inside the frame and try again.',
      );

      return;
    }

    final String barcode =
        code;

    final NutritionLabelData? product;

    try {
      product = await runWithProgress<NutritionLabelData?>(
        context,
        () => FoodDatabaseService.lookup(barcode),
      );
    } on FoodDatabaseException catch (error) {
      _showMessage(
        error.message,
      );

      return;
    }

    if (!mounted) {
      return;
    }

    if (product == null ||
        product.nutrients.isEmpty) {
      await _offerLabelScan(
        barcode,
        productKnown:
            product != null,
      );

      return;
    }

    final NutritionLabelData found =
        product;

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (
          BuildContext context,
        ) {
          return ExtractedNutritionReviewScreen(
            data:
                found,
          );
        },
      ),
    );
  }

  Future<void> _offerLabelScan(
    String code, {
    required bool productKnown,
  }) async {
    final bool? scanLabel =
        await showDialog<bool>(
      context:
          context,
      builder: (
        BuildContext dialogContext,
      ) {
        return AlertDialog(
          title: Text(
            productKnown
                ? 'No nutrition facts yet'
                : 'Product not found',
            style:
                const TextStyle(
              color:
                  darkPurple,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          content: Text(
            productKnown
                ? 'Barcode $code is in the food database, but its nutrition facts have not been added yet.\n\nYou can scan the nutrition label instead.'
                : 'Barcode $code is not in the food database yet.\n\nYou can scan the nutrition label instead.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child:
                  const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    primaryPurple,
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child:
                  const Text(
                'Scan nutrition label',
              ),
            ),
          ],
        );
      },
    );

    if (scanLabel == true &&
        mounted) {
      _selectNutritionLabel();
    }
  }

  // =====================================================
  // CAPTURE IMAGE
  // =====================================================

  Future<void> _captureImage() async {
    final CameraController? controller =
        _cameraController;

    if (controller == null ||
        !controller.value.isInitialized ||
        _isCapturing) {
      return;
    }

    try {
      setState(() {
        _isCapturing =
            true;
      });

      final XFile image =
          await controller.takePicture();

      if (!mounted) {
        return;
      }

      setState(() {
        _isCapturing =
            false;
      });

      // =================================================
      // NUTRITION LABEL MODE
      // =================================================

      if (_scanMode ==
          ScanMode.nutritionLabel) {
        await _openNutritionPreview(
          image.path,
        );

        return;
      }

      // =================================================
      // BARCODE MODE
      // =================================================

      await _lookUpBarcodePhoto(
        image.path,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isCapturing =
            false;
      });

      _showMessage(
        'Unable to capture the image. Please try again.',
      );
    }
  }

  // =====================================================
  // GALLERY
  // =====================================================

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image =
          await _imagePicker.pickImage(
        source:
            ImageSource.gallery,
        imageQuality:
            95,
      );

      if (image == null ||
          !mounted) {
        return;
      }

      // =================================================
      // NUTRITION LABEL MODE
      // =================================================

      if (_scanMode ==
          ScanMode.nutritionLabel) {
        await _openNutritionPreview(
          image.path,
        );

        return;
      }

      // =================================================
      // BARCODE MODE
      // =================================================

      await _lookUpBarcodePhoto(
        image.path,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'Unable to open your gallery.',
      );
    }
  }

  // =====================================================
  // HELP
  // =====================================================

  void _showHelp() {
    showModalBottomSheet<void>(
      context:
          context,
      backgroundColor:
          Colors.transparent,
      builder: (
        BuildContext context,
      ) {
        return Container(
          padding:
              const EdgeInsets.fromLTRB(
            24,
            16,
            24,
            30,
          ),
          decoration:
              const BoxDecoration(
            color:
                Color(
              0xFFF7F2E9,
            ),
            borderRadius:
                BorderRadius.vertical(
              top:
                  Radius.circular(
                28,
              ),
            ),
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // =========================================
              // HANDLE
              // =========================================

              Center(
                child: Container(
                  width:
                      44,
                  height:
                      5,
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xFFE4D9F7,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height:
                    20,
              ),

              // =========================================
              // TITLE
              // =========================================

              const Text(
                'Scanning tips',
                style:
                    TextStyle(
                  color:
                      darkPurple,
                  fontSize:
                      22,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(
                height:
                    14,
              ),

              // =========================================
              // TIPS
              // =========================================

              const _HelpItem(
                number:
                    '1',
                text:
                    'Keep the full nutrition label inside the scan frame.',
              ),

              const SizedBox(
                height:
                    12,
              ),

              const _HelpItem(
                number:
                    '2',
                text:
                    'Make sure the label is clear, well lit and not blurry.',
              ),

              const SizedBox(
                height:
                    12,
              ),

              const _HelpItem(
                number:
                    '3',
                text:
                    'Avoid strong glare or shadows covering nutrient values.',
              ),

              const SizedBox(
                height:
                    12,
              ),

              const _HelpItem(
                number:
                    '4',
                text:
                    'You can also upload an existing photo from your gallery.',
              ),
            ],
          ),
        );
      },
    );
  }

  // =====================================================
  // MESSAGE
  // =====================================================

  void _showMessage(
    String message,
  ) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
            Text(
          message,
        ),
        backgroundColor:
            primaryPurple,
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  // =====================================================
  // SCAN MODE
  // =====================================================

  void _selectNutritionLabel() {
    setState(() {
      _scanMode =
          ScanMode.nutritionLabel;
    });
  }

  void _selectBarcode() {
    setState(() {
      _scanMode =
          ScanMode.barcode;
    });
  }

  // =====================================================
  // CAMERA PREVIEW
  // =====================================================

  Widget _buildCameraPreview() {
    final CameraController? controller =
        _cameraController;

    if (!_isCameraReady ||
        controller == null ||
        !controller.value.isInitialized) {
      return const SizedBox.expand(
        child:
            ColoredBox(
          color:
              Colors.black,
        ),
      );
    }

    final Size? previewSize =
        controller.value.previewSize;

    if (previewSize ==
        null) {
      return CameraPreview(
        controller,
      );
    }

    return SizedBox.expand(
      child:
          ClipRect(
        child:
            FittedBox(
          fit:
              BoxFit.cover,
          child:
              SizedBox(
            width:
                previewSize.height,
            height:
                previewSize.width,
            child:
                CameraPreview(
              controller,
            ),
          ),
        ),
      ),
    );
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          Colors.black,

      body:
          Stack(
        fit:
            StackFit.expand,
        children: [
          // =================================================
          // CAMERA PREVIEW
          // =================================================

          _buildCameraPreview(),

          // =================================================
          // SCANNER FRAME
          // =================================================

          if (_isCameraReady)
            LayoutBuilder(
              builder: (
                BuildContext context,
                BoxConstraints constraints,
              ) {
                final double screenWidth =
                    constraints.maxWidth;

                final double screenHeight =
                    constraints.maxHeight;

                // ===========================================
                // FRAME WIDTH
                // ===========================================

                final double frameWidth =
                    math.min(
                  screenWidth *
                      0.82,
                  390,
                );

                // ===========================================
                // FRAME HEIGHT
                // ===========================================

                final double frameHeight =
                    _scanMode ==
                            ScanMode
                                .nutritionLabel
                        ? math.min(
                            screenHeight *
                                0.48,
                            480,
                          )
                        : math.min(
                            screenHeight *
                                0.25,
                            230,
                          );

                // ===========================================
                // FRAME POSITION
                // ===========================================

                final double frameLeft =
                    (screenWidth -
                            frameWidth) /
                        2;

                final double frameTop =
                    _scanMode ==
                            ScanMode
                                .nutritionLabel
                        ? screenHeight *
                            0.18
                        : screenHeight *
                            0.25;

                final Rect frameRect =
                    Rect.fromLTWH(
                  frameLeft,
                  frameTop,
                  frameWidth,
                  frameHeight,
                );

                return Stack(
                  children: [
                    // =============================================
                    // DARK AREA AROUND FRAME
                    // =============================================

                    Positioned.fill(
                      child:
                          CustomPaint(
                        painter:
                            _ScannerOverlayPainter(
                          frameRect:
                              frameRect,
                        ),
                      ),
                    ),

                    // =============================================
                    // TEAL FRAME CORNERS
                    // =============================================

                    Positioned(
                      left:
                          frameRect.left,
                      top:
                          frameRect.top,
                      width:
                          frameRect.width,
                      height:
                          frameRect.height,
                      child:
                          CustomPaint(
                        painter:
                            const _ScannerCornersPainter(
                          color:
                              selectedTeal,
                        ),
                      ),
                    ),

                    // =============================================
                    // INSTRUCTION
                    // =============================================

                    Positioned(
                      top:
                          math.min(
                        frameRect.bottom +
                            30,
                        screenHeight -
                            285,
                      ),
                      left:
                          30,
                      right:
                          30,
                      child:
                          Center(
                        child:
                            Container(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal:
                                18,
                            vertical:
                                10,
                          ),
                          decoration:
                              BoxDecoration(
                            color:
                                Colors.black
                                    .withValues(
                              alpha:
                                  0.65,
                            ),
                            borderRadius:
                                BorderRadius.circular(
                              24,
                            ),
                            border:
                                Border.all(
                              color:
                                  Colors.white
                                      .withValues(
                                alpha:
                                    0.14,
                              ),
                            ),
                          ),
                          child:
                              Text(
                            _scanMode ==
                                    ScanMode
                                        .nutritionLabel
                                ? 'Position the full nutrition label inside the frame'
                                : 'Position the barcode inside the frame',
                            textAlign:
                                TextAlign.center,
                            style:
                                const TextStyle(
                              color:
                                  Colors.white,
                              fontSize:
                                  14,
                              fontWeight:
                                  FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

          // =================================================
          // TOP GRADIENT
          // =================================================

          Positioned(
            top:
                0,
            left:
                0,
            right:
                0,
            height:
                145,
            child:
                IgnorePointer(
              child:
                  Container(
                decoration:
                    BoxDecoration(
                  gradient:
                      LinearGradient(
                    begin:
                        Alignment.topCenter,
                    end:
                        Alignment.bottomCenter,
                    colors: [
                      Colors.black
                          .withValues(
                        alpha:
                            0.72,
                      ),
                      Colors.black
                          .withValues(
                        alpha:
                            0.30,
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // =================================================
          // BOTTOM GRADIENT
          // =================================================

          Positioned(
            left:
                0,
            right:
                0,
            bottom:
                0,
            height:
                310,
            child:
                IgnorePointer(
              child:
                  Container(
                decoration:
                    BoxDecoration(
                  gradient:
                      LinearGradient(
                    begin:
                        Alignment.bottomCenter,
                    end:
                        Alignment.topCenter,
                    colors: [
                      Colors.black
                          .withValues(
                        alpha:
                            0.86,
                      ),
                      Colors.black
                          .withValues(
                        alpha:
                            0.45,
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // =================================================
          // TOP BAR
          // =================================================

          Positioned(
            top:
                0,
            left:
                0,
            right:
                0,
            child:
                SafeArea(
              bottom:
                  false,
              child:
                  Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  16,
                  4,
                  16,
                  0,
                ),
                child:
                    SizedBox(
                  height:
                      52,
                  child:
                      Row(
                    children: [
                      // ===========================================
                      // BACK
                      // ===========================================

                      SizedBox(
                        width:
                            48,
                        height:
                            48,
                        child:
                            IconButton(
                          onPressed:
                              () {
                            Navigator.pop(
                              context,
                            );
                          },
                          padding:
                              EdgeInsets.zero,
                          splashRadius:
                              24,
                          icon:
                              const Icon(
                            Icons
                                .arrow_back_ios_new_rounded,
                            color:
                                Colors.white,
                            size:
                                27,
                          ),
                        ),
                      ),

                      // ===========================================
                      // TITLE
                      // ===========================================

                      const Expanded(
                        child:
                            Text(
                          'Scan product',
                          textAlign:
                              TextAlign.center,
                          style:
                              TextStyle(
                            color:
                                Colors.white,
                            fontSize:
                                22,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      ),

                      // ===========================================
                      // FLASH
                      // ===========================================

                      SizedBox(
                        width:
                            48,
                        height:
                            48,
                        child:
                            IconButton(
                          onPressed:
                              _toggleFlash,
                          padding:
                              EdgeInsets.zero,
                          splashRadius:
                              24,
                          icon:
                              Icon(
                            _flashMode ==
                                    FlashMode
                                        .off
                                ? Icons
                                    .flash_off_rounded
                                : Icons
                                    .flash_on_rounded,
                            color:
                                Colors.white,
                            size:
                                29,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // =================================================
          // BOTTOM CONTROLS
          // =================================================

          if (_isCameraReady)
            Positioned(
              left:
                  0,
              right:
                  0,
              bottom:
                  0,
              child:
                  SafeArea(
                top:
                    false,
                child:
                    Padding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    22,
                    0,
                    22,
                    18,
                  ),
                  child:
                      Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      // ===========================================
                      // MODE SELECTOR
                      // ===========================================

                      _ModeSelector(
                        selectedMode:
                            _scanMode,
                        onNutritionTap:
                            _selectNutritionLabel,
                        onBarcodeTap:
                            _selectBarcode,
                      ),

                      const SizedBox(
                        height:
                            22,
                      ),

                      // ===========================================
                      // GALLERY / CAMERA / HELP
                      // ===========================================

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .spaceBetween,
                        children: [
                          // =====================================
                          // GALLERY
                          // =====================================

                          _RoundControlButton(
                            icon:
                                Icons
                                    .photo_library_outlined,
                            onTap:
                                _pickFromGallery,
                          ),

                          // =====================================
                          // CAMERA
                          // =====================================

                          _CaptureButton(
                            isCapturing:
                                _isCapturing,
                            onTap:
                                _captureImage,
                          ),

                          // =====================================
                          // HELP
                          // =====================================

                          _RoundControlButton(
                            icon:
                                Icons
                                    .help_outline_rounded,
                            onTap:
                                _showHelp,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // =================================================
          // INITIALISING CAMERA
          // =================================================

          if (_isInitializing)
            const Positioned.fill(
              child:
                  ColoredBox(
                color:
                    Colors.black,
                child:
                    Center(
                  child:
                      CircularProgressIndicator(
                    color:
                        selectedTeal,
                  ),
                ),
              ),
            ),

          // =================================================
          // CAMERA ERROR
          // =================================================

          if (!_isInitializing &&
              _cameraError !=
                  null)
            Positioned.fill(
              child:
                  ColoredBox(
                color:
                    Color(
                  0xFF17131D,
                ),
                child:
                    SafeArea(
                  child:
                      Padding(
                    padding:
                        const EdgeInsets.all(
                      28,
                    ),
                    child:
                        Column(
                      children: [
                        // =====================================
                        // BACK
                        // =====================================

                        Align(
                          alignment:
                              Alignment.centerLeft,
                          child:
                              IconButton(
                            onPressed:
                                () {
                              Navigator.pop(
                                context,
                              );
                            },
                            icon:
                                const Icon(
                              Icons
                                  .arrow_back_ios_new_rounded,
                              color:
                                  Colors.white,
                            ),
                          ),
                        ),

                        const Spacer(),

                        // =====================================
                        // ICON
                        // =====================================

                        const Icon(
                          Icons
                              .no_photography_outlined,
                          color:
                              selectedTeal,
                          size:
                              62,
                        ),

                        const SizedBox(
                          height:
                              22,
                        ),

                        // =====================================
                        // TITLE
                        // =====================================

                        const Text(
                          'Camera unavailable',
                          textAlign:
                              TextAlign.center,
                          style:
                              TextStyle(
                            color:
                                Colors.white,
                            fontSize:
                                24,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),

                        const SizedBox(
                          height:
                              10,
                        ),

                        // =====================================
                        // MESSAGE
                        // =====================================

                        Text(
                          _cameraError!,
                          textAlign:
                              TextAlign.center,
                          style:
                              const TextStyle(
                            color:
                                Colors.white70,
                            fontSize:
                                15,
                            height:
                                1.4,
                          ),
                        ),

                        const SizedBox(
                          height:
                              24,
                        ),

                        // =====================================
                        // RETRY
                        // =====================================

                        SizedBox(
                          width:
                              180,
                          height:
                              48,
                          child:
                              ElevatedButton(
                            onPressed:
                                _initializeCamera,
                            style:
                                ElevatedButton
                                    .styleFrom(
                              backgroundColor:
                                  primaryPurple,
                              foregroundColor:
                                  Colors.white,
                            ),
                            child:
                                const Text(
                              'Try again',
                            ),
                          ),
                        ),

                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =======================================================
// MODE SELECTOR
// =======================================================

class _ModeSelector extends StatelessWidget {
  final ScanMode selectedMode;

  final VoidCallback onNutritionTap;

  final VoidCallback onBarcodeTap;

  const _ModeSelector({
    required this.selectedMode,
    required this.onNutritionTap,
    required this.onBarcodeTap,
  });

  static const Color selectedTeal =
      Color(0xFF17B6B1);

  static const Color selectedPurple =
      Color(0xFFB268FF);

  @override
  Widget build(
    BuildContext context,
  ) {
    final bool nutritionSelected =
        selectedMode ==
            ScanMode.nutritionLabel;

    return SizedBox(
      height:
          58,
      child:
          Stack(
        children: [
          Row(
            children: [
              // =============================================
              // NUTRITION LABEL
              // =============================================

              Expanded(
                child:
                    GestureDetector(
                  onTap:
                      onNutritionTap,
                  behavior:
                      HitTestBehavior.opaque,
                  child:
                      AnimatedDefaultTextStyle(
                    duration:
                        const Duration(
                      milliseconds:
                          220,
                    ),
                    style:
                        TextStyle(
                      color:
                          nutritionSelected
                              ? selectedPurple
                              : Colors.white70,
                      fontSize:
                          13,
                      fontWeight:
                          nutritionSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                    ),
                    child:
                        Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons
                              .receipt_long_rounded,
                          color:
                              nutritionSelected
                                  ? selectedPurple
                                  : Colors.white70,
                          size:
                              26,
                        ),

                        const SizedBox(
                          width:
                              8,
                        ),

                        const Flexible(
                          child:
                              Text(
                            'NUTRITION LABEL',
                            overflow:
                                TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // =============================================
              // DIVIDER
              // =============================================

              Container(
                width:
                    1,
                height:
                    36,
                color:
                    Colors.white
                        .withValues(
                  alpha:
                      0.30,
                ),
              ),

              // =============================================
              // BARCODE
              // =============================================

              Expanded(
                child:
                    GestureDetector(
                  onTap:
                      onBarcodeTap,
                  behavior:
                      HitTestBehavior.opaque,
                  child:
                      AnimatedDefaultTextStyle(
                    duration:
                        const Duration(
                      milliseconds:
                          220,
                    ),
                    style:
                        TextStyle(
                      color:
                          !nutritionSelected
                              ? selectedPurple
                              : Colors.white70,
                      fontSize:
                          13,
                      fontWeight:
                          !nutritionSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                    ),
                    child:
                        Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        _BarcodeSymbol(
                          color:
                              !nutritionSelected
                                  ? selectedPurple
                                  : Colors.white70,
                        ),

                        const SizedBox(
                          width:
                              8,
                        ),

                        const Text(
                          'BARCODE',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // =============================================
          // ACTIVE TEAL LINE
          // =============================================

          AnimatedAlign(
            duration:
                const Duration(
              milliseconds:
                  280,
            ),
            curve:
                Curves.easeInOutCubic,
            alignment:
                nutritionSelected
                    ? Alignment.bottomLeft
                    : Alignment.bottomRight,
            child:
                FractionallySizedBox(
              widthFactor:
                  0.5,
              child:
                  Center(
                child:
                    Container(
                  width:
                      70,
                  height:
                      4,
                  decoration:
                      BoxDecoration(
                    color:
                        selectedTeal,
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =======================================================
// BARCODE SYMBOL
// =======================================================

class _BarcodeSymbol
    extends StatelessWidget {
  final Color color;

  const _BarcodeSymbol({
    required this.color,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return CustomPaint(
      size:
          const Size(
        29,
        25,
      ),
      painter:
          _BarcodePainter(
        color:
            color,
      ),
    );
  }
}

class _BarcodePainter
    extends CustomPainter {
  final Color color;

  _BarcodePainter({
    required this.color,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final Paint paint =
        Paint()
          ..color =
              color
          ..strokeCap =
              StrokeCap.round;

    final List<double> xPositions =
        [
      1,
      5,
      8,
      13,
      16,
      21,
      24,
      28,
    ];

    final List<double> widths =
        [
      2,
      1.5,
      2.5,
      1.5,
      2,
      2.5,
      1.5,
      2,
    ];

    for (int i = 0;
        i <
            xPositions.length;
        i++) {
      paint.strokeWidth =
          widths[i];

      canvas.drawLine(
        Offset(
          xPositions[i],
          2,
        ),
        Offset(
          xPositions[i],
          size.height -
              2,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant _BarcodePainter oldDelegate,
  ) {
    return oldDelegate.color !=
        color;
  }
}

// =======================================================
// ROUND CONTROL BUTTON
// =======================================================

class _RoundControlButton
    extends StatelessWidget {
  final IconData icon;

  final VoidCallback onTap;

  const _RoundControlButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color:
          Colors.transparent,
      child:
          InkWell(
        onTap:
            onTap,
        customBorder:
            const CircleBorder(),
        child:
            Container(
          width:
              64,
          height:
              64,
          decoration:
              BoxDecoration(
            shape:
                BoxShape.circle,
            color:
                Colors.black
                    .withValues(
              alpha:
                  0.52,
            ),
            border:
                Border.all(
              color:
                  Colors.white
                      .withValues(
                alpha:
                    0.10,
              ),
            ),
          ),
          child:
              Icon(
            icon,
            color:
                Colors.white,
            size:
                30,
          ),
        ),
      ),
    );
  }
}

// =======================================================
// CAPTURE BUTTON
// =======================================================

class _CaptureButton extends StatelessWidget {
  final bool isCapturing;

  final VoidCallback onTap;

  const _CaptureButton({
    required this.isCapturing,
    required this.onTap,
  });

  static const Color capturePurple =
      Color(0xFF6F3BFF);

  static const Color selectedTeal =
      Color(0xFF17B6B1);

  @override
  Widget build(
    BuildContext context,
  ) {
    return GestureDetector(
      onTap:
          isCapturing
              ? null
              : onTap,
      child:
          AnimatedScale(
        duration:
            const Duration(
          milliseconds:
              150,
        ),
        scale:
            isCapturing
                ? 0.94
                : 1,
        child:
            Container(
          width:
              92,
          height:
              92,
          decoration:
              BoxDecoration(
            shape:
                BoxShape.circle,
            border:
                Border.all(
              color:
                  selectedTeal,
              width:
                  5,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    selectedTeal
                        .withValues(
                  alpha:
                      0.25,
                ),
                blurRadius:
                    14,
              ),
            ],
          ),
          padding:
              const EdgeInsets.all(
            7,
          ),
          child:
              Container(
            decoration:
                const BoxDecoration(
              shape:
                  BoxShape.circle,
              gradient:
                  LinearGradient(
                begin:
                    Alignment.topLeft,
                end:
                    Alignment.bottomRight,
                colors: [
                  Color(
                    0xFF8B4DFF,
                  ),
                  capturePurple,
                ],
              ),
            ),
            child:
                isCapturing
                    ? const Padding(
                        padding:
                            EdgeInsets.all(
                          26,
                        ),
                        child:
                            CircularProgressIndicator(
                          color:
                              Colors.white,
                          strokeWidth:
                              3,
                        ),
                      )
                    : const Icon(
                        Icons
                            .photo_camera_rounded,
                        color:
                            Colors.white,
                        size:
                            40,
                      ),
          ),
        ),
      ),
    );
  }
}

// =======================================================
// DARK SCANNER OVERLAY
// =======================================================

class _ScannerOverlayPainter
    extends CustomPainter {
  final Rect frameRect;

  _ScannerOverlayPainter({
    required this.frameRect,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final Paint paint =
        Paint()
          ..color =
              Colors.black
                  .withValues(
            alpha:
                0.28,
          );

    // TOP
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        0,
        size.width,
        frameRect.top,
      ),
      paint,
    );

    // LEFT
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        frameRect.top,
        frameRect.left,
        frameRect.height,
      ),
      paint,
    );

    // RIGHT
    canvas.drawRect(
      Rect.fromLTWH(
        frameRect.right,
        frameRect.top,
        size.width -
            frameRect.right,
        frameRect.height,
      ),
      paint,
    );

    // BOTTOM
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        frameRect.bottom,
        size.width,
        size.height -
            frameRect.bottom,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(
    covariant _ScannerOverlayPainter oldDelegate,
  ) {
    return oldDelegate.frameRect !=
        frameRect;
  }
}

// =======================================================
// SCANNER CORNERS
// =======================================================

class _ScannerCornersPainter
    extends CustomPainter {
  final Color color;

  const _ScannerCornersPainter({
    required this.color,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    const double cornerLength =
        30;

    const double radius =
        12;

    final Paint paint =
        Paint()
          ..color =
              color
          ..strokeWidth =
              6
          ..style =
              PaintingStyle.stroke
          ..strokeCap =
              StrokeCap.round;

    // TOP LEFT
    final Path topLeft =
        Path()
          ..moveTo(
            0,
            cornerLength,
          )
          ..lineTo(
            0,
            radius,
          )
          ..quadraticBezierTo(
            0,
            0,
            radius,
            0,
          )
          ..lineTo(
            cornerLength,
            0,
          );

    canvas.drawPath(
      topLeft,
      paint,
    );

    // TOP RIGHT
    final Path topRight =
        Path()
          ..moveTo(
            size.width -
                cornerLength,
            0,
          )
          ..lineTo(
            size.width -
                radius,
            0,
          )
          ..quadraticBezierTo(
            size.width,
            0,
            size.width,
            radius,
          )
          ..lineTo(
            size.width,
            cornerLength,
          );

    canvas.drawPath(
      topRight,
      paint,
    );

    // BOTTOM LEFT
    final Path bottomLeft =
        Path()
          ..moveTo(
            0,
            size.height -
                cornerLength,
          )
          ..lineTo(
            0,
            size.height -
                radius,
          )
          ..quadraticBezierTo(
            0,
            size.height,
            radius,
            size.height,
          )
          ..lineTo(
            cornerLength,
            size.height,
          );

    canvas.drawPath(
      bottomLeft,
      paint,
    );

    // BOTTOM RIGHT
    final Path bottomRight =
        Path()
          ..moveTo(
            size.width -
                cornerLength,
            size.height,
          )
          ..lineTo(
            size.width -
                radius,
            size.height,
          )
          ..quadraticBezierTo(
            size.width,
            size.height,
            size.width,
            size.height -
                radius,
          )
          ..lineTo(
            size.width,
            size.height -
                cornerLength,
          );

    canvas.drawPath(
      bottomRight,
      paint,
    );
  }

  @override
  bool shouldRepaint(
    covariant _ScannerCornersPainter oldDelegate,
  ) {
    return oldDelegate.color !=
        color;
  }
}

// =======================================================
// HELP ITEM
// =======================================================

class _HelpItem extends StatelessWidget {
  final String number;

  final String text;

  const _HelpItem({
    required this.number,
    required this.text,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width:
              28,
          height:
              28,
          decoration:
              const BoxDecoration(
            shape:
                BoxShape.circle,
            color:
                Color(
              0xFF17B6B1,
            ),
          ),
          alignment:
              Alignment.center,
          child:
              Text(
            number,
            style:
                const TextStyle(
              color:
                  Colors.white,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ),

        const SizedBox(
          width:
              12,
        ),

        Expanded(
          child:
              Padding(
            padding:
                const EdgeInsets.only(
              top:
                  3,
            ),
            child:
                Text(
              text,
              style:
                  const TextStyle(
                color:
                    Color(
                  0xFF67558E,
                ),
                fontSize:
                    14,
                height:
                    1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}