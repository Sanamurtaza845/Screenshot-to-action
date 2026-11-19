import 'dart:math';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';
import 'package:tesseract_ocr/ocr_engine_config.dart';
import 'package:flutter/foundation.dart';

class TextRecognitionService {
 Future<String> extractText(String imagePath) async {
  String englishText = '';
  String urduText = '';

  // STEP 1: English recognition using existing ML Kit.
  final recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  try {
    final image = InputImage.fromFilePath(imagePath);
    final result = await recognizer.processImage(image);

    if (result.blocks.isNotEmpty) {
      englishText = reconstructText(result);
    }
  } finally {
    await recognizer.close();
  }

  // STEP 2: Urdu recognition using Tesseract only.
  try {
    final config = OCRConfig(
      language: 'urd',
      engine: OCREngine.tesseract,
    );

    urduText = await TesseractOcr.extractText(
      imagePath,
      config: config,
    );

  } catch (e) {
    debugPrint('Urdu OCR Error: $e');
  }

  // STEP 3: Print both results separately.
  debugPrint('========== ENGLISH OCR ==========');
  debugPrint(englishText);

  debugPrint('========== URDU OCR ==========');
  debugPrint(urduText);

  return [
    englishText.trim(),
    urduText.trim(),
  ].where((text) => text.isNotEmpty).join('\n');
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
      RegExp(r'\bAl(?=\s+(CHATBOT|AGENT|PROMPT|MODEL|ENGINE|TOOL|GENERATIVE)\b)', caseSensitive: false),
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
