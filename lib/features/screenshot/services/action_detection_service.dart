import 'dart:math';

class ActionDetectionService {
  // -------------------------------------------------------------
  // 1. PHONE NUMBERS
  // -------------------------------------------------------------
  List<String> detectPhoneNumbers(String text) {
    final phoneRegex = RegExp(
      r'(?:(?:\+|00)\d{1,3}[\s-]?)?' // Country code like +92, +1, 0092
      r'(?:\(?0?\d{2,4}\)?[\s-]?)?' // Area/network code like (051), 0300, 321
      r'\d{3,4}[\s-]?\d{3,4}' // Main number body
      r'|'
      r'\b111[\s-]?\d{3}[\s-]?\d{3}\b' // UAN like 111-123-456
      r'|'
      r'\b0800[\s-]?\d{5}\b', // Toll-free like 0800-12345
    );

    final matches = phoneRegex.allMatches(text);
    final results = <String>[];

    for (final match in matches) {
      String raw = match.group(0)!.trim();

      // Clean trailing punctuation
      raw = raw.replaceAll(RegExp(r'[\.,;:!?\)\]"\x27\-]+$'), '').trim();
      raw = raw.replaceAll(RegExp(r'^[\.,;:!?\(\[\"\x27\-]+'), '').trim();

      final digitsOnly = raw.replaceAll(RegExp(r'\D'), '');

      // Exclude numbers that are too short, too long, or look like 4-digit years (e.g. 2024, 2025)
      if (digitsOnly.length < 9 || digitsOnly.length > 15) continue;
      if (digitsOnly.length == 4) continue;

      if (!results.contains(raw)) {
        results.add(raw);
      }
    }

    return results;
  }

  // -------------------------------------------------------------
  // 2. WEBSITE LINKS
  // -------------------------------------------------------------
  List<String> detectWebsiteLinks(String text) {
    final urlRegex = RegExp(
      r'(?:https?:\/\/)?' // Optional scheme
      r'(?:www\.)?' // Optional www
      r'(?:'
      r'[a-zA-Z0-9-]+\.'
      r'(?:com|pk|org|net|io|co|store|online|tech|app|ai|me|edu|gov|info|biz|site|xyz)'
      r'(?:\.[a-zA-Z]{2})?' // e.g. .com.pk, .org.pk
      r'|'
      r'(?:instagram|facebook|fb|tiktok|twitter|x|youtube|linkedin)\.com\/[a-zA-Z0-9_.-]+'
      r')'
      r'(?:\/[^\s]*)?', // Optional path
      caseSensitive: false,
    );

    final matches = urlRegex.allMatches(text);
    final results = <String>[];

    for (final match in matches) {
      String url = match.group(0)!.trim();

      // Clean leading and trailing punctuation (dots, commas, exclamation marks, quotes, brackets)
      url = url.replaceAll(RegExp(r'[\.,;:!?\)\]"\x27\>]+$'), '');
      url = url.replaceAll(RegExp(r'^[\.,;:!?\(\[\"\x27\<]+'), '');

      if (url.isEmpty) continue;

      // Avoid matching email addresses like user@domain.com
      final matchIndex = match.start;
      if (matchIndex > 0 && text[matchIndex - 1] == '@') {
        continue;
      }

      // Format with https://
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://$url';
      }

      if (!results.contains(url)) {
        results.add(url);
      }
    }

    return results;
  }

  // -------------------------------------------------------------
  // 3. ADDRESS DETECTION (Street, House, Sector, City, etc.)
  // -------------------------------------------------------------
  List<String> detectAddresses(String text) {
    final rawLines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (rawLines.isEmpty) return [];

    final detected = <String>[];

    // High-confidence address markers
    final premiseRegex = RegExp(
      r'\b(?:house|h|home|flat|apt|apartment|plot|shop|office|unit|suite|building|bldg)\s*(?:#|no\.?|num\.?)?\s*\d+[a-zA-Z]?(?:[-/]\d+[a-zA-Z]?)?\b',
      caseSensitive: false,
    );

    final streetRegex = RegExp(
      r'\b(?:street|st|lane|boulevard|blvd|road|rd|avenue|ave|highway|hwy|way|drive|dr|chowk|markaz)\s*(?:#|no\.?|num\.?)?\s*\d*[a-zA-Z]?\b',
      caseSensitive: false,
    );

    final sectorAreaRegex = RegExp(
      r'\b(?:sector|phase|block|colony|town|society|mohallah|cantt|cantonment|commercial area|dha|bahria)\b'
      r'|'
      r'\b[FfGgHhIi]-\d+(?:\/\d+)?\b', // F-7/2, G-9, I-8
      caseSensitive: false,
    );

    final landmarkRegex = RegExp(
      r'\b(?:near|opposite|opp\.?|behind|next to|beside|adjacent to|in front of)\b',
      caseSensitive: false,
    );

    final cityRegex = RegExp(
      r'\b(?:islamabad|lahore|karachi|rawalpindi|faisalabad|multan|peshawar|quetta|'
      r'sahiwal|gujranwala|sialkot|hyderabad|abbottabad|bahawalpur|sargodha|'
      r'gulberg|gulshan|clifton|blue area|johar town|model town|pakistan)\b',
      caseSensitive: false,
    );

    int getAddressScore(String line) {
      int score = 0;
      if (premiseRegex.hasMatch(line)) score += 3;
      if (streetRegex.hasMatch(line)) score += 3;
      if (sectorAreaRegex.hasMatch(line)) score += 2;
      if (landmarkRegex.hasMatch(line)) score += 2;
      if (cityRegex.hasMatch(line)) score += 2;
      if (RegExp(r'\b\d{5}\b').hasMatch(line)) score += 1; // Postal code
      return score;
    }

    // Pass 1: Multi-line and single-line address scanning
    int i = 0;
    while (i < rawLines.length) {
      String line = _cleanAddressLine(rawLines[i]);
      int score = getAddressScore(line);

      if (score >= 2) {
        final addressParts = <String>[line];

        // Check if next lines are continuation of the address
        int j = i + 1;
        while (j < rawLines.length && j <= i + 2) {
          final nextLine = _cleanAddressLine(rawLines[j]);
          final nextScore = getAddressScore(nextLine);

          // If next line has address keywords or is a city/sector line
          if (nextScore > 0 && !_isInvalidAddressLine(nextLine)) {
            addressParts.add(nextLine);
            j++;
          } else {
            break;
          }
        }

        final combinedAddress = addressParts.join(', ');
        if (!_isInvalidAddressLine(combinedAddress)) {
          _addAddressIfUnique(detected, combinedAddress);
        }

        i = j; // skip consumed lines
      } else {
        i++;
      }
    }

    return detected;
  }

  String _cleanAddressLine(String line) {
    String cleaned = line.trim();
    cleaned = cleaned.replaceAll(
      RegExp(r'^(?:address|location|loc|branch|add|find us at)\s*[:\-]\s*', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(RegExp(r'[\.,;\-]+$'), '').trim();
    return cleaned;
  }

  bool _isInvalidAddressLine(String line) {
    if (RegExp(r'^(?:https?:\/\/|www\.)', caseSensitive: false).hasMatch(line)) return true;
    if (RegExp(r'^\+?[\d\s().-]{7,}$').hasMatch(line)) return true;
    return false;
  }

  void _addAddressIfUnique(List<String> list, String newAddress) {
    final cleaned = newAddress.trim();
    if (cleaned.length < 5) return;

    for (int i = 0; i < list.length; i++) {
      if (list[i].toLowerCase().contains(cleaned.toLowerCase())) {
        return; // Already covered by more detailed address
      }
      if (cleaned.toLowerCase().contains(list[i].toLowerCase())) {
        list[i] = cleaned; // Replace with more detailed version
        return;
      }
    }

    list.add(cleaned);
  }

  // -------------------------------------------------------------
  // 4. RESTAURANTS, BRANDS & PLACES DETECTION
  // -------------------------------------------------------------
  List<String> detectPlaceCandidates(String text) {
    final places = <String>[];

    void addPlace(String name) {
      name = name.trim();
      name = name.replaceAll(RegExp(r'^[\s\-:,]+|[\s\-:,]+$'), '');
      if (name.length < 2 || name.length > 50) return;

      if (RegExp(r'^(?:https?:\/\/|www\.|\+?\d)', caseSensitive: false).hasMatch(name)) return;

      for (int i = 0; i < places.length; i++) {
        if (places[i].toLowerCase() == name.toLowerCase()) return;
        if (places[i].toLowerCase().contains(name.toLowerCase())) return;
        if (name.toLowerCase().contains(places[i].toLowerCase())) {
          places[i] = name;
          return;
        }
      }
      places.add(name);
    }

    // A. Popular Restaurant & Brand Dictionary
    final popularNames = [
      // Fast food & Pizza
      'KFC', "McDonald's", 'McDonalds', 'Subway', 'Pizza Hut', "Domino's", 'Dominos',
      "Hardee's", 'Hardees', 'Cheezious', 'Burger King', 'Texas Chicken', 'Howdy',
      'OPTP', 'Ranchers', 'Broadway Pizza', '14th Street Pizza', 'Daily Deli', 'Johnny & Jugnu',
      // Cafes & Coffee & Bakes
      "Gloria Jean's", 'Gloria Jeans', 'Second Cup', 'Starbucks', 'Tim Hortons', 'Chaye Khana',
      'The Coffee Bean', 'Burning Brownie', 'Cinnabon', "Dunkin'", 'Dunkin Donuts', 'Dunkin',
      'Layers Bakeshop', 'Tehzeeb Bakers', 'Rahat Bakers', 'Gourmet Bakers', 'Kitchen Cuisine',
      'Sweet Tooth', 'Jalal Sons', 'Esquires Coffee', "Rina's Kitchenette",
      // Desi & Continental Dining
      'Monal', 'Bundu Khan', 'Savour Foods', "Salt'n Pepper", 'Habibi', 'Kababjees',
      'Kolachi', 'Bar.B.Q Tonight', 'Ginsoy', 'Mei Kong', 'Chilli Chutney', 'Butt Karahi',
      'Shinwari', 'Tayto', 'Roasters', 'Cafe Aylanto', 'Arcadian Cafe', "Nando's", 'Nandos',
      // Fashion & Retail Brands
      'Khaadi', 'Gul Ahmed', 'J.', 'Junaid Jamshed', 'Outfitters', 'Alkaram', 'Sana Safinaz',
      'Maria.B', 'Sapphire', 'Bonanza Satrangi', 'Nishat Linen', 'Limelight', 'Bata',
      'Service', 'Borjan', 'Stylo', 'Edenrobe', 'Charcoal', 'Uniworth', 'Diners',
      'Levis', "Levi's", 'Nike', 'Adidas', 'Puma', 'Zara', 'H&M', 'Gucci', 'Breakout',
      'Cougar', 'Engine', 'ECS', 'Ndure', 'Bareeze', 'Baroque',
      // Tech, Services & Marts
      'Apple', 'Samsung', 'Xiaomi', 'Huawei', 'Infinix', 'Tecno', 'Vivo', 'Oppo',
      'Sony', 'HP', 'Dell', 'Lenovo', 'Daraz', 'Foodpanda', 'Careem', 'Indrive', 'Bykea',
      'Carrefour', 'Metro', 'Imtiaz Super Market', 'Al-Fatah', 'Chase Up',
    ];

    for (final name in popularNames) {
      final regex = RegExp('\\b${RegExp.escape(name)}\\b', caseSensitive: false);
      if (regex.hasMatch(text)) {
        addPlace(name);
      }
    }

    // B. Explicit Prefix / Tag Patterns (e.g. "Restaurant: XYZ", "Brand: XYZ", "Welcome to XYZ")
    final prefixPatterns = [
      RegExp(r'\b(?:restaurant|cafe|brand|store|shop|outlet|hotel|bakery|kitchen|bistro|pizzeria)\s*[:\-]\s*([^\n,]+)', caseSensitive: false),
      RegExp(r'\b(?:welcome to|ordered from|visit)\s+([A-Za-z0-9\s&.\x27-]{2,30})', caseSensitive: false),
    ];

    for (final pattern in prefixPatterns) {
      for (final match in pattern.allMatches(text)) {
        final candidate = match.group(1)?.trim();
        if (candidate != null && candidate.isNotEmpty) {
          addPlace(candidate);
        }
      }
    }

    // C. Keyword Suffix Patterns (e.g. "XYZ Restaurant", "XYZ Cafe", "XYZ Bakers", "XYZ Studio")
    final suffixKeywords = [
      'restaurant', 'cafe', 'pizzeria', 'bakery', 'bakers', 'kitchen', 'diner',
      'bistro', 'grill', 'fast food', 'lounge', 'eatery', 'coffee', 'burger',
      'pizza', 'karahi', 'tikka', 'sweets', 'pharmacy', 'hospital', 'clinic',
      'salon', 'supermarket', 'mart', 'mall', 'boutique', 'studio', 'jewellers',
    ];

    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    for (final line in lines) {
      if (RegExp(r'^(?:https?:\/\/|www\.|\+?\d)', caseSensitive: false).hasMatch(line)) continue;
      if (RegExp(r'\b(?:street|house|h#|road|sector)\b', caseSensitive: false).hasMatch(line)) continue;

      for (final kw in suffixKeywords) {
        if (RegExp('\\b${RegExp.escape(kw)}\\b', caseSensitive: false).hasMatch(line)) {
          final words = line.split(RegExp(r'\s+'));
          if (words.length <= 6) {
            addPlace(line);
          }
          break;
        }
      }
    }

    // D. Extract Brand Name from Websites / Domains in text
    final domainMatches = RegExp(
      r'(?:https?:\/\/)?(?:www\.)?([a-zA-Z0-9-]+)\.(?:com|pk|org|net|io|co|store|app)',
      caseSensitive: false,
    ).allMatches(text);

    for (final match in domainMatches) {
      final domainSlug = match.group(1)?.toLowerCase();
      if (domainSlug != null && domainSlug.length >= 3) {
        if (['google', 'facebook', 'instagram', 'twitter', 'tiktok', 'youtube'].contains(domainSlug)) {
          continue;
        }
        for (final line in lines) {
          final normalizedLine = line.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
          if (normalizedLine.contains(domainSlug) && line.split(' ').length <= 4) {
            addPlace(line);
          }
        }
      }
    }

    // E. Fallback: First prominent non-generic header line (if places is still empty)
    if (places.isEmpty && lines.isNotEmpty) {
      final ignoredHeaderWords = {
        'screenshot', 'notification', 'notifications', 'settings', 'search',
        'follow', 'following', 'message', 'messages', 'profile', 'home',
        'menu', 'order', 'orders', 'summary', 'invoice', 'receipt', 'total',
        'subtotal', 'discount', 'status', 'battery', 'share', 'edit',
      };

      for (int k = 0; k < min(lines.length, 3); k++) {
        final line = lines[k];
        final words = line.split(RegExp(r'\s+'));
        if (words.isNotEmpty && words.length <= 4) {
          final lower = line.toLowerCase();
          if (!ignoredHeaderWords.any((w) => lower.contains(w)) &&
              !RegExp(r'^\d+$').hasMatch(line) &&
              !RegExp(r'^(?:https?:\/\/|www\.|\+?\d)', caseSensitive: false).hasMatch(line)) {
            addPlace(line);
            break;
          }
        }
      }
    }

    return places;
  }
}
