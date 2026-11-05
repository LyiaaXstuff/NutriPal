import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/label_detection_status.dart';
import '../models/nutrition_label_data.dart';
import '../services/azure_layout_client.dart';
import '../services/nutrition_scan_service.dart';
import '../services/nutrition_label_parser_service.dart';
import 'extracted_nutrition_review_screen.dart';

class ScanPreviewScreen extends StatefulWidget {
  final String imagePath;

  final LabelDetectionStatus initialStatus;
  final Future<NutritionLabelData> Function(String)? onAnalyze;
  final bool? onlineScanning;


  final Future<LabelDetectionStatus> Function(
    String imagePath,
  )? onValidate;

  const ScanPreviewScreen({
    super.key,
    required this.imagePath,
    this.initialStatus = LabelDetectionStatus.unverified,
    this.onValidate,
    this.onAnalyze,
    this.onlineScanning,
  });

  @override
  State<ScanPreviewScreen> createState() =>
      _ScanPreviewScreenState();
}

class _ScanPreviewScreenState
    extends State<ScanPreviewScreen> {
  // =====================================================
  // NUTRIPAL COLOURS
  // =====================================================

  static const Color primaryPurple =
      Color(0xFF4B2E83);

  static const Color darkPurple =
      Color(0xFF25104F);

  static const Color selectedTeal =
      Color(0xFF17B6B1);

  static const Color backgroundColor =
      Color(0xFFFDFBFF);

  static const Color warningOrange =
      Color(0xFFE69A17);

  static const Color errorRed =
      Color(0xFFD84A4A);

  // =====================================================
  // STATE
  // =====================================================

  final ImagePicker _imagePicker =
      ImagePicker();

  late String _currentImagePath;

  late LabelDetectionStatus _status;

  bool _isChoosingPhoto =
      false;

  bool get _online => widget.onlineScanning ?? AzureLayoutClient.isConfigured;

  bool _isAnalysing =
      false;

  // =====================================================
  // INIT
  // =====================================================

  @override
  void initState() {
    super.initState();

    _currentImagePath =
        widget.imagePath;

    _status =
        widget.initialStatus;

    // Automatically validate the image when
    // the preview screen opens.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!mounted) {
          return;
        }

        if (_status ==
                LabelDetectionStatus.unverified &&
            widget.onValidate != null) {
          _checkLabel();
        }
      },
    );
  }

  // =====================================================
  // RETAKE
  // =====================================================

  void _retake() {
    Navigator.pop(
      context,
    );
  }

  // =====================================================
  // CHOOSE ANOTHER PHOTO
  // =====================================================

  Future<void> _choosePhoto() async {
    if (_isChoosingPhoto ||
        _isAnalysing) {
      return;
    }

    try {
      setState(() {
        _isChoosingPhoto =
            true;
      });

      final XFile? image =
          await _imagePicker.pickImage(
        source:
            ImageSource.gallery,
        imageQuality:
            95,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isChoosingPhoto =
            false;
      });

      if (image == null) {
        return;
      }

      setState(() {
        _currentImagePath =
            image.path;

        _status =
            LabelDetectionStatus.unverified;
      });

      // Automatically validate newly selected photo.
      if (widget.onValidate != null) {
        await _checkLabel();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isChoosingPhoto =
            false;
      });

      _showMessage(
        'Unable to open your gallery.',
      );
    }
  }

  // =====================================================
  // CHECK LABEL
  // =====================================================

  Future<void> _checkLabel() async {
    if (widget.onValidate == null) {
      _showMessage(
        'Nutrition label checking is unavailable.',
      );

      return;
    }

    if (_status ==
        LabelDetectionStatus.checking) {
      return;
    }

    if (_isAnalysing) {
      return;
    }

    setState(() {
      _status =
          LabelDetectionStatus.checking;
    });

    try {
      final LabelDetectionStatus result =
          await widget.onValidate!(
        _currentImagePath,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _status =
            result;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _status =
            LabelDetectionStatus.unverified;
      });

      _showMessage(
        'NutriPal could not check this image. Please try again.',
      );
    }
  }

  // =====================================================
  // ANALYSE LABEL
  // =====================================================

  Future<void> _analyseLabel({bool forceOffline = false}) async {
    if (_isAnalysing) {
      return;
    }

    try {
      setState(() {
        _isAnalysing =
            true;
      });

      // =================================================
      // PARSE THE NUTRITION LABEL
      // =================================================

      final nutritionData =
          await (forceOffline ? NutritionLabelParserService.parseImage
            : widget.onAnalyze ?? NutritionScanService.analyze)(_currentImagePath);

      if (!mounted) {
        return;
      }

      setState(() {
        _isAnalysing =
            false;
      });

      // =================================================
      // OPEN EXTRACTED NUTRITION REVIEW
      // =================================================

      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (
            BuildContext context,
          ) {
            return ExtractedNutritionReviewScreen(
              data:
                  nutritionData,
              sourceImagePath: _currentImagePath,
            );
          },
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() { _isAnalysing = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error is NutritionScanException ? error.message
            : 'NutriPal could not read this label. Retake the photo and try again.'),
        action: _online && !forceOffline ? SnackBarAction(label: 'Use on-device',
          onPressed: () => _analyseLabel(forceOffline: true)) : null,
      ));
    }
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
  // FRAME COLOUR
  // =====================================================

  Color get _frameColor {
    switch (_status) {
      case LabelDetectionStatus.unclear:
        return warningOrange;

      case LabelDetectionStatus.notDetected:
        return errorRed;

      case LabelDetectionStatus.unverified:
      case LabelDetectionStatus.checking:
      case LabelDetectionStatus.detected:
        return selectedTeal;
    }
  }

  // =====================================================
  // STATUS BADGE
  // =====================================================

  Widget? _buildStatusBadge() {
    switch (_status) {
      // ---------------------------------------------------
      // UNVERIFIED
      // ---------------------------------------------------

      case LabelDetectionStatus.unverified:
        return null;

      // ---------------------------------------------------
      // CHECKING
      // ---------------------------------------------------

      case LabelDetectionStatus.checking:
        return _StatusBadge(
          backgroundColor:
              const Color(
            0xFFF0EBFA,
          ),
          foregroundColor:
              primaryPurple,
          leading:
              const SizedBox(
            width:
                25,
            height:
                25,
            child:
                CircularProgressIndicator(
              strokeWidth:
                  2.7,
              color:
                  primaryPurple,
            ),
          ),
          text:
              'Checking nutrition label...',
        );

      // ---------------------------------------------------
      // READY
      // ---------------------------------------------------

      case LabelDetectionStatus.detected:
        return _StatusBadge(
          backgroundColor:
              const Color(
            0xFFE8FAF8,
          ),
          foregroundColor:
              const Color(
            0xFF06746E,
          ),
          leading:
              Container(
            width:
                34,
            height:
                34,
            decoration:
                const BoxDecoration(
              color:
                  selectedTeal,
              shape:
                  BoxShape.circle,
            ),
            child:
                const Icon(
              Icons.check_rounded,
              color:
                  Colors.white,
              size:
                  23,
            ),
          ),
          text:
              'Nutrition label ready',
        );

      // ---------------------------------------------------
      // INCOMPLETE
      // ---------------------------------------------------

      case LabelDetectionStatus.unclear:
        return _StatusBadge(
          backgroundColor:
              const Color(
            0xFFFFF5DF,
          ),
          foregroundColor:
              const Color(
            0xFF8C5A00,
          ),
          leading:
              Container(
            width:
                34,
            height:
                34,
            decoration:
                const BoxDecoration(
              color:
                  warningOrange,
              shape:
                  BoxShape.circle,
            ),
            child:
                const Icon(
              Icons.warning_amber_rounded,
              color:
                  Colors.white,
              size:
                  23,
            ),
          ),
          text:
              'Nutrition label incomplete',
        );

      // ---------------------------------------------------
      // NOT DETECTED
      // ---------------------------------------------------

      case LabelDetectionStatus.notDetected:
        return _StatusBadge(
          backgroundColor:
              const Color(
            0xFFFFEBEB,
          ),
          foregroundColor:
              const Color(
            0xFFA32929,
          ),
          leading:
              Container(
            width:
                34,
            height:
                34,
            decoration:
                const BoxDecoration(
              color:
                  errorRed,
              shape:
                  BoxShape.circle,
            ),
            child:
                const Icon(
              Icons.close_rounded,
              color:
                  Colors.white,
              size:
                  23,
            ),
          ),
          text:
              'No nutrition label detected',
        );
    }
  }

  // =====================================================
  // PANEL TITLE
  // =====================================================

  String get _panelTitle {
    switch (_status) {
      case LabelDetectionStatus.unverified:
        return 'Is the label clear?';

      case LabelDetectionStatus.checking:
        return 'Checking your photo';

      case LabelDetectionStatus.detected:
        return 'Label looks complete';

      case LabelDetectionStatus.unclear:
        return 'More of the label is needed';

      case LabelDetectionStatus.notDetected:
        return 'We couldn’t find a nutrition label';
    }
  }

  // =====================================================
  // PANEL DESCRIPTION
  // =====================================================

  String get _panelDescription {
    switch (_status) {
      case LabelDetectionStatus.unverified:
        return 'Make sure the serving information, nutrient names and nutrient values are fully visible.';

      case LabelDetectionStatus.checking:
        return 'NutriPal is checking whether the nutrition label contains enough readable information for analysis.';

      case LabelDetectionStatus.detected:
        return 'NutriPal found enough readable nutrition information to continue with the analysis.';

      case LabelDetectionStatus.unclear:
        return 'A nutrition label was found, but some serving information or nutrient values may be missing, cut off or difficult to read.';

      case LabelDetectionStatus.notDetected:
        return 'This photo does not appear to contain a nutrition information table. Try another photo with the full label visible.';
    }
  }

  // =====================================================
  // INFORMATION CARD
  // =====================================================

  Widget _buildInformationCard() {
    switch (_status) {
      // ---------------------------------------------------
      // UNVERIFIED
      // ---------------------------------------------------

      case LabelDetectionStatus.unverified:
        return const _InformationCard(
          icon:
              Icons.description_outlined,
          iconColor:
              primaryPurple,
          backgroundColor:
              Color(
            0xFFF3EDFF,
          ),
          text:
              'Keep the serving information, nutrient names and nutrient values visible.',
        );

      // ---------------------------------------------------
      // CHECKING
      // ---------------------------------------------------

      case LabelDetectionStatus.checking:
        return const _InformationCard(
          icon:
              Icons.document_scanner_outlined,
          iconColor:
              primaryPurple,
          backgroundColor:
              Color(
            0xFFF3EDFF,
          ),
          text:
              'Checking serving information and readable nutrient-value pairs.',
        );

      // ---------------------------------------------------
      // READY
      // ---------------------------------------------------

      case LabelDetectionStatus.detected:
        return const _InformationCard(
          icon:
              Icons.check_circle_outline_rounded,
          iconColor:
              selectedTeal,
          backgroundColor:
              Color(
            0xFFE9FAF8,
          ),
          text:
              'Enough serving information and nutrient values were captured for analysis.',
        );

      // ---------------------------------------------------
      // INCOMPLETE
      // ---------------------------------------------------

      case LabelDetectionStatus.unclear:
        return const _InformationCard(
          icon:
              Icons.warning_amber_rounded,
          iconColor:
              warningOrange,
          backgroundColor:
              Color(
            0xFFFFF5DF,
          ),
          text:
              'Retake the photo so the serving size and readable nutrient values are visible.',
        );

      // ---------------------------------------------------
      // NOT DETECTED
      // ---------------------------------------------------

      case LabelDetectionStatus.notDetected:
        return const _InformationCard(
          icon:
              Icons.image_search_rounded,
          iconColor:
              errorRed,
          backgroundColor:
              Color(
            0xFFFFEBEB,
          ),
          text:
              'Look for the Nutrition Information, Nutrition Facts or Maklumat Pemakanan table on the package.',
        );
    }
  }

  // =====================================================
  // BUTTONS
  // =====================================================

  Widget _buildButtons() {
    // Local label detection is only a preview hint. It must not block Azure
    // from reading a label that ML Kit could not recognise.
    if (_online && _status != LabelDetectionStatus.checking) {
      return Row(children: [
        Expanded(child: _SecondaryButton(text: 'Retake',
          onPressed: _isAnalysing ? null : _retake)),
        const SizedBox(width: 12),
        Expanded(child: _isAnalysing ? const _LoadingButton() : _PrimaryButton(
          text: 'Analyse label', icon: Icons.cloud_outlined, onPressed: _analyseLabel)),
      ]);
    }
    switch (_status) {
      // ---------------------------------------------------
      // UNVERIFIED
      // ---------------------------------------------------

      case LabelDetectionStatus.unverified:
        return Row(
          children: [
            Expanded(
              child:
                  _SecondaryButton(
                text:
                    'Retake',
                onPressed:
                    _retake,
              ),
            ),

            const SizedBox(
              width:
                  12,
            ),

            Expanded(
              child:
                  _PrimaryButton(
                text:
                    'Check label',
                icon:
                    Icons.document_scanner_outlined,
                onPressed:
                    _checkLabel,
              ),
            ),
          ],
        );

      // ---------------------------------------------------
      // CHECKING
      // ---------------------------------------------------

      case LabelDetectionStatus.checking:
        return const Row(
          children: [
            Expanded(
              child:
                  _SecondaryButton(
                text:
                    'Retake',
                onPressed:
                    null,
              ),
            ),

            SizedBox(
              width:
                  12,
            ),

            Expanded(
              child:
                  _LoadingButton(),
            ),
          ],
        );

      // ---------------------------------------------------
      // READY
      // ---------------------------------------------------

      case LabelDetectionStatus.detected:
        return Row(
          children: [
            Expanded(
              child:
                  _SecondaryButton(
                text:
                    'Retake',
                onPressed:
                    _isAnalysing
                        ? null
                        : _retake,
              ),
            ),

            const SizedBox(
              width:
                  12,
            ),

            Expanded(
              child:
                  _isAnalysing
                      ? const _LoadingButton()
                      : _PrimaryButton(
                          text:
                              'Analyse label',
                          icon:
                              Icons.arrow_forward_rounded,
                          onPressed:
                              _analyseLabel,
                        ),
            ),
          ],
        );

      // ---------------------------------------------------
      // INCOMPLETE
      // ---------------------------------------------------

      case LabelDetectionStatus.unclear:
        return Row(children: [
          Expanded(child: _SecondaryButton(text: 'Retake',
            onPressed: _isAnalysing ? null : _retake)),
          const SizedBox(width: 12),
          Expanded(child: _isAnalysing ? const _LoadingButton() : _PrimaryButton(
            text: 'Review readable values', icon: Icons.fact_check_outlined,
            onPressed: _analyseLabel)),
        ]);

      // ---------------------------------------------------
      // NOT DETECTED
      // ---------------------------------------------------

      case LabelDetectionStatus.notDetected:
        return Row(
          children: [
            Expanded(
              child:
                  _SecondaryButton(
                text:
                    'Retake',
                onPressed:
                    _retake,
              ),
            ),

            const SizedBox(
              width:
                  12,
            ),

            Expanded(
              child:
                  _PrimaryButton(
                text:
                    'Choose photo',
                icon:
                    Icons.photo_library_outlined,
                onPressed:
                    _isChoosingPhoto
                        ? null
                        : _choosePhoto,
              ),
            ),
          ],
        );
    }
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
          LayoutBuilder(
        builder: (
          BuildContext context,
          BoxConstraints constraints,
        ) {
          final double screenWidth =
              constraints.maxWidth;

          final double screenHeight =
              constraints.maxHeight;

          // =================================================
          // BOTTOM PANEL
          // =================================================

          final double sheetHeight =
              math.min(
            screenHeight *
                0.40,
            385,
          );

          final double sheetTop =
              screenHeight -
                  sheetHeight;

          // =================================================
          // REVIEW FRAME
          // =================================================

          final double frameWidth =
              math.min(
            screenWidth *
                0.82,
            390,
          );

          final double frameLeft =
              (screenWidth -
                      frameWidth) /
                  2;

          final double frameTop =
              screenHeight *
                  0.145;

          final double availableHeight =
              sheetTop -
                  frameTop +
                  5;

          final double frameHeight =
              math.max(
            160,
            math.min(
              screenHeight *
                  0.46,
              availableHeight,
            ),
          );

          final Rect frameRect =
              Rect.fromLTWH(
            frameLeft,
            frameTop,
            frameWidth,
            frameHeight,
          );

          final Widget? statusBadge =
              _buildStatusBadge();

          return Stack(
            fit:
                StackFit.expand,
            children: [
              // =================================================
              // CAPTURED IMAGE
              // =================================================

              Image.file(
                File(
                  _currentImagePath,
                ),
                fit:
                    BoxFit.cover,
                errorBuilder: (
                  context,
                  error,
                  stackTrace,
                ) {
                  return const ColoredBox(
                    color:
                        Color(
                      0xFF17131D,
                    ),
                    child:
                        Center(
                      child:
                          Icon(
                        Icons.broken_image_outlined,
                        color:
                            Colors.white54,
                        size:
                            60,
                      ),
                    ),
                  );
                },
              ),

              // =================================================
              // DARK OVERLAY
              // =================================================

              Positioned.fill(
                child:
                    CustomPaint(
                  painter:
                      _PreviewOverlayPainter(
                    frameRect:
                        frameRect,
                  ),
                ),
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
                    150,
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
              // REVIEW FRAME
              // =================================================

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
                      _PreviewCornersPainter(
                    color:
                        _frameColor,
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
                          54,
                      child:
                          Row(
                        children: [
                          SizedBox(
                            width:
                                48,
                            height:
                                48,
                            child:
                                IconButton(
                              onPressed:
                                  _isAnalysing
                                      ? null
                                      : () {
                                          Navigator.pop(
                                            context,
                                          );
                                        },
                              padding:
                                  EdgeInsets.zero,
                              splashRadius:
                                  24,
                              icon:
                                  Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color:
                                    _isAnalysing
                                        ? Colors.white54
                                        : Colors.white,
                                size:
                                    28,
                              ),
                            ),
                          ),

                          const Expanded(
                            child:
                                Text(
                              'Review label',
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
                          ),

                          const SizedBox(
                            width:
                                48,
                            height:
                                48,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // =================================================
              // STATUS BADGE
              // =================================================

              if (statusBadge != null)
                Positioned(
                  top:
                      frameRect.bottom -
                          54,
                  left:
                      20,
                  right:
                      20,
                  child:
                      Center(
                    child:
                        statusBadge,
                  ),
                ),

              // =================================================
              // BOTTOM PANEL
              // =================================================

              Positioned(
                left:
                    0,
                right:
                    0,
                bottom:
                    0,
                height:
                    sheetHeight,
                child:
                    Container(
                  decoration:
                      const BoxDecoration(
                    color:
                        backgroundColor,
                    borderRadius:
                        BorderRadius.vertical(
                      top:
                          Radius.circular(
                        30,
                      ),
                    ),
                  ),
                  child:
                      SafeArea(
                    top:
                        false,
                    child:
                        Padding(
                      padding:
                          const EdgeInsets.fromLTRB(
                        22,
                        12,
                        22,
                        18,
                      ),
                      child:
                          Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Expanded(child: SingleChildScrollView(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                          // =====================================
                          // HANDLE
                          // =====================================

                          Center(
                            child:
                                Container(
                              width:
                                  48,
                              height:
                                  5,
                              decoration:
                                  BoxDecoration(
                                color:
                                    const Color(
                                  0xFFD6D1DC,
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

                          // =====================================
                          // TITLE
                          // =====================================

                          Text(
                            _isAnalysing
                                ? 'Reading nutrition values'
                                : _panelTitle,
                            style:
                                const TextStyle(
                              color:
                                  darkPurple,
                              fontSize:
                                  25,
                              fontWeight:
                                  FontWeight.w900,
                              height:
                                  1.05,
                            ),
                          ),

                          const SizedBox(
                            height:
                                9,
                          ),

                          // =====================================
                          // DESCRIPTION
                          // =====================================

                          Text(
                            _isAnalysing
                                ? 'NutriPal is extracting the serving information and nutrient values from this label.'
                                : _panelDescription,
                            style:
                                const TextStyle(
                              color:
                                  Color(
                                0xFF4F416D,
                              ),
                              fontSize:
                                  14.5,
                              height:
                                  1.35,
                              fontWeight:
                                  FontWeight.w500,
                            ),
                          ),

                          const SizedBox(
                            height:
                                14,
                          ),

                          // =====================================
                          // INFORMATION CARD
                          // =====================================

                          if (_online)
                            const Padding(padding: EdgeInsets.only(bottom: 12),
                              child: Text('Online table scan sends this label photo to Azure for text and table analysis.',
                                style: TextStyle(color: Color(0xFF67558E), fontSize: 13))),
                          if (_isAnalysing)
                            const _InformationCard(
                              icon:
                                  Icons.manage_search_rounded,
                              iconColor:
                                  primaryPurple,
                              backgroundColor:
                                  Color(
                                0xFFF3EDFF,
                              ),
                              text:
                                  'Reading serving size, nutrient names and their corresponding values.',
                            )
                          else
                            _buildInformationCard(),

                              ],
                            ),
                          )),
                          const SizedBox(height: 12),

                          // =====================================
                          // BUTTONS
                          // =====================================

                          _buildButtons(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// =======================================================
// STATUS BADGE
// =======================================================

class _StatusBadge extends StatelessWidget {
  final Color backgroundColor;

  final Color foregroundColor;

  final Widget leading;

  final String text;

  const _StatusBadge({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.leading,
    required this.text,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      constraints:
          const BoxConstraints(
        maxWidth:
            330,
      ),
      padding:
          const EdgeInsets.fromLTRB(
        10,
        7,
        17,
        7,
      ),
      decoration:
          BoxDecoration(
        color:
            backgroundColor,
        borderRadius:
            BorderRadius.circular(
          28,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black
                    .withValues(
              alpha:
                  0.12,
            ),
            blurRadius:
                8,
            offset:
                const Offset(
              0,
              3,
            ),
          ),
        ],
      ),
      child:
          Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          leading,

          const SizedBox(
            width:
                10,
          ),

          Flexible(
            child:
                Text(
              text,
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color:
                    foregroundColor,
                fontSize:
                    15,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =======================================================
// INFORMATION CARD
// =======================================================

class _InformationCard extends StatelessWidget {
  final IconData icon;

  final Color iconColor;

  final Color backgroundColor;

  final String text;

  const _InformationCard({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.text,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            16,
        vertical:
            14,
      ),
      decoration:
          BoxDecoration(
        color:
            backgroundColor,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
      ),
      child:
          Row(
        children: [
          Icon(
            icon,
            color:
                iconColor,
            size:
                32,
          ),

          const SizedBox(
            width:
                14,
          ),

          Expanded(
            child:
                Text(
              text,
              style:
                  const TextStyle(
                color:
                    _ScanPreviewColours.darkPurple,
                fontSize:
                    14,
                height:
                    1.3,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =======================================================
// PRIMARY BUTTON
// =======================================================

class _PrimaryButton extends StatelessWidget {
  final String text;

  final IconData icon;

  final VoidCallback? onPressed;

  const _PrimaryButton({
    required this.text,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return SizedBox(
      height:
          56,
      child:
          ElevatedButton(
        onPressed:
            onPressed,
        style:
            ElevatedButton.styleFrom(
          backgroundColor:
              _ScanPreviewColours.primaryPurple,
          foregroundColor:
              Colors.white,
          disabledBackgroundColor:
              const Color(
            0xFFD7CCE8,
          ),
          disabledForegroundColor:
              Colors.white,
          elevation:
              onPressed == null
                  ? 0
                  : 3,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              28,
            ),
          ),
        ),
        child:
            Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Flexible(
              child:
                  Text(
                text,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  fontSize:
                      16,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),

            const SizedBox(
              width:
                  7,
            ),

            Icon(
              icon,
              size:
                  22,
            ),
          ],
        ),
      ),
    );
  }
}

// =======================================================
// SECONDARY BUTTON
// =======================================================

class _SecondaryButton extends StatelessWidget {
  final String text;

  final VoidCallback? onPressed;

  const _SecondaryButton({
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return SizedBox(
      height:
          56,
      child:
          OutlinedButton(
        onPressed:
            onPressed,
        style:
            OutlinedButton.styleFrom(
          foregroundColor:
              _ScanPreviewColours.primaryPurple,
          disabledForegroundColor:
              const Color(
            0xFFAAA0B7,
          ),
          side:
              BorderSide(
            color:
                onPressed == null
                    ? const Color(
                        0xFFD8D0E0,
                      )
                    : _ScanPreviewColours.primaryPurple,
            width:
                1.7,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              28,
            ),
          ),
        ),
        child:
            Text(
          text,
          style:
              const TextStyle(
            fontSize:
                16,
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// =======================================================
// LOADING BUTTON
// =======================================================

class _LoadingButton extends StatelessWidget {
  const _LoadingButton();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      height:
          56,
      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFFD7CCE8,
        ),
        borderRadius:
            BorderRadius.circular(
          28,
        ),
      ),
      alignment:
          Alignment.center,
      child:
          const SizedBox(
        width:
            23,
        height:
            23,
        child:
            CircularProgressIndicator(
          strokeWidth:
              2.5,
          color:
              Colors.white,
        ),
      ),
    );
  }
}

// =======================================================
// COMMON COLOURS
// =======================================================

class _ScanPreviewColours {
  static const Color primaryPurple =
      Color(0xFF4B2E83);

  static const Color darkPurple =
      Color(0xFF25104F);
}

// =======================================================
// DARK AREA OUTSIDE FRAME
// =======================================================

class _PreviewOverlayPainter
    extends CustomPainter {
  final Rect frameRect;

  _PreviewOverlayPainter({
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
                0.24,
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
    covariant _PreviewOverlayPainter oldDelegate,
  ) {
    return oldDelegate.frameRect !=
        frameRect;
  }
}

// =======================================================
// FRAME CORNERS
// =======================================================

class _PreviewCornersPainter
    extends CustomPainter {
  final Color color;

  const _PreviewCornersPainter({
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
    covariant _PreviewCornersPainter oldDelegate,
  ) {
    return oldDelegate.color !=
        color;
  }
}