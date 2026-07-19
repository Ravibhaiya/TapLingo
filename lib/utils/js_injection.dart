import 'package:flutter/services.dart';

/// Loads novel/manga JS assets and provides scroll helpers.
class JsInjection {
  static String? _reader;

  static Future<String> readerTap() async {
    return _reader ??= await rootBundle.loadString('assets/js/reader_tap.js');
  }

  static const getScrollY =
      '((window.__tlgScrollResolver && window.__tlgScrollResolver.getY) ? window.__tlgScrollResolver.getY() : (window.scrollY || window.pageYOffset || document.documentElement.scrollTop || document.body.scrollTop || 0));';

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
  const maxTime = 25000;
  const start = Date.now();
  const STALL_LIMIT = 8;

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

  function forceLoadAllImages() {
    // 1. Convert native lazy images to eager
    document.querySelectorAll('img[loading="lazy"]').forEach(img => {
      img.loading = 'eager';
      img.removeAttribute('loading');
    });

    // 2. Resolve common lazy load data-attributes
    const lazyAttributes = [
      'data-src', 'data-lazy-src', 'data-original', 'bv-data-src', 
      'data-src-retina', 'lazy-src', 'data-srcset', 'bv-data-srcset'
    ];

    document.querySelectorAll('img, source').forEach(el => {
      let srcFound = false;
      let srcsetFound = false;

      // Check all attributes on this element
      for (let i = 0; i < el.attributes.length; i++) {
        const attr = el.attributes[i];
        const name = attr.name.toLowerCase();
        const value = attr.value;
        
        if (!value) continue;

        if (name === 'data-srcset' || name === 'bv-data-srcset' || name.includes('srcset')) {
          if (name !== 'srcset') {
            el.setAttribute('srcset', value);
            srcsetFound = true;
          }
        }
        
        if (name === 'data-src' || name === 'bv-data-src' || name === 'data-lazy-src' || name === 'data-original' || name.includes('src')) {
          if (name !== 'src' && name !== 'srcset') {
            el.setAttribute('src', value);
            srcFound = true;
          }
        }
      }

      // If the image is currently showing a tiny SVG placeholder, but has a src it hasn't loaded yet
      if (el.tagName === 'IMG' && el.src && el.src.startsWith('data:image/')) {
        const realSrc = el.getAttribute('data-src') || el.getAttribute('bv-data-src') || el.getAttribute('data-lazy-src');
        if (realSrc) {
          el.src = realSrc;
        }
      }
    });

    // 3. Trigger generic lazyload events
    window.dispatchEvent(new Event('scroll'));
    window.dispatchEvent(new Event('resize'));
  }

  let status = 'timeout';
  let stalls = 0;
  let targetStalls = 0;
  let currentScroll = 0;

  async function run() {
    try {
      disableAnchoring();
      // Force load lazy elements immediately to speed up restoration
      forceLoadAllImages();

      while (Date.now() - start < maxTime) {
        const currentHeight = getScrollHeight();
        const viewportHeight = isWindow ? window.innerHeight : container.clientHeight;
        const maxScroll = currentHeight - viewportHeight;

        // Verify/scroll to target
        if (maxScroll >= TARGET) {
          scrollTo(TARGET);
          
          // Wait and verify if the page height is still growing (images loading above us)
          const stepStart = Date.now();
          let grew = false;
          while (Date.now() - stepStart < 800) {
            await new Promise(r => setTimeout(r, 100));
            if (getScrollHeight() > currentHeight) {
              grew = true;
              break;
            }
          }

          if (grew) {
            targetStalls = 0;
            continue; // Re-clamp to TARGET in the next loop
          } else {
            targetStalls++;
            // If height is stable for ~1.6 seconds (2 checks), we're done
            if (targetStalls >= 2) {
              if (Math.abs(getScrollY() - TARGET) < 10) {
                status = 'reached';
              } else {
                status = 'end-of-content';
              }
              break;
            }
            continue;
          }
        }

        // Scroll incrementally to trigger lazy loading along the way
        currentScroll = Math.min(currentScroll + 1000, maxScroll);
        scrollTo(currentScroll);

        // Wait for page to grow
        const stepStart = Date.now();
        let grew = false;
        while (Date.now() - stepStart < 600) {
          await new Promise(r => setTimeout(r, 100));
          if (getScrollHeight() > currentHeight) {
            grew = true;
            break;
          }
        }

        if (grew) {
          stalls = 0;
        } else {
          if (currentScroll >= maxScroll) {
            stalls++;
            if (stalls >= STALL_LIMIT) {
              scrollTo(TARGET); // Final clamp scroll
              status = 'end-of-content';
              break;
            }
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
