class ApiData {
  static Map<String, dynamic> map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static dynamic unwrap(dynamic value) {
    if (value is Map) {
      final m = map(value);
      final data = m['data'];
      if (data is Map || data is List) return data;
    }
    return value;
  }

  static List<Map<String, dynamic>> list(dynamic value) {
    dynamic current = value;
    if (current is Map) {
      final m = map(current);
      for (final key in const [
        'data',
        'content',
        'items',
        'results',
        'users',
        'assessments',
        'consultations',
      ]) {
        final candidate = m[key];
        if (candidate is List) {
          current = candidate;
          break;
        }
        if (candidate is Map) {
          final nested = map(candidate);
          for (final nestedKey in const ['content', 'items', 'results']) {
            if (nested[nestedKey] is List) {
              current = nested[nestedKey];
              break;
            }
          }
        }
      }
    }

    if (current is! List) return <Map<String, dynamic>>[];
    return current.map((e) => map(e)).where((e) => e.isNotEmpty).toList();
  }

  static String firstText(Map<String, dynamic> item, List<String> keys,
      {String fallback = '—'}) {
    for (final key in keys) {
      final value = item[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return fallback;
  }

  static int? intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  static double? doubleValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }
}
