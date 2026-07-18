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

  static const getScrollY =
      '((window.__tlgScrollResolver && window.__tlgScrollResolver.getY) ? window.__tlgScrollResolver.getY() : (window.scrollY || window.pageYOffset || 0));';

  static String scrollToY(double y) =>
      '(function() { '
      'const resolver = window.__tlgScrollResolver; '
      'const container = resolver ? resolver.getContainer() : (document.scrollingElement || document.documentElement || document.body); '
      'const isWindow = resolver ? resolver.isWindow(container) : true; '
      'if (isWindow) { window.scrollTo({ top: $y, left: 0, behavior: "auto" }); } '
      'else { if (typeof container.scrollTo === "function") { container.scrollTo({ top: $y, left: 0, behavior: "auto" }); } else { container.scrollTop = $y; } } '
      'return true; '
      '})();';

  /// Injects JS that keeps retrying `scrollTo(targetY)` whenever images load
  /// or the DOM mutates, until the page is tall enough and we've settled at
  /// the target position — or a 15-second timeout is hit.
  static String scrollWithImageWait(double y) => '''
(function() {
  const TARGET = $y;
  const maxTime = 15000;
  const start = Date.now();
  const STEP_TIMEOUT = 2500;
  const STALL_LIMIT = 2;

  const resolver = window.__tlgScrollResolver;
  const container = resolver ? resolver.getContainer() : (document.scrollingElement || document.documentElement || document.body);
  const isWindow = resolver ? resolver.isWindow(container) : true;

  function getScrollHeight() {
    return isWindow 
      ? Math.max(document.documentElement.scrollHeight, document.body.scrollHeight)
      : container.scrollHeight;
  }

  function getScrollY() {
    return isWindow 
      ? (window.scrollY || window.pageYOffset || 0)
      : container.scrollTop;
  }

  function scrollTo(y) {
    if (isWindow) {
      window.scrollTo({ top: y, left: 0, behavior: 'auto' });
    } else {
      if (typeof container.scrollTo === 'function') {
        container.scrollTo({ top: y, left: 0, behavior: 'auto' });
      } else {
        container.scrollTop = y;
      }
    }
  }

  function disableAnchoring() {
    if (isWindow) {
      document.documentElement.style.overflowAnchor = 'none';
      document.body.style.overflowAnchor = 'none';
    } else {
      container.style.overflowAnchor = 'none';
    }
  }

  function enableAnchoring() {
    if (isWindow) {
      document.documentElement.style.overflowAnchor = '';
      document.body.style.overflowAnchor = '';
    } else {
      container.style.overflowAnchor = '';
    }
  }

  let status = 'timeout';
  let stalls = 0;

  async function run() {
    try {
      disableAnchoring();

      while (Date.now() - start < maxTime) {
        const currentHeight = getScrollHeight();
        const viewportHeight = isWindow ? window.innerHeight : container.clientHeight;
        const maxScroll = currentHeight - viewportHeight;

        // Verify/scroll to target
        if (maxScroll >= TARGET) {
          scrollTo(TARGET);
          await new Promise(r => setTimeout(r, 100));
          if (Math.abs(getScrollY() - TARGET) < 10) {
            status = 'reached';
            break;
          }
          continue; // Retry target, do not overshoot to maxScroll
        }

        // Scroll to current bottom to trigger lazy loading
        scrollTo(maxScroll);

        // Wait for page to grow
        const stepStart = Date.now();
        let grew = false;
        while (Date.now() - stepStart < STEP_TIMEOUT) {
          await new Promise(r => setTimeout(r, 100));
          if (getScrollHeight() > currentHeight) {
            grew = true;
            break;
          }
        }

        if (grew) {
          stalls = 0;
        } else {
          stalls++;
          if (stalls >= STALL_LIMIT) {
            scrollTo(TARGET); // Final clamp scroll
            status = 'end-of-content';
            break;
          }
        }
      }
    } finally {
      enableAnchoring();
      // Report status back to Flutter channel
      if (window.TapLingoChannel) {
        window.TapLingoChannel.postMessage(JSON.stringify({
          type: 'scrollRestoration',
          status: status
        }));
      }
    }
  }

  run();
  true;
})();
''';
}
