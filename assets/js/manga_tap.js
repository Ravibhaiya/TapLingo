(function() {
  if (window.__tlgMangaInstalled) return;
  window.__tlgMangaInstalled = true;

  var holdTimer = null;
  var touchStartX = 0;
  var touchStartY = 0;
  var longPressTriggered = false;

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

  function startHold(e) {
    longPressTriggered = false;
    var x = e.touches ? e.touches[0].clientX : e.clientX;
    var y = e.touches ? e.touches[0].clientY : e.clientY;
    var img = findImageAt(x, y);
    if (!img) return;
    
    touchStartX = x;
    touchStartY = y;
    
    clearTimeout(holdTimer);
    holdTimer = setTimeout(function() {
      longPressTriggered = true;
      triggerMeaning(touchStartX, touchStartY, 3);
    }, 500);
  }

  function cancelHold() {
    clearTimeout(holdTimer);
  }

  function checkMove(e) {
    if (!holdTimer) return;
    var x = e.touches ? e.touches[0].clientX : e.clientX;
    var y = e.touches ? e.touches[0].clientY : e.clientY;
    var dx = x - touchStartX;
    var dy = y - touchStartY;
    if (Math.abs(dx) > 10 || Math.abs(dy) > 10) {
      cancelHold();
    }
  }

  document.addEventListener('touchstart', startHold, { passive: true });
  document.addEventListener('mousedown', function(e) {
    if (e.touches) return;
    startHold(e);
  }, { passive: true });

  document.addEventListener('touchmove', checkMove, { passive: true });
  document.addEventListener('mousemove', checkMove, { passive: true });

  document.addEventListener('touchend', cancelHold, { passive: true });
  document.addEventListener('mouseup', cancelHold, { passive: true });
  document.addEventListener('touchcancel', cancelHold, { passive: true });

  document.addEventListener('click', function(e) {
    if (longPressTriggered) {
      longPressTriggered = false;
      return;
    }
    triggerMeaning(e.clientX, e.clientY, 1);
  }, true);

  document.addEventListener('contextmenu', function(e) {
    if (findImageAt(e.clientX, e.clientY)) {
      e.preventDefault();
    }
  });

})();
