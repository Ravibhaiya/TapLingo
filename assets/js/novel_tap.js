(function() {
  if (window.__tlgInstalled) return;
  window.__tlgInstalled = true;

  function getScrollContainer() {
    const defaultContainer = document.scrollingElement || document.documentElement || document.body;
    const candidates = [];
    
    // High probability selectors first (without bare tags like div, section, article)
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
    
    // Fallback to div, section, article only if the scoped selectors didn't match
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

  var style = document.createElement('style');
  style.textContent = '.tlg-word { cursor: pointer; -webkit-tap-highlight-color: rgba(232,168,56,0.35); } .tlg-word.tlg-hl { background: rgba(232,168,56,0.35); border-radius: 2px; }';
  document.head.appendChild(style);

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

  wrapWords(document.body);

  var observer = new MutationObserver(function(mutations) {
    mutations.forEach(function(mu) {
      mu.addedNodes.forEach(function(n) {
        if (n.nodeType === 1) wrapWords(n);
      });
    });
  });
  observer.observe(document.body, { childList: true, subtree: true });

  /* ── Gesture state ── */
  var holdTimer = null;    // fires at ~500ms → long-press (sentence)
  var touchStartX = 0;
  var touchStartY = 0;
  var gestureSpan = null;  // the .tlg-word under the finger
  var gestureFired = false; // true if hold fired
  var isScrolling = false;

  function triggerMeaning(span, taps) {
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
      TapLingoChannel.postMessage(JSON.stringify({
        word: span.innerText,
        sentence: sentence,
        taps: taps
      }));
    }
    setTimeout(function() { span.classList.remove('tlg-hl'); }, 600);
  }

  function getSpan(e) {
    var t = e.touches ? e.touches[0] : e;
    var el = document.elementFromPoint(t.clientX, t.clientY);
    return el && el.closest && el.closest('.tlg-word');
  }

  function cancelGesture() {
    clearTimeout(holdTimer);
    holdTimer = null;
    gestureSpan = null;
  }

  function onTouchStart(e) {
    if (e.touches && e.touches.length > 1) {
      cancelGesture();
      return;
    }
    cancelGesture();
    gestureFired = false;
    isScrolling = false;

    var span = getSpan(e);
    if (!span) return;

    var t = e.touches ? e.touches[0] : e;
    touchStartX = t.clientX;
    touchStartY = t.clientY;
    gestureSpan = span;

    // Long-press fires after 500ms automatically if finger hasn't moved
    holdTimer = setTimeout(function() {
      if (!gestureSpan || isScrolling) return;
      gestureFired = true;
      triggerMeaning(gestureSpan, 3);
      gestureSpan = null;
    }, 500);
  }

  function onMove(e) {
    if (!gestureSpan) return;
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
    if (!gestureSpan) return;
    clearTimeout(holdTimer);
    holdTimer = null;
    
    // If not scrolling and hold hasn't fired yet, it's a tap
    if (!isScrolling && !gestureFired) {
      triggerMeaning(gestureSpan, 1);
    }
    
    gestureSpan = null;
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

  window.addEventListener('scroll', function() {
    isScrolling = true;
    cancelGesture();
  }, { passive: true });

  // Suppress the synthetic click so it doesn't double-fire or navigate
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

  document.addEventListener('contextmenu', function(e) {
    var span = e.target.closest && e.target.closest('.tlg-word');
    if (span) e.preventDefault();
  });

})();
