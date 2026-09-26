// Admin export data models

part of '../admin_models.dart';

class AdminExportFile {
  AdminExportFile({
    required this.fileName,
    required this.contentType,
    required this.content,
    required this.rowCount,
  });

  final String fileName;
  final String contentType;
  final String content;
  final int rowCount;

  factory AdminExportFile.fromJson(Map<String, dynamic> json) {
    final String fileName = (json['fileName'] ?? '').toString();
    final String contentType = (json['contentType'] ?? '').toString();
    final Object? content = json['data'];
    final int? rowCount = _toInt(json['rowCount']);
    if (fileName.isEmpty ||
        contentType.isEmpty ||
        content is! String ||
        rowCount == null) {
      throw const FormatException('导出响应格式无效');
    }
    return AdminExportFile(
      fileName: fileName,
      contentType: contentType,
      content: content,
      rowCount: rowCount,
    );
  }
}
