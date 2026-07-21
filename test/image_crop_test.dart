import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:taplingo/utils/image_crop.dart';

Future<Uint8List> createTestPng(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF00FF00),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return byteData!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Image Crop & Downscale Utility Tests', () {
    test('downscaleImage returns original bytes if longest edge <= maxEdge', () async {
      final pngBytes = await createTestPng(100, 100);
      final result = await downscaleImage(pngBytes, maxEdge: 1568);

      expect(result.length, pngBytes.length);
    });

    test('downscaleImage resizes image when longest edge > maxEdge', () async {
      // 2000px width > 500px maxEdge constraint
      final pngBytes = await createTestPng(600, 400);
      final result = await downscaleImage(pngBytes, maxEdge: 300);

      expect(result, isNotNull);
      final codec = await ui.instantiateImageCodec(result);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      expect(image.width, 300);
      expect(image.height, 200);
      image.dispose();
    });

    test('cropAroundTap produces a valid cropped region byte array', () async {
      final pngBytes = await createTestPng(500, 500);
      final cropped = await cropAroundTap(
        fullImageBytes: pngBytes,
        x: 250,
        y: 250,
        viewportWidth: 500,
        viewportHeight: 500,
        cropSize: 100,
      );

      expect(cropped, isNotNull);
      expect(cropped!.isNotEmpty, isTrue);
    });

    test('cropSelectedRect crops specific normalized rectangle', () async {
      final pngBytes = await createTestPng(400, 400);
      final cropped = await cropSelectedRect(
        fullImageBytes: pngBytes,
        normalizedRect: const ui.Rect.fromLTRB(0.1, 0.1, 0.5, 0.5),
      );

      expect(cropped, isNotNull);
      final codec = await ui.instantiateImageCodec(cropped!);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // 0.4 * 400 = 160px
      expect(image.width, 160);
      expect(image.height, 160);
      image.dispose();
    });
  });
}
