// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
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
      int sizeBytes = 0;
      try {
        sizeBytes = base64Decode(base64Data).length;
      } catch (_) {
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
