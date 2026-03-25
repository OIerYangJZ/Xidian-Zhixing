// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;

import 'picked_image_data.dart';

Future<List<PickedImageData>> pickImageFiles({bool multiple = true}) async {
  final html.FileUploadInputElement input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = multiple;

  final Completer<List<PickedImageData>> completer = Completer<List<PickedImageData>>();

  void completeSafely(List<PickedImageData> value) {
    if (!completer.isCompleted) {
      completer.complete(value);
    }
  }

  input.onChange.listen((_) async {
    final List<html.File> files = input.files?.toList() ?? <html.File>[];
    if (files.isEmpty) {
      completeSafely(const <PickedImageData>[]);
      return;
    }

    final List<PickedImageData> results = <PickedImageData>[];
    for (final html.File file in files) {
      final String? dataUrl = await _readAsDataUrl(file);
      if (dataUrl == null || !dataUrl.contains(',')) {
        continue;
      }
      final int separator = dataUrl.indexOf(',');
      final String header = dataUrl.substring(0, separator);
      final String base64Data = dataUrl.substring(separator + 1);
      final String contentType = _extractContentType(header, fallback: file.type);

      // 校验文件类型
      if (!_isAllowedImageType(contentType)) {
        continue;
      }

      // 计算原始文件大小（Base64 编码会增加约 33% 长度）
      final int sizeBytes = _calcBase64DecodedSize(base64Data);

      // 校验文件大小（不超过 10MB 作为前端预防上限）
      const int maxPreviewSize = 10 * 1024 * 1024;
      if (sizeBytes > maxPreviewSize) {
        continue;
      }

      results.add(
        PickedImageData(
          fileName: file.name,
          contentType: contentType,
          dataBase64: base64Data,
          sizeBytes: sizeBytes,
          previewDataUrl: dataUrl,
        ),
      );
    }
    completeSafely(results);
  });

  input.click();

  // If user cancels file chooser in some browsers, onChange may not fire.
  Future<void>.delayed(const Duration(seconds: 15), () {
    completeSafely(const <PickedImageData>[]);
  });
  return completer.future;
}

Future<String?> _readAsDataUrl(html.File file) {
  final Completer<String?> completer = Completer<String?>();
  final html.FileReader reader = html.FileReader();
  reader.readAsDataUrl(file);
  reader.onLoadEnd.listen((_) {
    if (!completer.isCompleted) {
      completer.complete(reader.result as String?);
    }
  });
  reader.onError.listen((_) {
    if (!completer.isCompleted) {
      completer.complete(null);
    }
  });
  return completer.future;
}

String _extractContentType(String dataUrlHeader, {required String fallback}) {
  final String normalizedFallback = fallback.trim().toLowerCase();
  final RegExpMatch? match = RegExp(r'^data:([^;]+);base64$').firstMatch(dataUrlHeader);
  if (match != null) {
    final String raw = match.group(1)?.trim().toLowerCase() ?? '';
    if (raw.isNotEmpty) {
      return raw;
    }
  }
  if (normalizedFallback.isNotEmpty) {
    return normalizedFallback;
  }
  return 'application/octet-stream';
}

bool _isAllowedImageType(String contentType) {
  const Set<String> allowed = <String>{'image/jpeg', 'image/png', 'image/webp', 'image/gif'};
  return allowed.contains(contentType.toLowerCase());
}

int _calcBase64DecodedSize(String base64Data) {
  // Base64 编码公式：output_length = (input_length * 4 + 3) / 3
  // 还原公式：input_length = output_length * 3 / 4
  int padding = 0;
  if (base64Data.endsWith('==')) {
    padding = 2;
  } else if (base64Data.endsWith('=')) {
    padding = 1;
  }
  return (base64Data.length * 3 ~/ 4) - padding;
}
