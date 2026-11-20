class ActionDetectionService {
  // -------------------------------------------------------------
  // 1. PHONE NUMBERS (Supports English and Urdu Numerals)
  // -------------------------------------------------------------
  List<String> detectPhoneNumbers(String text) {
    // Normalize Eastern Arabic/Urdu digits (۰۱۲۳۴۵۶۷۸۹) to standard digits (0123456789)
    final normalizedText = normalizeUrduDigits(text);

    final phoneRegex = RegExp(
      r'(?:(?:\+|00)\d{1,3}[\s-]?)?'
      r'(?:\(?0?\d{2,4}\)?[\s-]?)'
      r'\d{3,4}[\s-]?\d{3,4}',
    );

    final results = <String>[];

    for (final match in phoneRegex.allMatches(normalizedText)) {
      final number = match.group(0)!.trim();
      final digits = number.replaceAll(RegExp(r'\D'), '');

      if (digits.length >= 9 &&
          digits.length <= 15 &&
          !results.contains(number)) {
        results.add(number);
      }
    }

    return results;
  }

  // -------------------------------------------------------------
  // 2. WEBSITE LINKS
  // -------------------------------------------------------------
  List<String> detectWebsiteLinks(String text) {
    final websiteRegex = RegExp(
      r'(?<![A-Za-z0-9_@-])'
      r'(?:(?:https?:\/\/)?(?:www\.)?)'
      r'(?:[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?\.)+'
      r'[A-Za-z]{2,}'
      r'(?:\/[^\s]*)?',
      caseSensitive: false,
    );

    final results = <String>[];

    for (final match in websiteRegex.allMatches(text)) {
      var website = match.group(0)!.trim();

      website = website.replaceAll(
        RegExp(r'[.,;:!?]+$'),
        '',
      );

      if (!website.startsWith('http://') &&
          !website.startsWith('https://')) {
        website = 'https://$website';
      }

      if (!results.contains(website)) {
        results.add(website);
      }
    }

    return results;
  }

  // -------------------------------------------------------------
  // 3. ADDRESS DETECTION (English & Urdu Nastaliq Keywords)
  // -------------------------------------------------------------
  List<String> detectAddresses(String text) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final results = <String>[];
    final consumed = <int>{};

    final addressPattern = RegExp(
      r'('
      // English keywords
      r'house\s*(?:number|no\.?|#)?\s*[-:#]?\s*\d+|'
      r'street\s*(?:number|no\.?|#)?\s*[-:#]?\s*\d+|'
      r'suite\s*(?:number|no\.?|#)?\s*[-:#]?\s*\d+|'
      r'flat\s*(?:number|no\.?|#)?\s*[-:#]?\s*\d+|'
      r'plot\s*(?:number|no\.?|#)?\s*[-:#]?\s*\d+|'
      r'road|street|avenue|lane|chowk|'
      r'sector|block|phase|colony|'
      r'town|society|mohallah|'
      r'markaz|plaza|complex|market|'
      // Urdu address keywords
      r'مکان\s*(?:نمبر|نمبر؟)?\s*[-:#]?\s*[\d۰-۹]+|'
      r'گلی\s*(?:نمبر|نمبر؟)?\s*[-:#]?\s*[\d۰-۹]+|'
      r'پلاٹ\s*(?:نمبر|نمبر؟)?\s*[-:#]?\s*[\d۰-۹]+|'
      r'فلیٹ\s*(?:نمبر|نمبر؟)?\s*[-:#]?\s*[\d۰-۹]+|'
      r'روڈ|سڑک|چوک|محلہ|سیکٹر|بلاک|فیز|کالونی|'
      r'ٹاؤن|سوسائٹی|مرکز|پلازہ|مارکیٹ|کمپلیکس'
      r')',
      caseSensitive: false,
    );

    final cityPattern = RegExp(
      r'('
      // English cities
      r'sahiwal|lahore|karachi|islamabad|'
      r'rawalpindi|multan|faisalabad|'
      r'gujranwala|peshawar|quetta|'
      r'sialkot|bahawalpur|okara|'
      r'pakistan|'
      // Urdu cities
      r'لاہور|کراچی|اسلام\s*آباد|راولپنڈی|فیصل\s*آباد|'
      r'ملتان|پشاور|کوئٹہ|سیالکوٹ|گوجرانوالہ|'
      r'ساہیوال|بہاولپور|اوکاڑہ|پاکستان'
      r')',
      caseSensitive: false,
    );

    final websitePattern = RegExp(
      r'(?:(?:https?:\/\/)?(?:www\.)?)'
      r'(?:[A-Za-z0-9-]+\.)+[A-Za-z]{2,}'
      r'(?:\/[^\s]*)?',
      caseSensitive: false,
    );

    final phonePattern = RegExp(
      r'(?:(?:\+|00)[\d۰-۹]{1,3}[\s-]?)?'
      r'(?:\(?0?[\d۰-۹]{2,4}\)?[\s-]?)'
      r'[\d۰-۹]{3,4}[\s-]?[\d۰-۹]{3,4}',
    );

    for (int i = 0; i < lines.length; i++) {
      if (consumed.contains(i)) continue;

      var currentLine = lines[i];

      // Remove websites and phone numbers.
      currentLine = currentLine
          .replaceAll(websitePattern, '')
          .replaceAll(phonePattern, '');

      currentLine = _cleanText(currentLine);

      if (currentLine.isEmpty ||
          !addressPattern.hasMatch(currentLine)) {
        continue;
      }

      final addressParts = <String>[currentLine];
      consumed.add(i);

      // Join nearby address continuation lines.
      for (int j = i + 1;
          j < lines.length && j <= i + 2;
          j++) {
        if (consumed.contains(j)) continue;

        var nextLine = lines[j];

        nextLine = nextLine
            .replaceAll(websitePattern, '')
            .replaceAll(phonePattern, '');

        nextLine = _cleanText(nextLine);

        if (nextLine.isEmpty) continue;

        final hasAddressKeyword =
            addressPattern.hasMatch(nextLine);

        final hasCityName =
            cityPattern.hasMatch(nextLine);

        final isShortContinuation =
            nextLine.length <= 40 &&
            !RegExp(r'\d{5,}').hasMatch(nextLine);

        if (hasAddressKeyword ||
            hasCityName ||
            isShortContinuation) {
          addressParts.add(nextLine);
          consumed.add(j);
        } else {
          break;
        }
      }

      final address = _cleanText(
        addressParts.join(', '),
      );

      if (address.length >= 5 &&
          !results.any(
            (existing) =>
                existing.toLowerCase() == address.toLowerCase(),
          )) {
        results.add(address);
      }
    }

    return results;
  }

  // -------------------------------------------------------------
  // 4. DATE AND EVENT DETECTION (English & Urdu Months)
  // -------------------------------------------------------------
  List<String> detectDatesAndEvents(String text) {
    final datePattern = RegExp(
      r'('
      // Numeric dates
      r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b|'
      r'\b\d{4}[/-]\d{1,2}[/-]\d{1,2}\b|'

      // English: 15 November or 15 November 2026
      r'\b\d{1,2}(?:st|nd|rd|th)?\s+'
      r'(?:January|February|March|April|May|June|July|'
      r'August|September|October|November|December|'
      r'Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)'
      r'(?:,?\s+\d{4})?\b|'

      // English: November 15 or November 15, 2026
      r'\b(?:January|February|March|April|May|June|July|'
      r'August|September|October|November|December|'
      r'Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)'
      r'\s+\d{1,2}(?:st|nd|rd|th)?'
      r'(?:,?\s+\d{4})?\b|'

      // Urdu: 15 نومبر 2026 or 15 نومبر or ۱۵ نومبر ۲۰۲۶
      r'[\d۰-۹]{1,2}\s+(?:جنوری|فروری|مارچ|اپریل|مئی|جون|جولائی|اگست|ستمبر|اکتوبر|نومبر|دسمبر)(?:\s+[\d۰-۹]{4})?|'
      r'(?:جنوری|فروری|مارچ|اپریل|مئی|جون|جولائی|اگست|ستمبر|اکتوبر|نومبر|دسمبر)\s+[\d۰-۹]{1,2}(?:,?\s+[\d۰-۹]{4})?'
      r')',
      caseSensitive: false,
    );

    final results = <String>[];

    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);

    for (final line in lines) {
      if (datePattern.hasMatch(line) &&
          !results.contains(line)) {
        results.add(line);
      }
    }

    return results;
  }

  // -------------------------------------------------------------
  // 5. HELPER: CONVERT URDU DIGITS TO WESTERN DIGITS
  // -------------------------------------------------------------
  String normalizeUrduDigits(String text) {
    const urduDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    String result = text;
    for (int i = 0; i < 10; i++) {
      result = result.replaceAll(urduDigits[i], '$i');
    }
    return result;
  }

  // -------------------------------------------------------------
  // 6. TEXT CLEANING
  // -------------------------------------------------------------
  String _cleanText(String text) {
    return text
        .replaceAll(RegExp(r'^[\s\-•|:]+'), '')
        .replaceAll(RegExp(r'[\s\-•|:]+$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
