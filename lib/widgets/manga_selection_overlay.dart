import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';

class MangaSelectionOverlay extends StatefulWidget {
  final Uint8List imageBytes;
  final double viewportWidth;
  final double viewportHeight;

  const MangaSelectionOverlay({
    super.key,
    required this.imageBytes,
    required this.viewportWidth,
    required this.viewportHeight,
  });

  @override
  State<MangaSelectionOverlay> createState() => _MangaSelectionOverlayState();
}

class _MangaSelectionOverlayState extends State<MangaSelectionOverlay> {
  Offset? _startPoint;
  Offset? _currentPoint;
  double _displayW = 1.0;
  double _displayH = 1.0;

  Rect? get _selectionRect {
    if (_startPoint == null || _currentPoint == null) return null;
    return Rect.fromPoints(_startPoint!, _currentPoint!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Draw a box around the dialogue to translate',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final scaleX = constraints.maxWidth / widget.viewportWidth;
                    final scaleY = constraints.maxHeight / widget.viewportHeight;
                    final scale = math.min(scaleX, scaleY);
                    
                    _displayW = widget.viewportWidth * scale;
                    _displayH = widget.viewportHeight * scale;

                    return GestureDetector(
                      onPanStart: (details) {
                        setState(() {
                          _startPoint = details.localPosition;
                          _currentPoint = details.localPosition;
                        });
                      },
                      onPanUpdate: (details) {
                        setState(() {
                          final clamped = Offset(
                            details.localPosition.dx.clamp(0, _displayW),
                            details.localPosition.dy.clamp(0, _displayH),
                          );
                          _currentPoint = clamped;
                        });
                      },
                      onPanEnd: (_) {},
                      child: SizedBox(
                        width: _displayW,
                        height: _displayH,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.memory(
                              widget.imageBytes,
                              fit: BoxFit.contain,
                            ),
                            if (_selectionRect != null)
                              CustomPaint(
                                painter: _SelectionPainter(
                                  rect: _selectionRect!,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Container(
              color: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                    label: const Text('Cancel', style: TextStyle(color: Colors.white)),
                  ),
                  ElevatedButton.icon(
                    onPressed: _selectionRect == null
                        ? null
                        : () {
                            final rect = _selectionRect!;
                            // Return normalized rect (0.0 to 1.0)
                            final normalizedRect = Rect.fromLTRB(
                              rect.left / _displayW,
                              rect.top / _displayH,
                              rect.right / _displayW,
                              rect.bottom / _displayH,
                            );
                            Navigator.of(context).pop(normalizedRect);
                          },
                    icon: const Icon(Icons.translate),
                    label: const Text('Translate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionPainter extends CustomPainter {
  final Rect rect;

  _SelectionPainter({required this.rect});

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = Colors.black54;
    
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, backgroundPaint);
    canvas.drawRect(rect, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(rect, borderPaint);
    
    final handlePaint = Paint()..color = Colors.blue;
    final handleSize = 8.0;
    for (final point in [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ]) {
      canvas.drawRect(
        Rect.fromCenter(center: point, width: handleSize, height: handleSize),
        handlePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SelectionPainter oldDelegate) {
    return oldDelegate.rect != rect;
  }
}
