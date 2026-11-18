import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class PlaceVerificationService {
  static const String _baseUrl =
      'https://nominatim.openstreetmap.org/search';

  static final Map<String, List<Map<String, dynamic>>> _cache = {};

  static DateTime? _lastRequestTime;

  Future<List<Map<String, dynamic>>> verifyPlace(
    String query,
  ) async {
    final cleanedQuery = query.trim();

    if (cleanedQuery.isEmpty) return [];

    final cacheKey = cleanedQuery.toLowerCase();

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      // Respect the public Nominatim limit:
      // maximum one request per second.
      if (_lastRequestTime != null) {
        final elapsed =
            DateTime.now().difference(_lastRequestTime!);

        if (elapsed < const Duration(seconds: 1)) {
          await Future.delayed(
            const Duration(seconds: 1) - elapsed,
          );
        }
      }

      final uri = Uri.parse(_baseUrl).replace(
        queryParameters: {
          'q': cleanedQuery,
          'format': 'jsonv2',
          'addressdetails': '1',
          'limit': '5',
          'countrycodes': 'pk',
        },
      );

      _lastRequestTime = DateTime.now();

      final response = await http
          .get(
            uri,
            headers: {
              'User-Agent': 'ScreenshotToAction/1.0',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return [];
      }

      final List<dynamic> data = jsonDecode(response.body);

      final results = <Map<String, dynamic>>[];

      for (final item in data) {
        final result = Map<String, dynamic>.from(item);

        final name = result['name']?.toString() ?? '';
        final displayName =
            result['display_name']?.toString() ?? '';

        final latitude = result['lat']?.toString();
        final longitude = result['lon']?.toString();

        if (displayName.isEmpty ||
            latitude == null ||
            longitude == null) {
          continue;
        }

        // Reject results that do not sufficiently match
        // the original screenshot text.
        if (!_isRelevant(cleanedQuery, name, displayName)) {
          continue;
        }

        results.add({
          'name': name.isNotEmpty ? name : cleanedQuery,
          'address': displayName,
          'latitude': latitude,
          'longitude': longitude,
          'type': result['type'] ?? '',
          'category': result['category'] ?? '',
        });
      }

      _cache[cacheKey] = results;

      return results;
    } catch (_) {
      return [];
    }
  }

  bool _isRelevant(
    String query,
    String name,
    String displayName,
  ) {
    final ignoredWords = {
      'the',
      'of',
      'and',
      'at',
      'in',
      'near',
      'to',
      'road',
      'street',
      'university',
      'college',
      'institute',
      'hospital',
      'restaurant',
      'shop',
      'market',
      'building',
    };

    Set<String> getUsefulWords(String value) {
      return value
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
          .split(RegExp(r'\s+'))
          .where(
            (word) =>
                word.length >= 3 &&
                !ignoredWords.contains(word),
          )
          .toSet();
    }

    final queryWords = getUsefulWords(query);
    final resultWords = getUsefulWords('$name $displayName');

    if (queryWords.isEmpty) return false;

    final matchingWords =
        queryWords.intersection(resultWords);

    // Require a meaningful word match.
    final matchRatio = matchingWords.length / queryWords.length;

    return matchingWords.isNotEmpty && matchRatio >= 0.5;
  }
}
