

class ActionDetectionService {
  // -------------------------------------------------------------
  // 1. PHONE NUMBERS
  // -------------------------------------------------------------
  List<String> detectPhoneNumbers(String text) {
    final phoneRegex = RegExp(
      r'(?:(?:\+|00)\d{1,3}[\s-]?)?'
      r'(?:\(?0?\d{2,4}\)?[\s-]?)'
      r'\d{3,4}[\s-]?\d{3,4}',
    );

    final results = <String>[];

    for (final match in phoneRegex.allMatches(text)) {
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
  // 3. ADDRESS DETECTION
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
    r'\b('
    r'house\s*(?:number|no\.?|#)?\s*[-:#]?\s*\d+|'
    r'street\s*(?:number|no\.?|#)?\s*[-:#]?\s*\d+|'
    r'suite\s*(?:number|no\.?|#)?\s*[-:#]?\s*\d+|'
    r'flat\s*(?:number|no\.?|#)?\s*[-:#]?\s*\d+|'
    r'plot\s*(?:number|no\.?|#)?\s*[-:#]?\s*\d+|'
    r'road|street|avenue|lane|chowk|'
    r'sector|block|phase|colony|'
    r'town|society|mohallah|'
    r'markaz|plaza|complex|market'
    r')\b',
    caseSensitive: false,
  );

  final cityPattern = RegExp(
    r'\b('
    r'sahiwal|lahore|karachi|islamabad|'
    r'rawalpindi|multan|faisalabad|'
    r'gujranwala|peshawar|quetta|'
    r'sialkot|bahawalpur|okara|'
    r'pakistan'
    r')\b',
    caseSensitive: false,
  );

  final websitePattern = RegExp(
    r'(?:(?:https?:\/\/)?(?:www\.)?)'
    r'(?:[A-Za-z0-9-]+\.)+[A-Za-z]{2,}'
    r'(?:\/[^\s]*)?',
    caseSensitive: false,
  );

  final phonePattern = RegExp(
    r'(?:(?:\+|00)\d{1,3}[\s-]?)?'
    r'(?:\(?0?\d{2,4}\)?[\s-]?)'
    r'\d{3,4}[\s-]?\d{3,4}',
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
          nextLine.length <= 35 &&
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
  // 4. DATE AND EVENT DETECTION
  // -------------------------------------------------------------

List<String> detectDatesAndEvents(String text) {
  final datePattern = RegExp(
    r'\b('
    // Numeric dates
    r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|'
    r'\d{4}[/-]\d{1,2}[/-]\d{1,2}|'

    // 15 November or 15 November 2026
    r'\d{1,2}(?:st|nd|rd|th)?\s+'
    r'(?:January|February|March|April|May|June|July|'
    r'August|September|October|November|December|'
    r'Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)'
    r'(?:,?\s+\d{4})?|'

    // November 15 or November 15, 2026
    r'(?:January|February|March|April|May|June|July|'
    r'August|September|October|November|December|'
    r'Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)'
    r'\s+\d{1,2}(?:st|nd|rd|th)?'
    r'(?:,?\s+\d{4})?'
    r')\b',
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
  // 5. TEXT CLEANING
  // -------------------------------------------------------------
  String _cleanText(String text) {
    return text
        .replaceAll(RegExp(r'^[\s\-•|:]+'), '')
        .replaceAll(RegExp(r'[\s\-•|:]+$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}