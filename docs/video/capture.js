const { chromium } = require('playwright');
const [, , dir, mode, pageName = 'ad.html', framesDir = 'frames'] = process.argv;
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1 });
  p.on('console', (m) => { if (m.type() === 'error') console.log('console:', m.text()); });
  await p.goto('file://' + dir + '/' + pageName);
  await p.evaluate(() => window.ready);
  console.log('font VT323 loaded:', await p.evaluate(() => document.fonts.check('40px VT323')));
  const D = await p.evaluate(() => window.DURATION), FPS = 30, BAR = 2.5;
  const times = mode === 'stills'
    ? Array.from({ length: 19 }, (_, i) => i * BAR + BAR * 0.7)
    : Array.from({ length: Math.round(D * FPS) }, (_, i) => i / FPS);
  for (let i = 0; i < times.length; i++) {
    await p.evaluate((t) => window.render(t), times[i]);
    const name = mode === 'stills' ? `still-${String(i).padStart(2, '0')}.png` : `${framesDir}/f${String(i).padStart(5, '0')}.jpg`;
    await p.screenshot(mode === 'stills' ? { path: dir + '/' + name } : { path: dir + '/' + name, type: 'jpeg', quality: 92 });
  }
  await b.close();
})();
