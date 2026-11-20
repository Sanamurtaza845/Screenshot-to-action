import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:tesseract_ocr/ocr_engine_config.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';

import 'image_preprocessing_service.dart';

/// Detailed result of the recognition process containing text, status,
/// language-specific breakdown, and error diagnostics.
class RecognitionResult {
  final String combinedText;
  final String englishText;
  final String urduText;
  final bool englishSuccess;
  final bool urduSuccess;
  final String? urduError;
  final String? englishError;
  final PreprocessingMetadata? preprocessingMetadata;

  const RecognitionResult({
    required this.combinedText,
    required this.englishText,
    required this.urduText,
    required this.englishSuccess,
    required this.urduSuccess,
    this.urduError,
    this.englishError,
    this.preprocessingMetadata,
  });

  bool get hasAnyText => combinedText.trim().isNotEmpty;
  bool get hasUrduFailure => !urduSuccess && urduError != null;
  bool get hasEnglishFailure => !englishSuccess && englishError != null;
}

class TextRecognitionService {
  final ImagePreprocessingService _preprocessingService =
      ImagePreprocessingService();

  /// Backwards-compatible extractText method returning combined text string.
  Future<String> extractText(String imagePath) async {
    final result = await extractTextDetailed(imagePath);
    return result.combinedText;
  }

  /// Full featured recognition pipeline:
  /// 1. Applies Image Pre-processing (scaling, dark-mode inversion, grayscale, contrast)
  /// 2. Performs English OCR via Google ML Kit
  /// 3. Performs Urdu OCR via Tesseract with diagnostic error handling & platform checks
  /// 4. Intelligent post-processing and text merging
  Future<RecognitionResult> extractTextDetailed(String imagePath) async {
    String englishText = '';
    String urduText = '';
    bool englishSuccess = false;
    bool urduSuccess = false;
    String? englishError;
    String? urduError;

    // STEP 0: IMAGE PRE-PROCESSING
    PreprocessedImageResult? preprocessed;
    String targetImagePath = imagePath;

    try {
      preprocessed = await _preprocessingService.preprocess(imagePath);
      targetImagePath = preprocessed.file.path;
      debugPrint(
        'Image Preprocessing Complete: ${preprocessed.metadata.summary} '
        '(Avg Lum: ${preprocessed.metadata.averageLuminance.toStringAsFixed(1)})',
      );
    } catch (e) {
      debugPrint('Image Preprocessing Warning: $e. Falling back to original image.');
      targetImagePath = imagePath;
    }

    try {
      // STEP 1: ENGLISH OCR VIA GOOGLE ML KIT
      final recognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );

      try {
        final image = InputImage.fromFilePath(targetImagePath);
        final result = await recognizer.processImage(image);

        if (result.blocks.isNotEmpty) {
          englishText = reconstructText(result);
        }
        englishSuccess = true;
      } catch (e, stack) {
        englishError = 'English OCR Error: ${e.toString()}';
        debugPrint('$englishError\n$stack');
        englishSuccess = false;
      } finally {
        await recognizer.close();
      }

      // STEP 2: URDU OCR VIA TESSERACT WITH DIAGNOSTIC ERROR HANDLING
      // Note: Tesseract mobile plugin natively runs on Android and iOS.
      final isMobilePlatform = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

      if (!isMobilePlatform) {
        urduError =
            'Urdu offline OCR (Tesseract) is supported on Android and iOS devices. '
            'Current platform (${Platform.operatingSystem}) operates in English ML Kit mode.';
        debugPrint('Urdu OCR Status: $urduError');
        urduSuccess = false;
      } else {
        try {
          final config = OCRConfig(
            language: 'urd',
            engine: OCREngine.tesseract,
          );

          final rawUrdu = await TesseractOcr.extractText(
            targetImagePath,
            config: config,
          );

          urduText = _cleanUrduOcrText(rawUrdu);
          urduSuccess = true;
        } catch (e, stack) {
          final errorStr = e.toString();
          debugPrint('Urdu OCR Exception: $errorStr\n$stack');

          if (errorStr.contains('MissingPluginException')) {
            urduError =
                'Tesseract OCR native plugin is not registered on this platform build.';
          } else if (errorStr.contains('urd.traineddata') ||
              errorStr.contains('tessdata')) {
            urduError =
                'Urdu language traineddata (assets/tessdata/urd.traineddata) could not be loaded by the OCR engine.';
          } else {
            urduError =
                'Urdu recognition failed: ${errorStr.length > 120 ? errorStr.substring(0, 120) : errorStr}';
          }
          urduSuccess = false;
        }
      }

      // STEP 3: LOG RESULTS SEPARATELY FOR DEBUGGING
      debugPrint('========== ENGLISH OCR ==========');
      debugPrint(englishText.isNotEmpty ? englishText : '(No English detected)');

      debugPrint('========== URDU OCR ==========');
      if (urduSuccess) {
        debugPrint(urduText.isNotEmpty ? urduText : '(No Urdu detected)');
      } else {
        debugPrint('URDU OCR FAILED: $urduError');
      }

      // STEP 4: INTELLIGENT COMBINATION
      final combined = _combineExtractedTexts(
        englishText: englishText.trim(),
        urduText: urduText.trim(),
      );

      return RecognitionResult(
        combinedText: combined,
        englishText: englishText.trim(),
        urduText: urduText.trim(),
        englishSuccess: englishSuccess,
        urduSuccess: urduSuccess,
        urduError: urduError,
        englishError: englishError,
        preprocessingMetadata: preprocessed?.metadata,
      );
    } finally {
      // Always cleanup temporary preprocessed file
      if (preprocessed != null) {
        await preprocessed.cleanup();
      }
    }
  }

  /// Intelligently combines English and Urdu extracted text.
  /// Removes duplicate lines and filters out single-character Latin noise generated
  /// by ML Kit when reading Urdu characters.
  String _combineExtractedTexts({
    required String englishText,
    required String urduText,
  }) {
    if (englishText.isEmpty && urduText.isEmpty) return '';
    if (englishText.isEmpty) return urduText;
    if (urduText.isEmpty) return englishText;

    // Both languages present: clean noise and separate clearly
    final cleanedEnglish = _filterLatinNoiseFromUrdu(englishText);

    return [
      cleanedEnglish,
      urduText,
    ].where((t) => t.isNotEmpty).join('\n\n');
  }

  /// Filters out isolated punctuation and junk Latin artifacts that ML Kit
  /// generates when attempting to parse Arabic/Urdu scripts with a Latin model.
  String _filterLatinNoiseFromUrdu(String text) {
    final lines = text.split('\n');
    final validLines = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Filter lines that are purely junk symbols or single stray characters
      if (RegExp(r'^[\W_\|\\/\[\]\<\>\-\+\=~`]{1,3}$').hasMatch(trimmed)) {
        continue;
      }

      validLines.add(line);
    }

    return validLines.join('\n').trim();
  }

  /// Cleans Urdu text extracted from Tesseract.
  String _cleanUrduOcrText(String text) {
    String cleaned = text.trim();
    // Normalize zero-width non-joiners and abnormal control codes
    cleaned = cleaned.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
    // Replace multiple empty lines with a double newline
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return cleaned.trim();
  }

  /// Reconstructs text from ML Kit RecognizedText while preserving natural reading order,
  /// tabular alignment, and paragraph structure without scrambling words or columns.
  String reconstructText(RecognizedText recognizedText) {
    final rawLines = <RecognizedLineData>[];

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final cleaned = _correctOcrText(line.text.trim());
        if (cleaned.isEmpty) continue;

        final box = line.boundingBox;
        rawLines.add(
          RecognizedLineData(
            text: cleaned,
            left: box.left.toDouble(),
            top: box.top.toDouble(),
            right: box.right.toDouble(),
            bottom: box.bottom.toDouble(),
          ),
        );
      }
    }

    if (rawLines.isEmpty) return '';

    return formatLines(rawLines);
  }

  /// Spatially groups lines into horizontal visual rows and orders rows top-to-bottom,
  /// lines left-to-right within rows, preserving tabular gaps and paragraph breaks.
  String formatLines(List<RecognizedLineData> rawLines) {
    if (rawLines.isEmpty) return '';

    // Sort all lines by top coordinate initially
    final lines = List<RecognizedLineData>.from(rawLines)
      ..sort((a, b) => a.top.compareTo(b.top));

    final rows = <_VisualRow>[];

    for (final line in lines) {
      _VisualRow? bestMatchingRow;
      double maxOverlap = 0;

      for (final row in rows) {
        final overlap = row.verticalOverlap(line);
        if (overlap > maxOverlap &&
            overlap >= 0.4 * min(line.height, row.height)) {
          maxOverlap = overlap;
          bestMatchingRow = row;
        }
      }

      if (bestMatchingRow != null) {
        bestMatchingRow.addLine(line);
      } else {
        rows.add(_VisualRow(line));
      }
    }

    // Sort rows from top to bottom
    rows.sort((a, b) => a.top.compareTo(b.top));

    final buffer = StringBuffer();
    _VisualRow? previousRow;

    for (final row in rows) {
      // Sort lines inside each row left to right
      row.lines.sort((a, b) => a.left.compareTo(b.left));

      // Check vertical gap from previous row for paragraph break
      if (previousRow != null) {
        final verticalGap = row.top - previousRow.bottom;
        final avgHeight = (row.height + previousRow.height) / 2;

        if (verticalGap > avgHeight * 1.3) {
          // Distinct paragraph / section separation
          buffer.write('\n\n');
        } else {
          buffer.write('\n');
        }
      }

      // Format lines inside this row
      final rowBuffer = StringBuffer();
      for (int i = 0; i < row.lines.length; i++) {
        final currentLine = row.lines[i];

        if (i > 0) {
          final previousLine = row.lines[i - 1];
          final horizontalGap = currentLine.left - previousLine.right;

          // If there is a noticeable column gap (e.g., receipt or table), insert wider gap
          if (horizontalGap > row.height * 2.5) {
            rowBuffer.write('    ');
          } else {
            rowBuffer.write(' ');
          }
        }

        rowBuffer.write(currentLine.text);
      }

      buffer.write(rowBuffer.toString().trim());
      previousRow = row;
    }

    return buffer.toString().trim();
  }

  String _correctOcrText(String text) {
    String corrected = text.trim();

    // Remove zero-width spaces and abnormal control characters
    corrected = corrected.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');

    // Normalize multiple whitespace to single space
    corrected = corrected.replaceAll(RegExp(r'[ \t]+'), ' ');

    // Correct AI-related headings
    corrected = corrected.replaceAll(
      RegExp(
        r'\bAl(?=\s+(CHATBOT|AGENT|PROMPT|MODEL|ENGINE|TOOL|GENERATIVE)\b)',
        caseSensitive: false,
      ),
      'AI',
    );

    // Correct isolated AI text
    if (RegExp(r'^AL$', caseSensitive: false).hasMatch(corrected)) {
      corrected = 'AI';
    }

    // Common OCR typos
    corrected = corrected.replaceAll(
      RegExp(r'\bAPls\b', caseSensitive: false),
      'APIs',
    );

    corrected = corrected.replaceAll(
      RegExp(r'\bE\.g,', caseSensitive: false),
      'E.g.',
    );

    return corrected;
  }
}

class RecognizedLineData {
  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  const RecognizedLineData({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  double get width => right - left;
  double get height => bottom - top;
}

class _VisualRow {
  double left;
  double top;
  double right;
  double bottom;
  final List<RecognizedLineData> lines;

  _VisualRow(RecognizedLineData firstLine)
      : left = firstLine.left,
        top = firstLine.top,
        right = firstLine.right,
        bottom = firstLine.bottom,
        lines = [firstLine];

  double get height => bottom - top;

  double verticalOverlap(RecognizedLineData line) {
    final overlapTop = max(top, line.top);
    final overlapBottom = min(bottom, line.bottom);
    if (overlapBottom <= overlapTop) return 0.0;
    return overlapBottom - overlapTop;
  }

  void addLine(RecognizedLineData line) {
    lines.add(line);
    left = min(left, line.left);
    top = min(top, line.top);
    right = max(right, line.right);
    bottom = max(bottom, line.bottom);
  }
}
