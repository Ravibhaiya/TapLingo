import 'package:flutter/services.dart';

/// Loads novel/manga JS assets and provides scroll helpers.
class JsInjection {
  static String? _novel;
  static String? _manga;

  static Future<String> novelTap() async {
    return _novel ??= await rootBundle.loadString('assets/js/novel_tap.js');
  }

  static Future<String> mangaTap() async {
    return _manga ??= await rootBundle.loadString('assets/js/manga_tap.js');
  }

  static const getScrollY = 'window.scrollY || window.pageYOffset || 0;';

  static String scrollToY(double y) =>
      'window.scrollTo({ top: $y, left: 0, behavior: "auto" }); true;';
}
