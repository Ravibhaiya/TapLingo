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

  /// Injects JS that keeps retrying `scrollTo(targetY)` whenever images load
  /// or the DOM mutates, until the page is tall enough and we've settled at
  /// the target position — or a 15-second timeout is hit.
  static String scrollWithImageWait(double y) => '''
(function() {
  var TARGET = $y;
  var settled = 0;
  var maxTime = 15000;
  var start = Date.now();
  var done = false;

  function tryScroll() {
    if (done) return;
    if (Date.now() - start > maxTime) { done = true; return; }

    var docH = document.documentElement.scrollHeight;
    window.scrollTo({ top: TARGET, left: 0, behavior: "auto" });

    // Check if we actually reached the target (or close enough)
    var actual = window.scrollY || window.pageYOffset || 0;
    if (Math.abs(actual - TARGET) < 5) {
      settled++;
      // Wait for 2 consecutive checks to confirm layout is stable
      if (settled >= 2) { done = true; return; }
    } else {
      settled = 0;
    }
  }

  // Initial attempt
  tryScroll();

  // Watch for any DOM changes (lazy-loaded images inserted)
  var observer = new MutationObserver(function() {
    tryScroll();
  });
  observer.observe(document.body, { childList: true, subtree: true, attributes: true, attributeFilter: ["src", "data-src"] });

  // Listen for image load events (images that are already in DOM but loading)
  document.addEventListener("load", function(e) {
    if (e.target && e.target.tagName === "IMG") tryScroll();
  }, true);

  // Periodic retry as a safety net
  var interval = setInterval(function() {
    tryScroll();
    if (done) {
      clearInterval(interval);
      observer.disconnect();
    }
  }, 300);

  // Hard stop after maxTime
  setTimeout(function() {
    done = true;
    clearInterval(interval);
    observer.disconnect();
  }, maxTime);

  true;
})();
''';
}
