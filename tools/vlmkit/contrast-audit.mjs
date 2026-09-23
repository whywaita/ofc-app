#!/usr/bin/env node
/**
 * WCAG contrast audit for a Flutter web screen, measured from pixels.
 *
 * Why this file exists
 * --------------------
 * `vlmkit check integrity --rule check.integrity/low-contrast-text` cannot judge this app.
 * It reads text colours out of the DOM, and Flutter's accessibility DOM paints nothing: every
 * `<flt-semantics>` node is transparent, so the rule reports every label as 1.00:1 — 8 findings
 * that are all false positives (see docs/vlmkit.md, "Known limits"). Turning the rule off left
 * the app with no contrast coverage at all.
 *
 * This measures what is actually on screen. It screenshots the page, asks the engine for the
 * rect of every labelled node in the accessibility tree, then samples those pixels: the most
 * common colour inside a rect is the background, the colour farthest from it is the text, and
 * the WCAG 2.1 ratio follows. Two labels the vlmkit rule could not see fail on the current
 * build — `Game Mode` (4.39:1) and the seed line (2.55:1) — which is the whole point.
 *
 * The pixel work runs inside the page (a detached canvas) rather than in Node, so this needs
 * no image-decoding dependency beyond the Playwright that vlmkit already brings.
 *
 * Text size decides the threshold, per WCAG: a rect at least 24px tall (or 18.66px bold) is
 * large text and needs 3.0:1, anything else needs 4.5:1. Findings below the threshold fail the
 * run; accepted ones go in --allow with a reason, the same shape vlmkit's own gates use.
 *
 * Usage
 * -----
 *   node tools/vlmkit/contrast-audit.mjs [options]
 *
 *   --base-url <url>       page to audit (default http://127.0.0.1:4173/)
 *   --viewport <WxH>       viewport in CSS px (default 375x812)
 *   --click <label>        click a button by its accessibility label before auditing,
 *                          repeatable: --click Practice --click Start
 *   --min-ratio <n>        override the normal-text threshold (default 4.5)
 *   --allow "<label>;<reason>"  accept a finding, repeatable
 *   --json                 print the raw results as JSON
 *
 * Exit code is 1 when any label fails, 0 otherwise. Expects the page to be served by
 * tools/vlmkit/serve-web.mjs, which enables Flutter's accessibility tree.
 */

import { chromium } from 'playwright';

const DEFAULT_BASE_URL = 'http://127.0.0.1:4173/';
const LARGE_TEXT_MIN_HEIGHT = 24;
const LARGE_TEXT_MIN_RATIO = 3.0;

function readArgs(argv) {
  const args = { baseUrl: DEFAULT_BASE_URL, viewport: '375x812', clicks: [], allows: [], json: false, minRatio: null };
  for (let i = 0; i < argv.length; i += 1) {
    const flag = argv[i];
    if (flag === '--base-url') args.baseUrl = argv[++i];
    else if (flag === '--viewport') args.viewport = argv[++i];
    else if (flag === '--click') args.clicks.push(argv[++i]);
    else if (flag === '--min-ratio') args.minRatio = Number(argv[++i]);
    else if (flag === '--allow') args.allows.push(argv[++i]);
    else if (flag === '--json') args.json = true;
    else if (flag === '--help' || flag === '-h') {
      console.log('usage: node tools/vlmkit/contrast-audit.mjs [--base-url <url>] [--viewport WxH]');
      console.log('                                                [--click <label>]… [--allow "<label>;<reason>"]…');
      console.log('                                                [--min-ratio <n>] [--json]');
      process.exit(0);
    } else {
      throw new Error(`unknown argument: ${flag}`);
    }
  }
  const [w, h] = args.viewport.split('x').map(Number);
  if (!Number.isFinite(w) || !Number.isFinite(h)) throw new Error(`bad --viewport: ${args.viewport}`);
  args.width = w;
  args.height = h;
  return args;
}

/** Every labelled node in the accessibility tree, innermost text only, in CSS px. */
const HARVEST = `(() => {
  const host = document.querySelector('flt-semantics-host');
  if (!host) return null;
  const out = [];
  for (const node of host.querySelectorAll('*')) {
    const tag = node.tagName.toLowerCase();
    const label = (node.textContent || '').trim();
    const rect = node.getBoundingClientRect();
    // Flutter renders SelectableText/TextField as an empty <textarea>: no text to read, but the
    // rect still carries painted pixels worth measuring. Label it so the finding is legible.
    if ((tag === 'textarea' || tag === 'input') && rect.width >= 4 && rect.height >= 4) {
      out.push({
        label: node.getAttribute('aria-label') || '(unlabelled text field)',
        rect: [Math.round(rect.x), Math.round(rect.y), Math.round(rect.width), Math.round(rect.height)],
      });
      continue;
    }
    if (!label || label.length > 40) continue;
    if (rect.width < 4 || rect.height < 4) continue;
    const hasInner = [...node.querySelectorAll('*')].some((c) => (c.textContent || '').trim() === label);
    if (hasInner) continue;
    out.push({
      label,
      rect: [Math.round(rect.x), Math.round(rect.y), Math.round(rect.width), Math.round(rect.height)],
      // WCAG 1.4.3 exempts inactive controls, and Flutter paints them grey-on-grey.
      disabled: node.getAttribute('aria-disabled') === 'true',
    });
  }
  return out;
})()`;

/**
 * Sample the screenshot for each rect and return background, text colour and WCAG ratio.
 * Runs in the page so no PNG decoder is needed here; the canvas is detached and never
 * touches the app's DOM.
 */
const MEASURE = async function measure({ dataUrl, regions, width, largeTextMinHeight }) {
  const image = new Image();
  await new Promise((resolve, reject) => {
    image.onload = resolve;
    image.onerror = () => reject(new Error('screenshot decode failed'));
    image.src = dataUrl;
  });
  const canvas = document.createElement('canvas');
  canvas.width = image.width;
  canvas.height = image.height;
  const ctx = canvas.getContext('2d', { willReadFrequently: true });
  ctx.drawImage(image, 0, 0);
  const scale = image.width / width;
  const luminance = ([r, g, b]) => {
    const chan = (v) => {
      const s = v / 255;
      return s <= 0.03928 ? s / 12.92 : ((s + 0.055) / 1.055) ** 2.4;
    };
    return 0.2126 * chan(r) + 0.7152 * chan(g) + 0.0722 * chan(b);
  };
  const ratio = (a, b) => {
    const [hi, lo] = [luminance(a), luminance(b)].sort((x, y) => y - x);
    return (hi + 0.05) / (lo + 0.05);
  };
  const results = [];
  for (const { label, rect, disabled } of regions) {
    const [x, y, w, h] = rect;
    if (disabled) {
      results.push({ label, rect, ratio: null, reason: 'disabled control (WCAG 1.4.3 exempt)' });
      continue;
    }
    const x0 = Math.max(0, Math.round(x * scale));
    const y0 = Math.max(0, Math.round(y * scale));
    const x1 = Math.min(image.width, Math.round((x + w) * scale));
    const y1 = Math.min(image.height, Math.round((y + h) * scale));
    if (x1 <= x0 || y1 <= y0) {
      results.push({ label, rect, ratio: null, reason: 'outside the viewport' });
      continue;
    }
    const { data } = ctx.getImageData(x0, y0, x1 - x0, y1 - y0);
    const counts = new Map();
    for (let i = 0; i < data.length; i += 4) {
      const key = (data[i] << 16) | (data[i + 1] << 8) | data[i + 2];
      counts.set(key, (counts.get(key) || 0) + 1);
    }
    let bg = 0;
    let bgCount = -1;
    for (const [key, count] of counts) if (count > bgCount) { bg = key; bgCount = count; }
    const toRgb = (key) => [(key >> 16) & 255, (key >> 8) & 255, key & 255];
    let fg = bg;
    let best = 1;
    for (const key of counts.keys()) {
      const r = ratio(toRgb(key), toRgb(bg));
      if (r > best) { best = r; fg = key; }
    }
    results.push({
      label,
      rect,
      ratio: Number(best.toFixed(2)),
      background: toRgb(bg),
      text: toRgb(fg),
      pixels: bgCount > 0 ? [...counts.values()].reduce((a, b) => a + b, 0) : 0,
      largeText: h >= largeTextMinHeight,
    });
  }
  return results;
};

async function clickByLabel(page, label) {
  const target = page.locator(`flt-semantics[role=button]`, { hasText: new RegExp(`^${label.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`) }).first();
  await target.click({ timeout: 10_000 });
  await page.waitForTimeout(800);
}

async function main() {
  const args = readArgs(process.argv.slice(2));
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: args.width, height: args.height } });
  try {
    await page.goto(args.baseUrl, { waitUntil: 'load' });
    // Flutter keeps <flt-semantics-host> zero-sized until the tree is built, so waiting for it
    // to be *visible* never resolves — attach is the right state here.
    await page.waitForSelector('flt-semantics-host', { state: 'attached', timeout: 20_000 }).catch(async () => {
      // The engine builds the tree only after something asks; serve-web.mjs does this for us,
      // but a plain static server needs the placeholder clicked.
      const placeholder = page.locator('flt-semantics-placeholder');
      if (await placeholder.count()) await placeholder.first().click({ force: true });
      await page.waitForSelector('flt-semantics-host', { state: 'attached', timeout: 20_000 });
    });
    for (const label of args.clicks) await clickByLabel(page, label);
    await page.waitForTimeout(500);

    const regions = await page.evaluate(HARVEST);
    if (!regions) throw new Error('no flt-semantics-host: serve the build with tools/vlmkit/serve-web.mjs');
    const shot = await page.screenshot();
    const dataUrl = `data:image/png;base64,${shot.toString('base64')}`;
    const measured = await page.evaluate(MEASURE, { dataUrl, regions, width: args.width });

    const allowed = new Map(
      args.allows.map((entry) => {
        const [label, reason] = entry.split(';');
        return [label.trim(), (reason || '').trim()];
      }),
    );
    const findings = [];
    for (const row of measured) {
      const threshold = args.minRatio ?? (row.largeText ? LARGE_TEXT_MIN_RATIO : 4.5);
      row.threshold = threshold;
      if (row.ratio === null) continue;
      if (row.ratio < threshold) {
        row.allowed = allowed.get(row.label) || null;
        findings.push(row);
      }
    }
    const failed = findings.filter((row) => !row.allowed);

    if (args.json) {
      console.log(JSON.stringify({ viewport: args.viewport, measured, findings, failed }, null, 2));
    } else {
      console.log(`contrast audit: ${args.baseUrl} at ${args.viewport}`);
      console.log(`inspected ${measured.length} labelled element(s)\n`);
      for (const row of measured) {
        if (row.ratio === null) {
          console.log(`  skip   ${row.label.slice(0, 34).padEnd(36)} ${row.reason}`);
          continue;
        }
        const state = row.ratio >= row.threshold ? 'pass' : 'FAIL';
        const size = row.largeText ? 'large' : 'normal';
        console.log(
          `  ${state}  ${row.ratio.toFixed(2).padStart(5)}:1  ${row.label.slice(0, 34).padEnd(36)} ${size} text, needs ${row.threshold.toFixed(1)}:1  bg=${row.background} fg=${row.text}`,
        );
      }
      if (findings.length) {
        console.log('\nfindings');
        for (const row of findings) {
          console.log(`  ${row.allowed ? 'allowed' : 'FAIL   '} ${row.label}: ${row.ratio}:1${row.allowed ? ` — ${row.allowed}` : ''}`);
        }
      }
      console.log(`\nverdict: ${failed.length ? `${failed.length} FAILED` : 'PASS'} (${measured.length - findings.length} pass, ${findings.length - failed.length} allowed, ${failed.length} failed)`);
    }
    process.exitCode = failed.length ? 1 : 0;
  } finally {
    await browser.close();
  }
}

main().catch((error) => {
  console.error(`contrast-audit: ${error.message}`);
  process.exitCode = 2;
});
