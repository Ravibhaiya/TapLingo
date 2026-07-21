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

/// Crops a specific normalized rectangle from the image.
/// [normalizedRect] coordinates are between 0.0 and 1.0.
Future<Uint8List?> cropSelectedRect({
  required Uint8List fullImageBytes,
  required ui.Rect normalizedRect,
}) async {
  final codec = await ui.instantiateImageCodec(fullImageBytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;

  final left = (normalizedRect.left * image.width).clamp(0, image.width - 1).round();
  final top = (normalizedRect.top * image.height).clamp(0, image.height - 1).round();
  final right = (normalizedRect.right * image.width).clamp(0, image.width).round();
  final bottom = (normalizedRect.bottom * image.height).clamp(0, image.height).round();

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

  final picture = recorder.endRecording();
  final cropped = await picture.toImage(w, h);
  final byteData = await cropped.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  cropped.dispose();
  return byteData?.buffer.asUint8List();
}

/// Downscale an image so its longest edge is at most [maxEdge] px,
/// re-encoded as PNG. Returns [bytes] unchanged if already small enough.
/// Manga is line-art, so PNG stays small while cutting Gemini input cost.
Future<Uint8List> downscaleImage(Uint8List bytes, {int maxEdge = 1568}) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;

  final longest = math.max(image.width, image.height);
  if (longest <= maxEdge) {
    image.dispose();
    return bytes;
  }

  final scale = maxEdge / longest;
  final w = (image.width * scale).round();
  final h = (image.height * scale).round();

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawImageRect(
    image,
    ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()..filterQuality = ui.FilterQuality.medium,
  );
  final picture = recorder.endRecording();
  final scaled = await picture.toImage(w, h);
  final byteData = await scaled.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  scaled.dispose();
  return byteData?.buffer.asUint8List() ?? bytes;
}
