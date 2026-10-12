// 소개 영상 렌더러 — intro.html 의 타임라인을 프레임 단위로 캡처해 MP4 로 만든다.
// 준비: npm i playwright && npx playwright install chromium   (ffmpeg 필요)
// MP4: node render.js video intro.mp4 30
// GIF: ffmpeg -i intro.mp4 -vf "fps=16,scale=960:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=192:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" -loop 0 intro.gif

// Usage: node render.js stills 1.0 3.2 ...   -> writes stills/t_<time>.png
//        node render.js video out.mp4 [fps]   -> pipes PNG frames into ffmpeg
const { chromium } = require('playwright');
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

(async () => {
  const mode = process.argv[2] || 'stills';
  const dir = __dirname;
  const browser = await chromium.launch({ args: ['--allow-file-access-from-files'] });
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
  page.on('pageerror', e => { console.error('PAGE ERROR', e.message); });
  await page.goto('file://' + path.join(dir, 'intro.html'));
  await page.evaluate(() => window.ready);
  await page.evaluate(t => window.renderFrame(t), 0.01); // warm up fonts
  const duration = await page.evaluate(() => window.DURATION);

  if (mode === 'stills') {
    fs.mkdirSync(path.join(dir, 'stills'), { recursive: true });
    const times = process.argv.slice(3).map(Number);
    for (const t of times) {
      await page.evaluate(t => window.renderFrame(t), t);
      await page.screenshot({ path: path.join(dir, 'stills', `t_${t.toFixed(2)}.png`) });
    }
  } else {
    const out = process.argv[3] || 'out.mp4';
    const fps = Number(process.argv[4] || 30);
    const total = Math.round(duration * fps);
    const ff = spawn('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'image2pipe', '-framerate', String(fps), '-c:v', 'png', '-i', '-',
      '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '17', '-preset', 'medium', '-movflags', '+faststart', out], { stdio: ['pipe', 'inherit', 'inherit'] });
    const t0 = Date.now();
    for (let i = 0; i < total; i++) {
      await page.evaluate(t => window.renderFrame(t), i / fps);
      const buf = await page.screenshot({ type: 'png' });
      if (!ff.stdin.write(buf)) await new Promise(r => ff.stdin.once('drain', r));
      if (i % 150 === 0) console.log(`frame ${i}/${total} (${((Date.now() - t0) / 1000).toFixed(0)}s)`);
    }
    ff.stdin.end();
    await new Promise(r => ff.on('close', r));
    console.log('done', total, 'frames in', ((Date.now() - t0) / 1000).toFixed(0), 's');
  }
  await browser.close();
})();
