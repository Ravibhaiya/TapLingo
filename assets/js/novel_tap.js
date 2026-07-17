(function() {
  if (window.__tlgInstalled) return;
  window.__tlgInstalled = true;

  document.querySelectorAll('*').forEach(function(el) {
    try {
      el.style.userSelect = 'text';
      el.style.webkitUserSelect = 'text';
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

  document.addEventListener('click', function(e) {
    var span = e.target.closest && e.target.closest('.tlg-word');
    if (!span) return;
    e.preventDefault();
    e.stopPropagation();

    var tapCount = (span._tlgTaps || 0) + 1;
    span._tlgTaps = tapCount;
    clearTimeout(span._tlgTimer);
    span.classList.add('tlg-hl');

    span._tlgTimer = setTimeout(function() {
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

      if (window.TapLingoChannel) {
        TapLingoChannel.postMessage(JSON.stringify({
          word: span.innerText,
          sentence: sentence,
          taps: tapCount >= 3 ? 3 : (tapCount >= 2 ? 2 : 1)
        }));
      }
      span._tlgTaps = 0;
      setTimeout(function() { span.classList.remove('tlg-hl'); }, 600);
    }, 300);
  }, true);
})();
