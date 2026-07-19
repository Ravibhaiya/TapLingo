import puppeteer from 'puppeteer';

async function testRestoration(page, targetY) {
  return page.evaluate((target) => {
    return new Promise((resolve) => {
      const TARGET = target;
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

        document.querySelectorAll('img, source').forEach(el => {
          let srcFound = false;
          let srcsetFound = false;
          for (let i = 0; i < el.attributes.length; i++) {
            const attr = el.attributes[i];
            const name = attr.name.toLowerCase();
            const value = attr.value;
            if (!value) continue;
            if (name === 'data-srcset' || name === 'bv-data-srcset' || name.includes('srcset')) {
              if (name !== 'srcset') { el.setAttribute('srcset', value); srcsetFound = true; }
            }
            if (name === 'data-src' || name === 'bv-data-src' || name === 'data-lazy-src' || name === 'data-original' || name.includes('src')) {
              if (name !== 'src' && name !== 'srcset') { el.setAttribute('src', value); srcFound = true; }
            }
          }
          if (el.tagName === 'IMG' && el.src && el.src.startsWith('data:image/')) {
            const realSrc = el.getAttribute('data-src') || el.getAttribute('bv-data-src') || el.getAttribute('data-lazy-src');
            if (realSrc) { el.src = realSrc; }
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
          resolve({
            status: status,
            finalScrollY: getScrollY(),
            scrollHeight: getScrollHeight()
          });
        }
      }

      run();
    });
  }, targetY);
}

(async () => {
  const browser = await puppeteer.launch({ executablePath: '/usr/bin/google-chrome', headless: 'new', args: ['--no-sandbox', '--disable-setuid-sandbox'] });
  const url = 'https://demonslayermangaa.com/demon-slayer-manga-chapter-1/';
  const targets = [5000, 15000, 25000, 8000, 12000, 20000, 6000];

  let successCount = 0;

  for (let i = 0; i < 7; i++) {
    console.log(`\n--- Test ${i + 1}/7 ---`);
    const page = await browser.newPage();
    
    // Set a realistic viewport
    await page.setViewport({ width: 390, height: 844 });
    
    try {
      console.log(`Navigating to ${url}...`);
      await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
      
      const targetY = targets[i];
      console.log(`Running restoration logic targeting Y=${targetY}...`);
      
      const result = await testRestoration(page, targetY);
      
      console.log(`Result: ${JSON.stringify(result)}`);
      
      if (result.status === 'reached' || result.status === 'end-of-content') {
        console.log(`✅ Test ${i + 1} passed.`);
        successCount++;
      } else {
        console.log(`❌ Test ${i + 1} failed.`);
      }

    } catch (e) {
      console.log(`Error during test ${i + 1}: ${e.message}`);
    } finally {
      await page.close();
    }
  }

  await browser.close();
  
  console.log(`\nTotal Successful: ${successCount}/7`);
  if (successCount === 7) {
    console.log('Everything is working perfectly.');
  } else {
    console.log('Some tests failed.');
  }
})();
