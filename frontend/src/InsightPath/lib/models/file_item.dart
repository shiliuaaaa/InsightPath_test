class FileItem {
  final String id;
  final int parentId;
  final String type;
  final String name;
  final String? url;
  final String? pdfUrl;
  final int? sizeBytes;
  final String? extension;
  final String updatedAt;
  final int? itemCount;

  FileItem({
    required this.id,
    required this.parentId,
    required this.type,
    required this.name,
    required this.url,
    this.pdfUrl,
    required this.sizeBytes,
    required this.extension,
    required this.updatedAt,
    required this.itemCount,
  });

  factory FileItem.fromJson(Map<String, dynamic> json) {
    return FileItem(
      id: (json['id'] as int? ?? 0).toString(),
      parentId: (json['parent_id'] ?? json['parentid']) as int? ?? 0,
      type: json['type'] as String? ?? 'FILE',
      name: json['name'] as String? ?? '',
      url: json['url'] as String?,
      pdfUrl: json['pdf_url'] as String?,
      sizeBytes: json['size'] as int?,
      extension: json['extension'] as String?,
      updatedAt: (json['updated_at'] ?? json['updatedat']) as String? ?? '',
      itemCount: (json['item_count'] ?? json['itemcount']) as int?,
    );
  }
}
