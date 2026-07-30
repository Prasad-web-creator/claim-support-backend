class PaginationResponse<T> {
  final List<T> docs;
  final int totalDocs;
  final int limit;
  final int totalPages;
  final int page;
  final bool hasPrevPage;
  final bool hasNextPage;

  PaginationResponse({
    required this.docs,
    required this.totalDocs,
    required this.limit,
    required this.totalPages,
    required this.page,
    required this.hasPrevPage,
    required this.hasNextPage,
  });

  factory PaginationResponse.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic>) fromJsonT) {
    return PaginationResponse(
      docs: (json['docs'] as List?)?.map((i) => fromJsonT(i as Map<String, dynamic>)).toList() ?? [],
      totalDocs: (json['totalDocs'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 10,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
      page: (json['page'] as num?)?.toInt() ?? 1,
      hasPrevPage: json['hasPrevPage'] ?? false,
      hasNextPage: json['hasNextPage'] ?? false,
    );
  }
}
