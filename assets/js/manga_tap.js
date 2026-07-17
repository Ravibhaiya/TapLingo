(function() {
  if (window.__tlgMangaInstalled) return;
  window.__tlgMangaInstalled = true;

  var tapCount = 0;
  var tapTimer = null;
  var lastX = 0, lastY = 0;

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

  document.addEventListener('click', function(e) {
    lastX = e.clientX;
    lastY = e.clientY;
    tapCount++;
    clearTimeout(tapTimer);
    tapTimer = setTimeout(function() {
      var taps = tapCount >= 3 ? 3 : (tapCount >= 2 ? 2 : 1);
      tapCount = 0;
      if (taps < 2) return;

      var img = findImageAt(lastX, lastY);
      var payload = {
        word: null,
        sentence: null,
        taps: taps,
        x: lastX,
        y: lastY,
        vw: window.innerWidth,
        vh: window.innerHeight,
        dpr: window.devicePixelRatio || 1
      };

      if (img) {
        var rect = img.getBoundingClientRect();
        payload.imageSrc = img.currentSrc || img.src || null;
        payload.imgLeft = rect.left;
        payload.imgTop = rect.top;
        payload.imgWidth = rect.width;
        payload.imgHeight = rect.height;
        payload.naturalWidth = img.naturalWidth || rect.width;
        payload.naturalHeight = img.naturalHeight || rect.height;
        payload.relX = lastX - rect.left;
        payload.relY = lastY - rect.top;
      }

      if (window.TapLingoChannel) {
        TapLingoChannel.postMessage(JSON.stringify(payload));
      }
    }, 300);
  }, true);
})();
