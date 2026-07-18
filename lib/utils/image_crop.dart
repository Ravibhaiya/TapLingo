import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Crops a square region around [x],[y] (viewport CSS pixels) from a
/// full-page screenshot. [viewportWidth]/[viewportHeight] are CSS sizes;
/// the screenshot may be in device pixels (scaled by DPR).
Future<Uint8List?> cropAroundTap({
  required Uint8List fullImageBytes,
  required double x,
  required double y,
  required double viewportWidth,
  required double viewportHeight,
  int cropSize = 200,
}) async {
  final codec = await ui.instantiateImageCodec(fullImageBytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;

  final scaleX = image.width / viewportWidth;
  final scaleY = image.height / viewportHeight;

  final cx = (x * scaleX).round();
  final cy = (y * scaleY).round();
  final half = (cropSize * ((scaleX + scaleY) / 2) / 2).round().clamp(40, 400);

  final left = (cx - half).clamp(0, image.width - 1);
  final top = (cy - half).clamp(0, image.height - 1);
  final right = math.min(cx + half, image.width);
  final bottom = math.min(cy + half, image.height);
  final w = math.max(1, right - left);
  final h = math.max(1, bottom - top);

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final src = ui.Rect.fromLTWH(
    left.toDouble(),
    top.toDouble(),
    w.toDouble(),
    h.toDouble(),
  );
  final dst = ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
  canvas.drawImageRect(image, src, dst, ui.Paint());

  final localX = (cx - left).toDouble();
  final localY = (cy - top).toDouble();
  final markerRadius = math.max(6.0, w * 0.03);
  canvas.drawCircle(ui.Offset(localX, localY), markerRadius,
      ui.Paint()..color = const ui.Color(0xFFFF0000));
  canvas.drawCircle(ui.Offset(localX, localY), markerRadius,
      ui.Paint()
        ..color = const ui.Color(0xFFFFFFFF)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2);

  final picture = recorder.endRecording();
  final cropped = await picture.toImage(w, h);
  final byteData = await cropped.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  cropped.dispose();
  return byteData?.buffer.asUint8List();
}
