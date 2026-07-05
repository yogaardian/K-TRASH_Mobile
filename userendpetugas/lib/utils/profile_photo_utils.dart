import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

ImageProvider? buildProfileImageProvider(String? photoValue) {
  if (photoValue == null || photoValue.trim().isEmpty) {
    return null;
  }

  final value = photoValue.trim();

  if (value.startsWith('http://') || value.startsWith('https://')) {
    return NetworkImage(value);
  }

  if (value.startsWith('data:')) {
    final separatorIndex = value.indexOf(',');
    if (separatorIndex == -1) {
      return null;
    }

    final encodedValue = value.substring(separatorIndex + 1).trim();
    if (encodedValue.isEmpty) {
      return null;
    }

    try {
      return MemoryImage(base64Decode(encodedValue));
    } catch (_) {
      return null;
    }
  }

  try {
    return MemoryImage(base64Decode(value));
  } catch (_) {
    return null;
  }
}
