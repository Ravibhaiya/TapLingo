const puppeteer = require('puppeteer');

const TARGET_Y = 15000;

const JS_CODE = `
(function() {
  const TARGET = ${TARGET_Y};
  const maxTime = 25000;
  const start = Date.now();
  const STEP_TIMEOUT = 2500;
  const STALL_LIMIT = 4;

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
    document.querySelectorAll('img[loading="lazy"]').forEach(img => {
      img.loading = 'eager';
      img.removeAttribute('loading');
    });

    const lazyAttributes = [
      'data-src', 'data-lazy-src', 'data-original', 'bv-data-src', 
      'data-src-retina', 'lazy-src', 'data-srcset', 'bv-data-srcset'
    ];

    document.querySelectorAll('img, source').forEach(el => {
      let srcFound = false;
      let srcsetFound = false;

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

      if (el.tagName === 'IMG' && el.src && el.src.startsWith('data:image/')) {
        const realSrc = el.getAttribute('data-src') || el.getAttribute('bv-data-src') || el.getAttribute('data-lazy-src');
        if (realSrc) {
          el.src = realSrc;
        }
      }
    });

    window.dispatchEvent(new Event('scroll'));
    window.dispatchEvent(new Event('resize'));
  }

  let status = 'timeout';
  let stalls = 0;

  async function run() {
    try {
      disableAnchoring();
      forceLoadAllImages();

      while (Date.now() - start < maxTime) {
        const currentHeight = getScrollHeight();
        const viewportHeight = isWindow ? window.innerHeight : container.clientHeight;
        const maxScroll = currentHeight - viewportHeight;

        if (maxScroll >= TARGET) {
          scrollTo(TARGET);
          await new Promise(r => setTimeout(r, 100));
          if (Math.abs(getScrollY() - TARGET) < 10) {
            status = 'reached';
            break;
          }
          continue; 
        }

        scrollTo(maxScroll);

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
            scrollTo(TARGET);
            status = 'end-of-content';
            break;
          }
        }
      }
    } finally {
      enableAnchoring();
      if (window.TapLingoChannel) {
        window.TapLingoChannel.postMessage(JSON.stringify({
          type: 'scrollRestoration',
          status: status,
          finalY: getScrollY(),
          timeTaken: Date.now() - start
        }));
      }
    }
  }

  run();
  return true;
})();
`;

async function runTest(iteration) {
  const browser = await puppeteer.launch({ headless: "new" });
  const page = await browser.newPage();
  await page.setViewport({ width: 1200, height: 800 });

  console.log(\`[Iteration \${iteration}] Loading page...\`);
  await page.goto('https://demonslayermangaa.com/demon-slayer-manga-chapter-1/', { waitUntil: 'domcontentloaded', timeout: 60000 });

  console.log(\`[Iteration \${iteration}] Injecting script & waiting...\`);
  
  await page.exposeFunction('postMessageToNode', msg => {
    try {
      const data = JSON.parse(msg);
      if (data.type === 'scrollRestoration') {
        console.log(\`[Iteration \${iteration}] Result: status=\${data.status}, finalY=\${data.finalY}, timeTaken=\${data.timeTaken}ms\`);
      }
    } catch (e) {
      console.error('Failed to parse msg', msg);
    }
  });

  await page.evaluateOnNewDocument(() => {
    window.TapLingoChannel = {
      postMessage: (msg) => {
        window.postMessageToNode(msg);
      }
    };
  });
  
  // Re-inject for the current page context if evaluateOnNewDocument didn't catch it in time
  await page.evaluate(() => {
    window.TapLingoChannel = {
      postMessage: (msg) => {
        window.postMessageToNode(msg);
      }
    };
  });

  const startScriptTime = Date.now();
  await page.evaluate(JS_CODE);

  // Wait until we get the log or timeout
  await new Promise(r => setTimeout(r, 26000));
  
  await browser.close();
}

async function main() {
  for (let i = 1; i <= 7; i++) {
    await runTest(i);
  }
}

main().catch(console.error);
