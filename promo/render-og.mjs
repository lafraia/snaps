// Renders og.html to ../docs/assets/og.png (1200×630 social card).
import { chromium } from "playwright-core";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const browser = await chromium.launch({ channel: "chrome", headless: true, args: ["--force-color-profile=srgb"] });
const page = await browser.newPage({ viewport: { width: 1200, height: 630 }, deviceScaleFactor: 1 });
await page.goto(pathToFileURL(join(here, "og.html")).href);
await page.evaluate(() => document.fonts.ready);
const out = join(here, "..", "docs", "assets", "og.png");
await page.screenshot({ path: out });
await browser.close();
console.log(`✓ ${out}`);
