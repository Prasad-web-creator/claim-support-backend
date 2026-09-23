/// Helpers for reading loosely-typed JSON coming back from the analysis API.
///
/// The backend sanitises nulls by replacing them with `""` (see
/// `_sanitize_nulls` in `app/models/analysis_report.py`), so a list-valued key
/// such as `prescriptionJson['symptoms']` arrives as an empty string whenever
/// the extractor produced nothing. LLM output is also not guaranteed to respect
/// the declared schema. A bare `as List?` cast therefore blows up the whole
/// screen, so read list fields through [asList] instead.
List<dynamic> asList(dynamic value) {
  if (value is List) return value;
  return const [];
}

/// Same contract as [asList], for dictionary-valued fields.
Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}
