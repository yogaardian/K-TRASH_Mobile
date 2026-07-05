import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user/utils/profile_photo_utils.dart';

void main() {
  group('buildProfileImageProvider', () {
    test('parses raw base64 strings into a memory image provider', () {
      final provider = buildProfileImageProvider(base64Encode([1, 2, 3, 4]));

      expect(provider, isA<MemoryImage>());
    });

    test('parses data:image URIs into a memory image provider', () {
      final provider = buildProfileImageProvider('data:image/png;base64,AAECAw==');

      expect(provider, isA<MemoryImage>());
    });

    test('parses remote image URLs into a network image provider', () {
      final provider = buildProfileImageProvider('https://example.com/avatar.png');

      expect(provider, isA<NetworkImage>());
    });

    test('returns null for invalid photo values', () {
      expect(buildProfileImageProvider('not-a-valid-photo'), isNull);
      expect(buildProfileImageProvider(null), isNull);
    });
  });
}
