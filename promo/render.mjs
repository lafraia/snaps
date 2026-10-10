// Renders promo.html to an MP4 by stepping its timeline frame by frame.
//   node render.mjs                     → ../docs/assets/promo.mp4 + poster
//   node render.mjs --stills 2,8.5,…    → PNG stills in ./stills for review
import { chromium } from "playwright-core";
import { spawn } from "node:child_process";
import { mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const FPS = 60;
const W = 1920, H = 1080;
const outDir = join(here, "..", "docs", "assets");
const stillsArg = process.argv.indexOf("--stills");

const browser = await chromium.launch({
  channel: "chrome",
  headless: true,
  args: ["--force-color-profile=srgb", "--hide-scrollbars", "--font-render-hinting=none"],
});
const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
await page.goto(pathToFileURL(join(here, "promo.html")).href + "?render=1");
await page.waitForFunction(() => window.__ready === true);
await page.evaluate(() => document.fonts.ready);
const duration = await page.evaluate(() => window.DURATION);

const frameAt = async (t, type = "jpeg") => {
  await page.evaluate((time) => window.renderAt(time), t);
  return page.screenshot(type === "png" ? { type: "png" } : { type: "jpeg", quality: 96 });
};

if (stillsArg !== -1) {
  const dir = join(here, "stills");
  mkdirSync(dir, { recursive: true });
  for (const t of process.argv[stillsArg + 1].split(",").map(Number)) {
    const buf = await frameAt(t, "png");
    const { writeFileSync } = await import("node:fs");
    writeFileSync(join(dir, `t${t.toFixed(2)}.png`), buf);
    console.log(`still t=${t}`);
  }
  await browser.close();
  process.exit(0);
}

mkdirSync(outDir, { recursive: true });
const output = join(outDir, "promo.mp4");
const ffmpeg = spawn("ffmpeg", [
  "-y", "-loglevel", "error",
  "-f", "image2pipe", "-framerate", String(FPS), "-i", "-",
  "-c:v", "libx264", "-preset", "slow", "-crf", "21", "-pix_fmt", "yuv420p",
  "-movflags", "+faststart", output,
], { stdio: ["pipe", "inherit", "inherit"] });

const total = Math.round(duration * FPS);
const started = Date.now();
for (let i = 0; i < total; i++) {
  const buf = await frameAt(i / FPS);
  if (!ffmpeg.stdin.write(buf)) await new Promise((r) => ffmpeg.stdin.once("drain", r));
  if (i % 120 === 0) console.log(`frame ${i}/${total} (${((Date.now() - started) / 1000).toFixed(0)}s)`);
}
ffmpeg.stdin.end();
await new Promise((r) => ffmpeg.on("close", r));

// Poster frame for the web page.
const poster = await frameAt(31.4);
const { writeFileSync } = await import("node:fs");
writeFileSync(join(outDir, "promo-poster.jpg"), poster);

await browser.close();
console.log(`✓ ${output}`);
