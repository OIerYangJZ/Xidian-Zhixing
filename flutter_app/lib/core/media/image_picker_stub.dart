import 'dart:convert';

import 'package:image_picker/image_picker.dart';

import 'picked_image_data.dart';

/// Android / iOS: the system gallery through image_picker, so pages shared
/// with the web (编辑资料, 发帖) can pick images on the phone too.
Future<List<PickedImageData>> pickImageFiles({bool multiple = true}) async {
  final ImagePicker picker = ImagePicker();
  final List<XFile> files;
  if (multiple) {
    files = await picker.pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
  } else {
    final XFile? one = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    files = <XFile>[?one];
  }
  final List<PickedImageData> picked = <PickedImageData>[];
  for (final XFile file in files) {
    final List<int> bytes = await file.readAsBytes();
    final String type = _contentType(file.name);
    final String data = base64Encode(bytes);
    picked.add(
      PickedImageData(
        fileName: file.name,
        contentType: type,
        dataBase64: data,
        sizeBytes: bytes.length,
        previewDataUrl: 'data:$type;base64,$data',
      ),
    );
  }
  return picked;
}

String _contentType(String name) {
  switch (name.split('.').last.toLowerCase()) {
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    default:
      return 'image/jpeg';
  }
}
