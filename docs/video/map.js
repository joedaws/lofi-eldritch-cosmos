const { chromium } = require('playwright');
(async () => { const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: 1400, height: 900 }, deviceScaleFactor: 2 });
  await p.goto('http://localhost:4500/'); await p.waitForTimeout(2500);
  const s = await p.$('#scrub'); if (s) { await p.evaluate(() => { const r = document.getElementById('scrub'); r.value = Math.floor(r.max * 0.6); r.dispatchEvent(new Event('input')); }); }
  await p.waitForTimeout(1500);
  await p.screenshot({ path: process.argv[2] }); await b.close(); })();
