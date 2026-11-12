import 'package:flutter/material.dart';

class ActionDetectionService {
  // 1. Detect phone numbers
  List<String> detectPhoneNumbers(String text) {
    final regex = RegExp(
      r'(\+?\d{1,3}[\s-]?)?'
      r'(\(?\d{2,4}\)?[\s-]?)?'
      r'\d{3,4}[\s-]?\d{4}',
    );

    final matches = regex.allMatches(text);

    return matches
        .map((match) => match.group(0)!.trim())
        .where((number) => number.replaceAll(RegExp(r'\D'), '').length >= 10)
        .toSet()
        .toList();
  }

  // 2. Detect website links
  List<String> detectWebsiteLinks(String text) {
    final regex = RegExp(
      r'((?:https?:\/\/)?(?:www\.)?'
      r'[a-zA-Z0-9-]+\.[a-zA-Z]{2,}'
      r'(?:\/[^\s]*)?)',
      caseSensitive: false,
    );

    final matches = regex.allMatches(text);

    return matches
        .map((match) {
          String website = match.group(0)!.trim();

          if (!website.startsWith('http://') &&
              !website.startsWith('https://')) {
            website = 'https://$website';
          }

          return website;
        })
        .toSet()
        .toList();
  }

  // 3. Detect address-related lines
  List<String> detectAddresses(String text) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final addressKeywords = [
      'street',
      'road',
      'avenue',
      'block',
      'sector',
      'chowk',
      'complex',
      'market',
      'town',
      'colony',
      'phase',
      'near',
      'opposite',
      'sahiwal',
      'lahore',
      'karachi',
      'islamabad',
    ];

    return lines.where((line) {
      return addressKeywords.any(
        (keyword) => RegExp(
          '\\b${RegExp.escape(keyword)}\\b',
          caseSensitive: false,
        ).hasMatch(line),
      );
    }).toSet().toList();
  }

  // 4. Detect possible business/place names
  List<String> detectPlaceCandidates(String text) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final places = <String>[];

    String normalize(String value) {
      return value.toLowerCase().replaceAll(
            RegExp(r'[^a-z0-9]'),
            '',
          );
    }

    bool isInvalidLine(String line) {
      return RegExp(
            r'(www\.|https?://|@)',
            caseSensitive: false,
          ).hasMatch(line) ||
          RegExp(r'\d{5,}').hasMatch(line);
    }

    void addPlace(String name) {
      name = name.trim();

      if (name.isNotEmpty && !places.contains(name)) {
        places.add(name);
      }
    }

    // Website-based detection
    final domains = RegExp(
      r'(?:https?://)?(?:www\.)?([a-z0-9-]+)\.[a-z]{2,}',
      caseSensitive: false,
    ).allMatches(text);

    for (final match in domains) {
      final domain = normalize(match.group(1)!);

      for (int i = 0; i < lines.length; i++) {
        if (isInvalidLine(lines[i])) continue;

        final candidates = <String>[lines[i]];

        if (i > 0 && !isInvalidLine(lines[i - 1])) {
          candidates.add('${lines[i - 1]} ${lines[i]}');
        }

        if (i + 1 < lines.length &&
            !isInvalidLine(lines[i + 1])) {
          candidates.add('${lines[i]} ${lines[i + 1]}');
        }

        for (String candidate in candidates) {
          candidate = candidate.split('-').first.trim();

          final normalizedCandidate = normalize(candidate);

          if (normalizedCandidate.length >= 8 &&
              domain.contains(normalizedCandidate)) {
            addPlace(candidate);
          }
        }
      }
    }

    // Keyword-based detection
    final keywords = [
      'cuisine',
      'restaurant',
      'cafe',
      'coffee',
      'hotel',
      'mall',
      'bakery',
      'pharmacy',
      'hospital',
      'salon',
      'supermarket',
      'pizza',
      'burger',
    ];

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];

      if (isInvalidLine(line)) continue;

      final hasKeyword = keywords.any(
        (keyword) => RegExp(
          '\\b${RegExp.escape(keyword)}\\b',
          caseSensitive: false,
        ).hasMatch(line),
      );

      if (!hasKeyword) continue;

      line = line.split('-').first.trim();

      if (i > 0 && !isInvalidLine(lines[i - 1])) {
        line = '${lines[i - 1]} $line';
      }

      addPlace(line);
    }

    // Context-based fallback detection
    if (places.isEmpty) {
      final hasPhone = RegExp(
        r'\+?\d[\d\s().-]{7,}\d',
      ).hasMatch(text);

      final hasAddress = RegExp(
        r'\b(street|road|avenue|block|sector|'
        r'chowk|complex|market|sahiwal|lahore|'
        r'karachi|islamabad)\b',
        caseSensitive: false,
      ).hasMatch(text);

      if (hasPhone || hasAddress) {
        final ignoredWords = {
          'pakistani',
          'continental',
          'arabic',
          'good',
          'mood',
          'food',
          'welcome',
          'official',
          'contact',
          'services',
          'quality',
          'delivery',
          'discount',
          'sale',
          'offer',
          'follow',
          'subscribe',
        };

        for (final line in lines) {
          if (isInvalidLine(line)) continue;

          final words = line.split(RegExp(r'\s+'));

          if (words.length < 2 || words.length > 4) {
            continue;
          }

          if (!RegExp(r'^[A-Z0-9 &]+$').hasMatch(line)) {
            continue;
          }

          if (line.length < 5 || line.length > 35) {
            continue;
          }

          final normalizedWords = words
              .map((word) => word.toLowerCase())
              .toList();

          if (normalizedWords.any(ignoredWords.contains)) {
            continue;
          }

          addPlace(line);
        }
      }
    }

    // Remove partial duplicate names
    final filteredPlaces = places.where((place) {
      return !places.any(
        (other) =>
            other != place &&
            other.toLowerCase().contains(place.toLowerCase()),
      );
    }).toList();

    debugPrint('FINAL PLACES: $filteredPlaces');

    return filteredPlaces;
  }
}
