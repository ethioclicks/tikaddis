import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import 'app_toast.dart';

/// Largest image the backend accepts.
const int kMaxImageBytes = 5 * 1024 * 1024;

/// Lets the user pick a JPG or PNG, uploads it, and returns the stored image
/// path (`/public/images/<id>`), or null if they cancelled or it failed. All
/// failures are shown to the user as a toast.
Future<String?> pickAndUploadImage(BuildContext context, WidgetRef ref) async {
  final picked = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['jpg', 'jpeg', 'png'],
    withData: kIsWeb,
  );
  if (picked == null || picked.files.isEmpty) return null;

  final file = picked.files.single;
  if (file.size <= 0 || file.size > kMaxImageBytes) {
    if (context.mounted) {
      AppToast.error(context, 'Choose an image that is 5 MB or smaller.');
    }
    return null;
  }

  try {
    final bytes =
        file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null) {
      if (context.mounted) AppToast.error(context, 'Could not read that image.');
      return null;
    }
    final res = await ref
        .read(apiServiceProvider)
        .uploadImage(bytes, file.name);
    final url = (res.data is Map ? res.data['url'] : null) as String?;
    if (url == null || url.isEmpty) {
      throw StateError('Upload response had no url');
    }
    return url;
  } on DioException catch (e) {
    if (context.mounted) AppToast.error(context, _messageFor(e));
    return null;
  } catch (_) {
    if (context.mounted) {
      AppToast.error(context, 'Could not upload the image. Try again.');
    }
    return null;
  }
}

String _messageFor(DioException e) {
  final data = e.response?.data;
  if (data is Map && data['message'] != null) {
    final text = data['message'].toString().replaceFirst('Cause by:', '').trim();
    if (text.isNotEmpty) return text;
  }
  switch (e.response?.statusCode) {
    case 404:
      return 'Image upload is not available on the server yet.';
    case 413:
      return 'That image is too large. Choose one under 5 MB.';
    case 409:
      return 'You have reached the image limit for this account.';
  }
  if (e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout) {
    return "Can't reach the server. Check your connection.";
  }
  return 'Could not upload the image. Try again.';
}
