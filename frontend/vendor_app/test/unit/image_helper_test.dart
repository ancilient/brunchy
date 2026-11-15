// test/unit/image_helper_test.dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:brunchy_vendor/core/utils/image_helper.dart';

void main() {
  group('ImageHelper Unit Tests', () {
    test('compressImageBytesToWebP compresses PNG to WebP under 150KB', () {
      // Create a test image (500x500)
      final image = img.Image(width: 500, height: 500);
      img.fill(image, color: img.ColorRgb8(255, 100, 50));
      for (int x = 0; x < 500; x += 10) {
        img.drawLine(image, x1: x, y1: 0, x2: x, y2: 499, color: img.ColorRgb8(0, 200, 150));
      }
      final pngBytes = img.encodePng(image);

      final webpBytes = ImageHelper.compressImageBytesToWebP(pngBytes);

      expect(webpBytes, isNotNull);
      expect(webpBytes.lengthInBytes, lessThanOrEqualTo(150 * 1024));

      // Verify it's a valid WebP image by decoding it
      final decodedWebp = img.decodeWebP(webpBytes);
      expect(decodedWebp, isNotNull);
      expect(decodedWebp!.width, equals(500));
      expect(decodedWebp.height, equals(500));
    });

    test('compressImageBytesToWebP downscales and compresses large 2500x2500 image under 150KB', () {
      final largeImage = img.Image(width: 2500, height: 2500);
      img.fill(largeImage, color: img.ColorRgb8(30, 90, 200));
      for (int i = 0; i < 2500; i += 20) {
        img.drawCircle(largeImage, x: i, y: i, radius: 10, color: img.ColorRgb8(250, 200, 50));
      }
      final jpegBytes = img.encodeJpg(largeImage, quality: 90);

      final webpBytes = ImageHelper.compressImageBytesToWebP(jpegBytes);

      expect(webpBytes, isNotNull);
      expect(webpBytes.lengthInBytes, lessThanOrEqualTo(150 * 1024));

      final decodedWebp = img.decodeWebP(webpBytes);
      expect(decodedWebp, isNotNull);
      // Ensure it was downscaled from 2500 to at most 1024
      expect(decodedWebp!.width, lessThanOrEqualTo(1024));
      expect(decodedWebp.height, lessThanOrEqualTo(1024));
    });

    test('compressImageBytesToWebP throws FormatException on invalid image bytes', () {
      final invalidBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9]);

      expect(
        () => ImageHelper.compressImageBytesToWebP(invalidBytes),
        throwsA(isA<FormatException>()),
      );
    });

    test('CompressedImageResult formats sizeInKb correctly', () {
      final result = CompressedImageResult(
        path: '/tmp/test.webp',
        bytes: Uint8List(86016), // 84 KB = 86016 bytes
        sizeInBytes: 86016,
      );

      expect(result.sizeInKb, equals(84));
    });
  });
}
