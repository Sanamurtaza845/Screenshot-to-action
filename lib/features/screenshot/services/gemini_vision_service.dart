import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';

class GeminiOcrResult {
  final bool isSuccess;
  final String text;
  final String englishText;
  final String urduText;
  final bool hasUrdu;
  final bool hasEnglish;
  final String? errorMessage;
  final bool fallbackToOffline;
  final String modelUsed;

  const GeminiOcrResult({
    required this.isSuccess,
    this.text = '',
    this.englishText = '',
    this.urduText = '',
    this.hasUrdu = false,
    this.hasEnglish = false,
    this.errorMessage,
    this.fallbackToOffline = false,
    this.modelUsed = '',
  });

  factory GeminiOcrResult.success({
    required String text,
    required String englishText,
    required String urduText,
    required bool hasUrdu,
    required bool hasEnglish,
    required String model,
  }) {
    return GeminiOcrResult(
      isSuccess: true,
      text: text,
      englishText: englishText,
      urduText: urduText,
      hasUrdu: hasUrdu,
      hasEnglish: hasEnglish,
      modelUsed: model,
    );
  }

  factory GeminiOcrResult.failure({
    required String errorMessage,
    bool fallbackToOffline = true,
  }) {
    return GeminiOcrResult(
      isSuccess: false,
      errorMessage: errorMessage,
      fallbackToOffline: fallbackToOffline,
    );
  }
}

class GeminiVisionService {
  final http.Client _client = http.Client();

  /// Checks whether internet access is currently reachable with a fast timeout.
  Future<bool> hasInternetConnection() async {
    try {
      final lookupResult = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return lookupResult.isNotEmpty && lookupResult[0].rawAddress.isNotEmpty;
    } catch (_) {
      try {
        final backupResult = await InternetAddress.lookup('1.1.1.1')
            .timeout(const Duration(seconds: 3));
        return backupResult.isNotEmpty;
      } catch (_) {
        return false;
      }
    }
  }

  /// Extracts English and Urdu (Nastaliq) text with 100% accuracy using Gemini Vision API.
  Future<GeminiOcrResult> extractBilingualText(String imagePath) async {
    final apiKey = await ApiConfig.getApiKey();

    if (!ApiConfig.isValidKey(apiKey)) {
      return GeminiOcrResult.failure(
        errorMessage: 'Gemini API key is not configured or invalid.',
        fallbackToOffline: true,
      );
    }

    final isOnline = await hasInternetConnection();
    if (!isOnline) {
      return GeminiOcrResult.failure(
        errorMessage: 'Internet connection is unavailable. '
            'Falling back to offline on-device engine.',
        fallbackToOffline: true,
      );
    }

    final imageFile = File(imagePath);
    if (!await imageFile.exists()) {
      return GeminiOcrResult.failure(
        errorMessage: 'Image file not found: $imagePath',
        fallbackToOffline: false,
      );
    }

    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);
    final mimeType = _getMimeType(imagePath);

    const prompt = '''
You are an expert bilingual OCR and document transcription engine specializing in English and Urdu (Nastaliq & Naskh scripts).
Extract ALL text from this screenshot with 100% accuracy.

Strict Extraction Instructions:
1. Exact Verbatim Transcription: Transcribe every single word, character, symbol, and digit exactly as written in the screenshot.
2. Urdu (Nastaliq) Fidelity: Accurately capture all Urdu characters, ligatures, diacritics, and dots (nuqtas). Never miss or confuse similar Urdu letters (e.g., ژ/ز/ڑ/ر, ڈ/د, ٹ/ت/ث, ں/ن, ے/ی, ہ/ح/ھ).
3. Mixed Scripts: Handle mixed Urdu and English seamlessly. Preserve Left-to-Right for English segments and Right-to-Left for Urdu segments.
4. Zero Translation: Do NOT translate Urdu to English or English to Urdu. Keep the original text in its original script.
5. Layout & Order: Preserve paragraph breaks, lines, bullet points, headers, and visual layout without scrambling words.
6. Numbers & Codes: Transcribe numbers, phone numbers, addresses, and codes exactly as shown (whether Eastern Arabic/Urdu numerals '۰۱۲۳۴۵۶۷۸۹' or Western '0123456789').
7. Negative Constraints (Strict Zero Hallucination):
   - If the image contains ONLY English and NO Urdu, output ONLY English. NEVER output or hallucinate any Urdu characters, Urdu words, or Urdu translations.
   - If the image contains NO phone numbers or NO numbers, do NOT invent or hallucinate any numbers.
   - Transcribe ONLY what is visually and physically present in the screenshot. Never assume or add synthetic text.
8. Output Format: Return the pure, complete extracted text directly without conversational commentary, preambles, or markdown code fences like ```text or ```.
''';

    final modelsToTry = [
      ApiConfig.geminiModel,
      ApiConfig.geminiFallbackModel,
      'gemini-flash-latest',
    ];

    for (final model in modelsToTry) {
      try {
        final rawText = await _callGeminiApi(
          model: model,
          apiKey: apiKey,
          prompt: prompt,
          base64Image: base64Image,
          mimeType: mimeType,
        );

        if (rawText != null && rawText.trim().isNotEmpty) {
          final cleaned = _cleanResponseText(rawText);
          final parsed = _separateLanguages(cleaned);

          return GeminiOcrResult.success(
            text: cleaned,
            englishText: parsed.englishText,
            urduText: parsed.urduText,
            hasUrdu: parsed.hasUrdu,
            hasEnglish: parsed.hasEnglish,
            model: model,
          );
        }
      } catch (e) {
        debugPrint('Gemini model ($model) error: $e');
      }
    }

    return GeminiOcrResult.failure(
      errorMessage: 'Gemini Vision API request failed or timed out. '
          'Using offline on-device engine as fallback.',
      fallbackToOffline: true,
    );
  }

  Future<String?> _callGeminiApi({
    required String model,
    required String apiKey,
    required String prompt,
    required String base64Image,
    required String mimeType,
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );

    final payload = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Image,
              }
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.0,
        'topK': 1,
        'topP': 0.1,
      }
    });

    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: payload,
        )
        .timeout(
          const Duration(seconds: ApiConfig.requestTimeoutSeconds),
        );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = json['candidates'] as List<dynamic>?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates[0]['content'] as Map<String, dynamic>?;
        final parts = content?['parts'] as List<dynamic>?;
        if (parts != null && parts.isNotEmpty) {
          final text = parts[0]['text'] as String?;
          return text;
        }
      }
    } else {
      debugPrint('Gemini API status ${response.statusCode}: ${response.body}');
    }

    return null;
  }

  String _cleanResponseText(String text) {
    String cleaned = text.trim();
    if (cleaned.startsWith('```') && cleaned.endsWith('```')) {
      final lines = cleaned.split('\n');
      if (lines.length >= 2) {
        lines.removeAt(0);
        if (lines.isNotEmpty && lines.last.trim() == '```') {
          lines.removeLast();
        }
        cleaned = lines.join('\n').trim();
      }
    }
    // Normalize Unicode for Urdu (convert Arabic Kaf/Yeh to standard Urdu Kaf/Yeh)
    cleaned = cleaned.replaceAll('ك', 'ک').replaceAll('ي', 'ی');
    return cleaned;
  }

  /// Separates extracted text into English and Urdu segments for convenient copying
  _LanguageSeparationResult _separateLanguages(String text) {
    final urduRegex =
        RegExp(r'[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]');
    final englishRegex = RegExp(r'[a-zA-Z]');

    final lines = text.split('\n');
    final englishLines = <String>[];
    final urduLines = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final hasUrdu = urduRegex.hasMatch(trimmed);
      final hasEnglish = englishRegex.hasMatch(trimmed);

      if (hasUrdu && !hasEnglish) {
        urduLines.add(line);
      } else if (hasEnglish && !hasUrdu) {
        englishLines.add(line);
      } else if (hasUrdu && hasEnglish) {
        urduLines.add(line);
        englishLines.add(line);
      } else {
        // Line has neither (e.g., pure numbers, dates, punctuation, symbols)
        // Add only to English lines, NEVER to Urdu lines unless Urdu characters exist
        englishLines.add(line);
      }
    }

    // A document genuinely has Urdu only if there are meaningful Urdu words
    final hasUrduChar = urduRegex.hasMatch(text);
    final hasUrdu = hasUrduChar &&
        urduLines.any((l) => RegExp(r'[\u0600-\u06FF]{2,}').hasMatch(l));
    final hasEnglish = englishRegex.hasMatch(text);

    return _LanguageSeparationResult(
      englishText: englishLines.join('\n').trim(),
      urduText: hasUrdu ? urduLines.join('\n').trim() : '',
      hasUrdu: hasUrdu,
      hasEnglish: hasEnglish,
    );
  }

  String _getMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}

class _LanguageSeparationResult {
  final String englishText;
  final String urduText;
  final bool hasUrdu;
  final bool hasEnglish;

  const _LanguageSeparationResult({
    required this.englishText,
    required this.urduText,
    required this.hasUrdu,
    required this.hasEnglish,
  });
}
