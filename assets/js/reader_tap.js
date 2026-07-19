(function() {
  if (window.__tlgInstalled) return;
  window.__tlgInstalled = true;

  /* ── Scroll Resolver (For scroll restoration) ── */
  function getScrollContainer() {
    const defaultContainer = document.scrollingElement || document.documentElement || document.body;
    const candidates = [];
    const elList = document.querySelectorAll('main, [class*="read"], [class*="chapter"], [class*="manga"], [id*="read"], [id*="chapter"]');
    elList.forEach(el => {
      if (el === document.documentElement || el === document.body) return;
      const style = window.getComputedStyle(el);
      if (style.overflowY !== 'auto' && style.overflowY !== 'scroll') return;
      const r = el.getBoundingClientRect();
      if (r.height < window.innerHeight * 0.6) return;
      if (el.scrollHeight <= el.clientHeight + 50) return;
      candidates.push(el);
    });
    if (candidates.length > 0) {
      candidates.sort((a, b) => (b.scrollHeight - b.clientHeight) - (a.scrollHeight - a.clientHeight));
      return candidates[0];
    }
    const fallbacks = document.querySelectorAll('div, section, article');
    fallbacks.forEach(el => {
      if (el === document.documentElement || el === document.body) return;
      const style = window.getComputedStyle(el);
      if (style.overflowY !== 'auto' && style.overflowY !== 'scroll') return;
      const r = el.getBoundingClientRect();
      if (r.height < window.innerHeight * 0.6) return;
      if (el.scrollHeight <= el.clientHeight + 50) return;
      candidates.push(el);
    });
    if (candidates.length > 0) {
      candidates.sort((a, b) => (b.scrollHeight - b.clientHeight) - (a.scrollHeight - a.clientHeight));
      return candidates[0];
    }
    return defaultContainer;
  }

  window.__tlgScrollResolver = {
    getContainer: getScrollContainer,
    isWindow: function(container) {
      return container === document.documentElement || container === document.body || container === window;
    },
    getY: function() {
      const container = getScrollContainer();
      const isWin = container === document.documentElement || container === document.body || container === window;
      return isWin ? (window.scrollY || window.pageYOffset || 0) : container.scrollTop;
    }
  };

  /* ── CSS Injection for Text Highlights ── */
  var style = document.createElement('style');
  style.textContent = '.tlg-word { cursor: pointer; -webkit-tap-highlight-color: rgba(232,168,56,0.35); } .tlg-word.tlg-hl { background: rgba(232,168,56,0.35); border-radius: 2px; }';
  document.head.appendChild(style);

  /* ── Word wrapping for text ── */
  function wrapWords(root) {
    var paragraphs = root.querySelectorAll('p, article, .chapter-content, .content, .entry-content, .text-left, .novel-content, #content, .page-content');
    if (!paragraphs.length) {
      paragraphs = root.querySelectorAll('div');
    }
    paragraphs.forEach(function(p) {
      if (p.dataset.tlgWrapped) return;
      if ((p.innerText || '').trim().length < 20) return;
      if (p.querySelector('img, video, iframe, script, style, .tlg-word')) return;

      var walker = document.createTreeWalker(p, NodeFilter.SHOW_TEXT, null);
      var textNodes = [];
      while (walker.nextNode()) textNodes.push(walker.currentNode);

      textNodes.forEach(function(node) {
        var text = node.nodeValue;
        if (!text || !/\w/.test(text)) return;
        var frag = document.createDocumentFragment();
        var re = /(\b[\w']+\b)/g;
        var last = 0, m;
        while ((m = re.exec(text)) !== null) {
          if (m.index > last) {
            frag.appendChild(document.createTextNode(text.slice(last, m.index)));
          }
          var span = document.createElement('span');
          span.className = 'tlg-word';
          span.textContent = m[1];
          frag.appendChild(span);
          last = m.index + m[1].length;
        }
        if (last < text.length) {
          frag.appendChild(document.createTextNode(text.slice(last)));
        }
        if (frag.childNodes.length) {
          node.parentNode.replaceChild(frag, node);
        }
      });
      p.dataset.tlgWrapped = '1';
    });
  }

  // Prevent selection/context menu on wrapped words
  document.querySelectorAll('*').forEach(function(el) {
    try {
      el.style.userSelect = 'none';
      el.style.webkitUserSelect = 'none';
      el.style.webkitTouchCallout = 'none';
    } catch (e) {}
  });
  document.oncontextmenu = null;
  document.onselectstart = null;
  document.oncopy = null;

  wrapWords(document.body);

  var observer = new MutationObserver(function(mutations) {
    mutations.forEach(function(mu) {
      mu.addedNodes.forEach(function(n) {
        if (n.nodeType === 1) wrapWords(n);
      });
    });
  });
  observer.observe(document.body, { childList: true, subtree: true });

  /* ── Image Detection Helper ── */
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

  /* ── Action Triggers ── */
  function triggerTextMeaning(span, taps) {
    var block = span.closest('p, div, li, article, section') || span.parentElement;
    var sentence = (block && block.innerText) ? block.innerText.trim() : span.innerText;
    try {
      var full = sentence;
      var idx = full.indexOf(span.innerText);
      if (idx >= 0) {
        var start = Math.max(0, full.lastIndexOf('.', idx - 1) + 1);
        var endDot = full.indexOf('.', idx + span.innerText.length);
        var end = endDot >= 0 ? endDot + 1 : full.length;
        var tighter = full.slice(start, end).trim();
        if (tighter.length > 0) sentence = tighter;
      }
    } catch (err) {}

    span.classList.add('tlg-hl');
    if (window.TapLingoChannel) {
      window.TapLingoChannel.postMessage(JSON.stringify({
        word: span.innerText,
        sentence: sentence,
        taps: taps
      }));
    }
    setTimeout(function() { span.classList.remove('tlg-hl'); }, 600);
  }

  function triggerImageMeaning(img, x, y, taps) {
    var rect = img.getBoundingClientRect();
    var payload = {
      word: null,
      sentence: null,
      taps: taps,
      x: x,
      y: y,
      vw: window.innerWidth,
      vh: window.innerHeight,
      dpr: window.devicePixelRatio || 1,
      imageSrc: img.currentSrc || img.src || null,
      imgLeft: rect.left,
      imgTop: rect.top,
      imgWidth: rect.width,
      imgHeight: rect.height,
      naturalWidth: img.naturalWidth || rect.width,
      naturalHeight: img.naturalHeight || rect.height,
      relX: x - rect.left,
      relY: y - rect.top
    };

    if (window.TapLingoChannel) {
      window.TapLingoChannel.postMessage(JSON.stringify(payload));
    }
  }

  /* ── Gesture state ── */
  var holdTimer = null;
  var touchStartX = 0;
  var touchStartY = 0;
  var activeElement = null; // Can be a span or an img
  var isImg = false;
  var gestureFired = false;
  var gestureActive = false;
  var isScrolling = false;

  function cancelGesture() {
    clearTimeout(holdTimer);
    holdTimer = null;
    gestureActive = false;
    activeElement = null;
  }

  function onTouchStart(e) {
    if (e.touches && e.touches.length > 1) {
      cancelGesture();
      return;
    }
    cancelGesture();
    gestureFired = false;
    isScrolling = false;

    var t = e.touches ? e.touches[0] : e;
    var x = t.clientX;
    var y = t.clientY;

    // Check if we hit a text span first
    var target = document.elementFromPoint(x, y);
    var span = target && target.closest && target.closest('.tlg-word');
    
    if (span) {
      activeElement = span;
      isImg = false;
    } else {
      // Check if we hit an image
      var img = findImageAt(x, y);
      if (img) {
        activeElement = img;
        isImg = true;
      } else {
        return; // Clicked blank space
      }
    }

    touchStartX = x;
    touchStartY = y;
    gestureActive = true;

    holdTimer = setTimeout(function() {
      if (!gestureActive || isScrolling || !activeElement) return;
      gestureFired = true;
      if (isImg) {
        triggerImageMeaning(activeElement, touchStartX, touchStartY, 3);
      } else {
        triggerTextMeaning(activeElement, 3);
      }
      cancelGesture();
    }, 500);
  }

  function onMove(e) {
    if (!gestureActive) return;
    if (e.touches && e.touches.length > 1) {
      cancelGesture();
      return;
    }
    var t = e.touches ? e.touches[0] : e;
    var dx = t.clientX - touchStartX;
    var dy = t.clientY - touchStartY;
    if (Math.abs(dx) > 5 || Math.abs(dy) > 5) {
      isScrolling = true;
      cancelGesture();
    }
  }

  function onEnd() {
    if (!gestureActive || !activeElement) return;
    clearTimeout(holdTimer);
    holdTimer = null;
    
    if (!isScrolling && !gestureFired) {
      if (isImg) {
        triggerImageMeaning(activeElement, touchStartX, touchStartY, 1);
      } else {
        triggerTextMeaning(activeElement, 1);
      }
    }
    
    cancelGesture();
  }

  var isTouch = false;

  document.addEventListener('touchstart', function(e) {
    isTouch = true;
    onTouchStart(e);
  }, { passive: true });
  document.addEventListener('mousedown', function(e) {
    if (isTouch) return;
    onTouchStart(e);
  }, { passive: true });

  document.addEventListener('touchmove', onMove, { passive: true });
  document.addEventListener('mousemove', function(e) {
    if (isTouch) return;
    onMove(e);
  }, { passive: true });

  document.addEventListener('touchend', onEnd, { passive: true });
  document.addEventListener('mouseup', function(e) {
    if (isTouch) return;
    onEnd(e);
  }, { passive: true });
  document.addEventListener('touchcancel', function() { cancelGesture(); }, { passive: true });

  var scrollReportTimer = null;
  window.addEventListener('scroll', function(e) {
    isScrolling = true;
    cancelGesture();
    
    clearTimeout(scrollReportTimer);
    scrollReportTimer = setTimeout(function() {
      if (window.__tlgScrollResolver && window.TapLingoChannel) {
        window.TapLingoChannel.postMessage(JSON.stringify({
          type: 'scrollPosition',
          y: window.__tlgScrollResolver.getY(),
          url: window.location.href
        }));
      }
    }, 1000);
  }, { passive: true, capture: true });

  // Suppress context menu for images
  document.addEventListener('contextmenu', function(e) {
    if (findImageAt(e.clientX, e.clientY)) {
      e.preventDefault();
    }
  });

  // Suppress clicks on words so they don't trigger native events
  document.addEventListener('click', function(e) {
    if (gestureFired) {
      gestureFired = false;
      e.preventDefault();
      e.stopPropagation();
      return;
    }
    var span = e.target.closest && e.target.closest('.tlg-word');
    if (span) {
      e.preventDefault();
      e.stopPropagation();
    }
  }, true);

})();
