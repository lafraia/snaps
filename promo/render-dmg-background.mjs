// Renders dmg-background.html to ../Resources/dmg/background.tiff (1x + 2x in one TIFF).
//   node render-dmg-background.mjs            → background.tiff
//   node render-dmg-background.mjs --preview  → stills/dmg-preview-{dark,light}.png with mock icons
import { chromium } from "playwright-core";
import { execFileSync } from "node:child_process";
import { mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const url = pathToFileURL(join(here, "dmg-background.html")).href;
const browser = await chromium.launch({ channel: "chrome", headless: true, args: ["--force-color-profile=srgb"] });

if (process.argv.includes("--preview")) {
  mkdirSync(join(here, "stills"), { recursive: true });
  for (const mode of ["dark", "light"]) {
    const page = await browser.newPage({ viewport: { width: 660, height: 420 }, deviceScaleFactor: 2 });
    await page.goto(`${url}?preview-${mode}`);
    await page.screenshot({ path: join(here, "stills", `dmg-preview-${mode}.png`) });
  }
} else {
  const out = join(here, "..", "Resources", "dmg");
  mkdirSync(out, { recursive: true });
  for (const scale of [1, 2]) {
    const page = await browser.newPage({ viewport: { width: 660, height: 420 }, deviceScaleFactor: scale });
    await page.goto(url);
    await page.screenshot({ path: join(out, scale === 1 ? "background.png" : "background@2x.png") });
  }
  execFileSync("tiffutil", ["-cathidpicheck", join(out, "background.png"), join(out, "background@2x.png"), "-out", join(out, "background.tiff")]);
  console.log(`✓ ${join(out, "background.tiff")}`);
}
await browser.close();
