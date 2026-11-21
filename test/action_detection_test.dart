import 'package:flutter_test/flutter_test.dart';
import 'package:screenshot_to_action/core/config/api_config.dart';
import 'package:screenshot_to_action/features/screenshot/services/action_detection_service.dart';
import 'package:screenshot_to_action/features/screenshot/services/image_preprocessing_service.dart';
import 'package:screenshot_to_action/features/screenshot/services/text_recognition_service.dart';

void main() {
  final detector = ActionDetectionService();
  final textService = TextRecognitionService();

  group('TextRecognitionService Formatting Tests', () {
    test('Preserves horizontal reading order and never scrambles words on same line', () {
      final lines = [
        const RecognizedLineData(
          text: 'Cheezious Pizza',
          left: 30,
          top: 100,
          right: 200,
          bottom: 125,
        ),
        const RecognizedLineData(
          text: 'Rs. 1,450',
          left: 450,
          top: 102,
          right: 550,
          bottom: 124,
        ),
        const RecognizedLineData(
          text: 'Garlic Bread',
          left: 30,
          top: 135,
          right: 180,
          bottom: 158,
        ),
        const RecognizedLineData(
          text: 'Rs. 350',
          left: 450,
          top: 136,
          right: 530,
          bottom: 157,
        ),
        const RecognizedLineData(
          text: 'House # 12, Street 4, Sector F-7, Islamabad',
          left: 30,
          top: 210,
          right: 480,
          bottom: 235,
        ),
      ];

      final output = textService.formatLines(lines);

      expect(output.contains('Cheezious Pizza'), isTrue);
      expect(
        output.indexOf('Cheezious Pizza'),
        lessThan(output.indexOf('Rs. 1,450')),
      );

      expect(
        output.indexOf('Rs. 1,450'),
        lessThan(output.indexOf('Garlic Bread')),
      );

      expect(
        output.indexOf('Garlic Bread'),
        lessThan(output.indexOf('Rs. 350')),
      );

      expect(
        output.indexOf('Rs. 350'),
        lessThan(output.indexOf('House # 12')),
      );
    });

    test('Preserves OCR text formatting', () {
      final lines = [
        const RecognizedLineData(
          text: 'Al CHATBOT',
          left: 10,
          top: 10,
          right: 100,
          bottom: 30,
        ),
      ];

      expect(
        textService.formatLines(lines),
        contains('Al CHATBOT'),
      );
    });
  });

  group('ActionDetectionService Tests', () {
    // -----------------------------------------------------------
    // PHONE NUMBER TESTS
    // -----------------------------------------------------------

    test('Detects Pakistani and international phone numbers', () {
      const text = '''
Call us at 0300-1234567 or +92 321 7654321
Landline: 051-1234567, UAN: 111-243-324
International: +1 (555) 234-5678
''';

      final phones = detector.detectPhoneNumbers(text);

      expect(phones.length, greaterThanOrEqualTo(3));
      expect(phones.any((p) => p.contains('0300')), isTrue);
      expect(phones.any((p) => p.contains('+92')), isTrue);
      expect(phones.any((p) => p.contains('111')), isTrue);
    });

    // -----------------------------------------------------------
    // WEBSITE TESTS
    // -----------------------------------------------------------

    test('Detects websites and cleans trailing punctuation', () {
      const text = '''
Check our site: https://www.kfc.com.pk.
Also visit www.daraz.pk!
Follow us on instagram.com/outfitterspk
Contact: info@example.com
''';

      final websites = detector.detectWebsiteLinks(text);

      expect(
        websites.any(
          (w) => w.contains('kfc.com.pk') && !w.endsWith('.'),
        ),
        isTrue,
      );

      expect(
        websites.any(
          (w) => w.contains('daraz.pk') && !w.endsWith('!'),
        ),
        isTrue,
      );

      expect(
        websites.any(
          (w) => w.contains('instagram.com/outfitterspk'),
        ),
        isTrue,
      );
    });

    // -----------------------------------------------------------
    // ADDRESS TESTS
    // -----------------------------------------------------------

    test('Detects house numbers, street numbers and sectors', () {
      const text = '''
KFC Fast Food
House # 45, Street 10, Sector F-11/3, Islamabad
Phone: 03001234567
''';

      final addresses = detector.detectAddresses(text);

      expect(addresses.isNotEmpty, isTrue);
      expect(addresses.first, contains('House # 45'));
      expect(addresses.first, contains('Street 10'));
      expect(addresses.first, contains('Sector F-11/3'));
      expect(addresses.first, contains('Islamabad'));
    });

    test('Detects addresses containing phases and colonies', () {
      const text = '''
Delivery Address:
House No. 14, Phase 5 DHA, Lahore
''';

      final addresses = detector.detectAddresses(text);

      expect(addresses.isNotEmpty, isTrue);
      expect(addresses.first, contains('House No. 14'));
      expect(addresses.first, contains('Phase 5 DHA'));
      expect(addresses.first, contains('Lahore'));
    });

    // -----------------------------------------------------------
    // DATE AND EVENT TESTS
    // -----------------------------------------------------------

    test('Detects dates written in numeric format', () {
      const text = '''
Annual Function
Date: 18/11/2026
Venue: Main Auditorium
''';

      final dates = detector.detectDatesAndEvents(text);

      expect(dates.isNotEmpty, isTrue);
      expect(
        dates.any((item) => item.contains('18/11/2026')),
        isTrue,
      );
    });

    test('Detects dates written with month names', () {
      const text = '''
Workshop
November 18, 2026
Registration is open.
''';

      final dates = detector.detectDatesAndEvents(text);

      expect(dates.isNotEmpty, isTrue);
      expect(
        dates.any((item) => item.contains('November 18, 2026')),
        isTrue,
      );
    });

    test('Does not detect dates when none are present', () {
      const text = '''
Welcome to our event.
Registration is now open.
Thank you for visiting.
''';

      final dates = detector.detectDatesAndEvents(text);

      expect(dates, isEmpty);
    });
  });

  group('RecognitionResult and Image Preprocessing Tests', () {
    test('RecognitionResult correctly flags Urdu failure with diagnostic message', () {
      const result = RecognitionResult(
        combinedText: 'Welcome to our store',
        englishText: 'Welcome to our store',
        urduText: '',
        englishSuccess: true,
        urduSuccess: false,
        urduError: 'Urdu offline OCR is supported on Android and iOS devices.',
      );

      expect(result.hasAnyText, isTrue);
      expect(result.hasUrduFailure, isTrue);
      expect(result.urduError, contains('Android and iOS'));
      expect(result.hasEnglishFailure, isFalse);
    });

    test('PreprocessingMetadata generates accurate summary', () {
      const meta = PreprocessingMetadata(
        isDarkModeInverted: true,
        wasUpscaled: true,
        wasDownscaled: false,
        wasContrastEnhanced: true,
        originalWidth: 600,
        originalHeight: 800,
        processedWidth: 1200,
        processedHeight: 1600,
        averageLuminance: 45.0,
      );

      expect(meta.summary.contains('Dark Mode Inverted'), isTrue);
      expect(meta.summary.contains('Resolution Upscaled'), isTrue);
      expect(meta.summary.contains('Contrast Enhanced'), isTrue);
      expect(meta.isDarkModeInverted, isTrue);
    });

    test('ImagePreprocessingService throws FileNotFoundException for missing files', () async {
      final service = ImagePreprocessingService();
      expect(
        () => service.preprocess('non_existent_file_path.png'),
        throwsA(isA<FileNotFoundException>()),
      );
    });

    test('ApiConfig validates keys accurately', () {
      expect(ApiConfig.isValidKey(''), isFalse);
      expect(ApiConfig.isValidKey('YOUR_GEMINI_API_KEY_HERE'), isFalse);
      expect(ApiConfig.isValidKey('short'), isFalse);
      expect(ApiConfig.isValidKey('AIzaSyD-validKeyForGeminiTest12345'), isTrue);
    });

    test('RecognitionResult constructs offline ML Kit result properly', () {
      const result = RecognitionResult(
        combinedText: 'Clean 100% extracted English text',
        englishText: 'Clean 100% extracted English text',
        englishSuccess: true,
        engineType: RecognitionEngineType.offlineMLKit,
        engineNotice: 'Extracted with On-Device AI Engine (100% Offline)',
      );
      expect(result.hasAnyText, isTrue);
      expect(result.combinedText, 'Clean 100% extracted English text');
      expect(result.englishSuccess, isTrue);
      expect(result.isGeminiVision, isFalse);
    });
  });

  group('Urdu Action Detection Tests', () {
    test('Normalizes Urdu numerals to Western digits accurately', () {
      expect(detector.normalizeUrduDigits('۰۳۰۰۱۲۳۴۵۶۷'), '03001234567');
      expect(detector.normalizeUrduDigits('۱۵ نومبر ۲۰۲۶'), '15 نومبر 2026');
    });

    test('Detects Urdu phone numbers written in Urdu numerals', () {
      const text = 'رابطہ نمبر: ۰۳۰۰-۱۲۳۴۵۶۷ یا ۰۳۲۱ ۷۶۵۴۳۲۱';
      final phones = detector.detectPhoneNumbers(text);

      expect(phones.length, greaterThanOrEqualTo(2));
      expect(phones.any((p) => p.contains('0300')), isTrue);
      expect(phones.any((p) => p.contains('0321')), isTrue);
    });

    test('Detects Urdu addresses with Urdu keywords and cities', () {
      const text = '''
پتہ:
مکان نمبر 45، گلی نمبر 10، فیز 5 ڈی ایچ اے، لاہور
فون: 03001234567
''';
      final addresses = detector.detectAddresses(text);

      expect(addresses.isNotEmpty, isTrue);
      expect(addresses.first.contains('مکان نمبر 45'), isTrue);
      expect(addresses.first.contains('لاہور'), isTrue);
    });

    test('Detects Urdu dates with Urdu month names', () {
      const text = '''
سالانہ تقریب
تاریخ: 15 نومبر 2026
مقام: جناح ہال
''';
      final dates = detector.detectDatesAndEvents(text);

      expect(dates.isNotEmpty, isTrue);
      expect(dates.any((d) => d.contains('15 نومبر 2026')), isTrue);
    });

    test('Does NOT detect false positive phone numbers from arbitrary digit sequences', () {
      const nonPhoneText = '''
Order # 9876543210
Tracking Code: 123456789012
Total Amount: Rs. 45,000
Barcode: 890123456789
Date: 20261120
Dummy: 0000000000
''';
      final phones = detector.detectPhoneNumbers(nonPhoneText);
      expect(phones, isEmpty, reason: 'Arbitrary digits, order IDs and barcodes must not be recognized as phone numbers');
    });

    test('Clean text with no numbers returns empty phone list', () {
      const pureText = '''
Welcome to Antigravity Software Solutions
We build modern mobile applications for Android and iOS.
''';
      final phones = detector.detectPhoneNumbers(pureText);
      expect(phones, isEmpty);
    });
  });
}