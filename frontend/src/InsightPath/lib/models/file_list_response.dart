import 'file_item.dart';

class PathItem {
  final int id;
  final String name;

  PathItem({
    required this.id,
    required this.name,
  });
}

class FileListResponse {
  final int currentFolderId;
  final List<PathItem> path;
  final List<FileItem> files;

  FileListResponse({
    required this.currentFolderId,
    required this.path,
    required this.files,
  });
}

