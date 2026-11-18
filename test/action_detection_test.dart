import 'package:flutter_test/flutter_test.dart';
import 'package:screenshot_to_action/features/screenshot/services/action_detection_service.dart';
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
}