import 'dart:math';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'image_preprocessing_service.dart';

enum RecognitionEngineType {
  offlineMLKit, // 100% On-device offline Google ML Kit
}

/// Detailed result of the recognition process containing text, status,
/// diagnostics, and engine metadata.
class RecognitionResult {
  final String combinedText;
  final String englishText;
  final String urduText;
  final bool englishSuccess;
  final bool urduSuccess;
  final String? urduError;
  final String? englishError;
  final PreprocessingMetadata? preprocessingMetadata;
  final RecognitionEngineType engineType;
  final String? engineNotice;

  const RecognitionResult({
    required this.combinedText,
    required this.englishText,
    this.urduText = '',
    required this.englishSuccess,
    this.urduSuccess = false,
    this.urduError,
    this.englishError,
    this.preprocessingMetadata,
    this.engineType = RecognitionEngineType.offlineMLKit,
    this.engineNotice,
  });

  bool get hasAnyText => combinedText.trim().isNotEmpty;
  bool get hasUrduFailure => false;
  bool get hasEnglishFailure => !englishSuccess && englishError != null;
  bool get isGeminiVision => false;
}

class TextRecognitionService {
  final ImagePreprocessingService _preprocessingService =
      ImagePreprocessingService();

  /// Backwards-compatible extractText method returning combined text string.
  Future<String> extractText(String imagePath) async {
    final result = await extractTextDetailed(imagePath);
    return result.combinedText;
  }

  /// High-accuracy 100% offline text extraction pipeline using:
  /// 1. Dynamic Contrast & Sharpness Image Preprocessing
  /// 2. Google ML Kit Latin Text Recognition Engine
  /// 3. Visual Row & Column Layout Reconstruction
  Future<RecognitionResult> extractTextDetailed(String imagePath) async {
    PreprocessedImageResult? preprocessed;
    String targetImagePath = imagePath;
    String englishText = '';
    bool englishSuccess = false;
    String? englishError;

    try {
      // 1. IMAGE PREPROCESSING FOR MAXIMUM OCR ACCURACY
      try {
        preprocessed = await _preprocessingService.preprocess(imagePath);
        targetImagePath = preprocessed.file.path;
      } catch (e) {
        targetImagePath = imagePath;
      }

      // 2. GOOGLE ML KIT TEXT RECOGNITION (100% OFFLINE)
      final recognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );

      try {
        final inputImage = InputImage.fromFilePath(targetImagePath);
        final recognizedText = await recognizer.processImage(inputImage);

        if (recognizedText.blocks.isNotEmpty) {
          englishText = reconstructText(recognizedText);
        }
        englishSuccess = englishText.trim().isNotEmpty;
      } catch (e) {
        englishError = 'Text recognition error: $e';
        englishSuccess = false;
      } finally {
        await recognizer.close();
      }

      // 3. CLEAN & NORMALIZE TEXT
      final cleanedText = _cleanExtractedEnglishText(englishText);

      return RecognitionResult(
        combinedText: cleanedText,
        englishText: cleanedText,
        urduText: '',
        englishSuccess: cleanedText.isNotEmpty,
        urduSuccess: false,
        englishError: englishError,
        preprocessingMetadata: preprocessed?.metadata,
        engineType: RecognitionEngineType.offlineMLKit,
        engineNotice: 'Extracted with On-Device AI Engine (100% Offline)',
      );
    } finally {
      if (preprocessed != null) {
        await preprocessed.cleanup();
      }
    }
  }

  /// Filters out stray non-English symbols or noise from non-Latin scripts
  String _cleanExtractedEnglishText(String text) {
    if (text.trim().isEmpty) return '';

    final lines = text.split('\n');
    final validLines = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Skip lines that are just symbols/brackets
      if (RegExp(r'^[\W_\|\\/\[\]\<\>\-\+\=~`]{1,4}$').hasMatch(trimmed)) {
        continue;
      }

      // Skip non-Latin noise hallucination
      if (_isNonLatinNoise(trimmed)) {
        continue;
      }

      validLines.add(line);
    }

    return validLines.join('\n').trim();
  }

  bool _isNonLatinNoise(String line) {
    // Foreign/accented characters uncommon in English but characteristic of reading non-Latin scripts
    final accentedMatches =
        RegExp(r'[õüöèòüïëãñîôûàáìíùúýÿ]').allMatches(line).length;
    if (accentedMatches >= 1) return true;

    final words = line.split(RegExp(r'\s+'));
    if (words.length >= 3) {
      int vowellessCount = 0;
      int singleLetterCount = 0;

      for (final w in words) {
        final lettersOnly = w.replaceAll(RegExp(r'[^a-zA-Z]'), '');
        if (lettersOnly.isEmpty) continue;

        if (lettersOnly.length == 1 &&
            lettersOnly != 'a' &&
            lettersOnly != 'A' &&
            lettersOnly != 'I') {
          singleLetterCount++;
        }

        if (lettersOnly.length >= 3 &&
            !RegExp(r'[aeiouyAEIOUY]').hasMatch(lettersOnly)) {
          vowellessCount++;
        }
      }

      if (vowellessCount >= 1 && singleLetterCount >= 2) return true;
      if (singleLetterCount >= 3) return true;
      if (vowellessCount >= 2) return true;
    }

    return false;
  }

  /// Reconstructs the exact visual reading layout from RecognizedText blocks
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

  /// Formats lines into visual rows and preserves paragraphs and horizontal order
  String formatLines(List<RecognizedLineData> rawLines) {
    if (rawLines.isEmpty) return '';

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

    rows.sort((a, b) => a.top.compareTo(b.top));

    final buffer = StringBuffer();
    _VisualRow? previousRow;

    for (final row in rows) {
      row.lines.sort((a, b) => a.left.compareTo(b.left));

      if (previousRow != null) {
        final verticalGap = row.top - previousRow.bottom;
        final avgHeight = (row.height + previousRow.height) / 2;

        if (verticalGap > avgHeight * 1.3) {
          buffer.write('\n\n');
        } else {
          buffer.write('\n');
        }
      }

      final rowBuffer = StringBuffer();
      for (int i = 0; i < row.lines.length; i++) {
        final currentLine = row.lines[i];

        if (i > 0) {
          final previousLine = row.lines[i - 1];
          final horizontalGap = currentLine.left - previousLine.right;

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
    corrected = corrected.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
    corrected = corrected.replaceAll(RegExp(r'[ \t]+'), ' ');

    corrected = corrected.replaceAll(
      RegExp(
        r'\bAl(?=\s+(CHATBOT|AGENT|PROMPT|MODEL|ENGINE|TOOL|GENERATIVE)\b)',
        caseSensitive: false,
      ),
      'AI',
    );

    if (RegExp(r'^AL$', caseSensitive: false).hasMatch(corrected)) {
      corrected = 'AI';
    }

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
