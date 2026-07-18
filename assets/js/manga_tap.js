(function() {
  if (window.__tlgMangaInstalled) return;
  window.__tlgMangaInstalled = true;

  /* ── Gesture state ── */
  var tapTimer = null;     // fires at ~200ms → single-tap (word)
  var holdTimer = null;    // fires at ~500ms → long-press (sentence)
  var touchStartX = 0;
  var touchStartY = 0;
  var gestureFired = false;
  var gestureActive = false; // true while a touchstart is being tracked

  function findImageAt(x, y) {
    var el = document.elementFromPoint(x, y);
    if (!el) return null;
    if (el.tagName === 'IMG') return el;
    var img = el.closest && el.closest('img');
    if (img) return img;
    var node = el;
    for (var i = 0; i < 6 && node; i++) {
      if (node.tagName === 'IMG') return node;
      var nested = node.querySelector && node.querySelector('img');
      if (nested) {
        var r = nested.getBoundingClientRect();
        if (x >= r.left && x <= r.right && y >= r.top && y <= r.bottom) return nested;
      }
      node = node.parentElement;
    }
    var imgs = Array.prototype.slice.call(document.images || []);
    var best = null, bestArea = 0;
    imgs.forEach(function(im) {
      var r = im.getBoundingClientRect();
      if (r.width < 80 || r.height < 80) return;
      if (x < r.left - 20 || x > r.right + 20 || y < r.top - 20 || y > r.bottom + 20) return;
      var area = r.width * r.height;
      if (area > bestArea) { bestArea = area; best = im; }
    });
    return best;
  }

  function triggerMeaning(x, y, taps) {
    var img = findImageAt(x, y);
    if (!img) return;

    var payload = {
      word: null,
      sentence: null,
      taps: taps,
      x: x,
      y: y,
      vw: window.innerWidth,
      vh: window.innerHeight,
      dpr: window.devicePixelRatio || 1
    };

    var rect = img.getBoundingClientRect();
    payload.imageSrc = img.currentSrc || img.src || null;
    payload.imgLeft = rect.left;
    payload.imgTop = rect.top;
    payload.imgWidth = rect.width;
    payload.imgHeight = rect.height;
    payload.naturalWidth = img.naturalWidth || rect.width;
    payload.naturalHeight = img.naturalHeight || rect.height;
    payload.relX = x - rect.left;
    payload.relY = y - rect.top;

    if (window.TapLingoChannel) {
      TapLingoChannel.postMessage(JSON.stringify(payload));
    }
  }

  function cancelGesture() {
    clearTimeout(tapTimer);
    clearTimeout(holdTimer);
    tapTimer = null;
    holdTimer = null;
    gestureActive = false;
  }

  function onTouchStart(e) {
    cancelGesture();
    gestureFired = false;

    var t = e.touches ? e.touches[0] : e;
    var x = t.clientX;
    var y = t.clientY;

    // Only track if there's an image under the finger
    var img = findImageAt(x, y);
    if (!img) return;

    touchStartX = x;
    touchStartY = y;
    gestureActive = true;

    // Single-tap fires after 200ms if finger hasn't moved
    tapTimer = setTimeout(function() {
      if (!gestureActive) return;
      gestureFired = true;
      triggerMeaning(touchStartX, touchStartY, 1);
      clearTimeout(holdTimer);
      holdTimer = null;
      gestureActive = false;
    }, 200);

    // Long-press fires after 500ms (overrides single-tap)
    holdTimer = setTimeout(function() {
      if (!gestureActive) return;
      gestureFired = true;
      clearTimeout(tapTimer);
      tapTimer = null;
      triggerMeaning(touchStartX, touchStartY, 3);
      gestureActive = false;
    }, 500);
  }

  function onMove(e) {
    if (!gestureActive) return;
    var t = e.touches ? e.touches[0] : e;
    var dx = t.clientX - touchStartX;
    var dy = t.clientY - touchStartY;
    if (Math.abs(dx) > 10 || Math.abs(dy) > 10) {
      cancelGesture();
    }
  }

  function onEnd() {
    // Finger lifted — cancel long-press timer.
    // If single-tap timer is still pending (< 200ms touch), let it fire
    // so fast deliberate taps still work.
    clearTimeout(holdTimer);
    holdTimer = null;
  }

  document.addEventListener('touchstart', onTouchStart, { passive: true });
  document.addEventListener('mousedown', function(e) {
    if (e.touches) return;
    onTouchStart(e);
  }, { passive: true });

  document.addEventListener('touchmove', onMove, { passive: true });
  document.addEventListener('mousemove', onMove, { passive: true });

  document.addEventListener('touchend', onEnd, { passive: true });
  document.addEventListener('mouseup', onEnd, { passive: true });
  document.addEventListener('touchcancel', function() { cancelGesture(); }, { passive: true });

  // Suppress the synthetic click so it doesn't navigate or double-fire
  document.addEventListener('click', function(e) {
    if (gestureFired) {
      gestureFired = false;
      e.preventDefault();
      e.stopPropagation();
    }
  }, true);

  document.addEventListener('contextmenu', function(e) {
    if (findImageAt(e.clientX, e.clientY)) {
      e.preventDefault();
    }
  });

})();
