import 'dart:math';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class TextRecognitionService {
  Future<String> extractText(String imagePath) async {
    final recognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );

    try {
      final image = InputImage.fromFilePath(imagePath);
      final result = await recognizer.processImage(image);

      if (result.blocks.isEmpty) return '';

      final List<_TextLine> lines = [];

      for (final block in result.blocks) {
        for (final line in block.lines) {
          final text = _correctOcrText(line.text.trim());

          if (text.isEmpty) continue;

          final box = line.boundingBox;

          lines.add(
            _TextLine(
              text: text,
              left: box.left.toDouble(),
              top: box.top.toDouble(),
              right: box.right.toDouble(),
              bottom: box.bottom.toDouble(),
            ),
          );
        }
      }

      if (lines.isEmpty) return '';

      final imageWidth = lines
          .map((line) => line.right)
          .reduce(max);

      final imageHeight = lines
          .map((line) => line.bottom)
          .reduce(max);

      final averageHeight = lines
              .map((line) => line.height)
              .reduce((a, b) => a + b) /
          lines.length;

      // Separate full-width text from column content.
      final spanningLines = <_TextLine>[];
      final contentLines = <_TextLine>[];

      for (final line in lines) {
        if (line.width >= imageWidth * 0.72) {
          spanningLines.add(line);
        } else {
          contentLines.add(line);
        }
      }

      spanningLines.sort((a, b) => a.top.compareTo(b.top));

      final output = <String>[];

      double currentTop = 0;

      for (final spanning in spanningLines) {
        final region = contentLines.where((line) {
          return line.top >= currentTop &&
              line.bottom <= spanning.top;
        }).toList();

        if (region.isNotEmpty) {
          output.addAll(
            _readRegion(region, averageHeight),
          );
        }

        output.add(spanning.text);

        currentTop = spanning.bottom;
      }

      final remaining = contentLines.where((line) {
        return line.top >= currentTop;
      }).toList();

      if (remaining.isNotEmpty) {
        output.addAll(
          _readRegion(remaining, averageHeight),
        );
      }

      return output
          .where((text) => text.trim().isNotEmpty)
          .join('\n')
          .trim();
    } finally {
      await recognizer.close();
    }
  }

  List<String> _readRegion(
    List<_TextLine> lines,
    double averageHeight,
  ) {
    if (lines.isEmpty) return [];

    final split = _findColumnSplit(lines, averageHeight);

    // No reliable column boundary: read normally.
    if (split == null) {
      final sorted = [...lines]
        ..sort((a, b) {
          final difference = a.top - b.top;

          if (difference.abs() < averageHeight * 0.7) {
            return a.left.compareTo(b.left);
          }

          return difference.compareTo(0);
        });

      return sorted.map((line) => line.text).toList();
    }

    final leftColumn = lines
        .where((line) => line.right <= split)
        .toList();

    final rightColumn = lines
        .where((line) => line.left >= split)
        .toList();

    final spanning = lines
        .where((line) =>
            line.left < split && line.right > split)
        .toList();

   if (leftColumn.length < 2 || rightColumn.length < 2) {
  final sortedLines = [...lines];

  sortedLines.sort(
    (a, b) => a.top.compareTo(b.top),
  );

  return sortedLines
      .map((line) => line.text)
      .toList();
}

    leftColumn.sort((a, b) => a.top.compareTo(b.top));
    rightColumn.sort((a, b) => a.top.compareTo(b.top));
    spanning.sort((a, b) => a.top.compareTo(b.top));

    // Read the left column completely, then the right column.
    final result = <String>[
      ...leftColumn.map((line) => line.text),
      ...rightColumn.map((line) => line.text),
    ];

    // Keep any crossing lines rather than losing their text.
    result.addAll(spanning.map((line) => line.text));

    return result;
  }

  double? _findColumnSplit(
    List<_TextLine> lines,
    double averageHeight,
  ) {
    final edges = <double>[];

    for (final line in lines) {
      edges
        ..add(line.left)
        ..add(line.right);
    }

    edges.sort();

    double? bestSplit;
    double bestScore = 0;

    for (int i = 0; i < edges.length - 1; i++) {
      final gap = edges[i + 1] - edges[i];

      if (gap < averageHeight * 1.5) continue;

      final split = (edges[i] + edges[i + 1]) / 2;

      final leftCount = lines.where(
        (line) => line.right <= split,
      ).length;

      final rightCount = lines.where(
        (line) => line.left >= split,
      ).length;

      final crossingCount = lines.length - leftCount - rightCount;

      if (leftCount < 2 || rightCount < 2) continue;

      // Prefer balanced columns and large whitespace gaps.
      final balance = min(leftCount, rightCount) /
          max(leftCount, rightCount);

      final crossingPenalty =
          crossingCount / lines.length;

      final score = gap *
          balance *
          (1 - crossingPenalty);

      if (score > bestScore) {
        bestScore = score;
        bestSplit = split;
      }
    }

    return bestSplit;
  }
 String _correctOcrText(String text) {
  String corrected = text.trim();

  // Correct AI-related headings.
  corrected = corrected.replaceAll(
    RegExp(r'\bAl(?=\s+(CHATBOT|AGENT)\b)', caseSensitive: false),
    'AI',
  );

  // Correct isolated AI text.
  if (RegExp(r'^AL$', caseSensitive: false).hasMatch(corrected)) {
    corrected = 'AI';
  }

  // Correct common OCR mistakes.
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

class _TextLine {
  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  const _TextLine({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  double get width => right - left;

  double get height => bottom - top;
}