#!/usr/bin/env node
/**
 * Ask an image-capable model about a screen, so the deterministic gates are not the only judge.
 *
 * Why this file exists
 * --------------------
 * The vlmkit gates and tools/vlmkit/contrast-audit.mjs answer questions of geometry and pixels:
 * how wide is this target, what is this label's contrast, does this handler exist. They cannot
 * answer "does the content run past the bottom edge", "is there any hint that a card must be
 * dragged", "does this look broken" — for that the screenshot has to be read by something that
 * sees. This sends the same screenshots to a vision model and prints what it reports.
 *
 * The two layers are not alternatives, they are hypothesis and proof. On this app the vision
 * model called the seed line "light gray, low contrast" and the DOM measurement put it at
 * 2.55:1 — same defect, one layer names it and the other proves it. It also reported the seed
 * field as "visible and active while Random is selected", which the DOM disproves: the input
 * carries `disabled` in Random mode, so that observation is wrong and must not become a finding.
 * Treat every reply as a hypothesis to check against the accessibility tree or the pixels.
 *
 * Keys
 * ----
 * The API key is read from the environment only (`OPENCODE_GO_API_KEY`) and is never written to
 * a file, a report or a commit. CI does not run this script: without the key it exits 2 before
 * touching the network, so `make verify-web` stays key-free and deterministic.
 *
 * Usage
 * -----
 *   OPENCODE_GO_API_KEY=… node tools/vlmkit/vision-review.mjs [options]
 *
 *   --base-url <url>   page to review (default http://127.0.0.1:4173/)
 *   --viewport <WxH>   viewport in CSS px (default 375x812)
 *   --click <label>    click a button by accessibility label first, repeatable
 *   --prompt <text>    question to ask (default: the defect sweep below)
 *   --model <id>       vision model (default mimo-v2.6-pro)
 *   --out <dir>        write the screenshot and a markdown report there
 *   --json             print the reply as JSON
 *
 * Expects the page to be served by tools/vlmkit/serve-web.mjs, which enables Flutter's
 * accessibility tree — the clicks below address nodes in that tree.
 */

import { mkdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { chromium } from 'playwright';

const DEFAULT_BASE_URL = 'http://127.0.0.1:4173/';
const DEFAULT_MODEL = 'mimo-v2.6-pro';
const DEFAULT_API_BASE = 'https://opencode.ai/zen/go/v1';
const DEFAULT_PROMPT =
  'This is a screenshot of a mobile app. Report only defects you can actually see: ' +
  '(a) text that is hard to read against its background, (b) elements that overlap or are ' +
  'clipped/cut off, (c) content that appears to continue past the bottom edge, (d) controls ' +
  'with no visible hint of how to use them. Quote the exact labels involved and say "none" for ' +
  'a category with no defect.';

function readArgs(argv) {
  const args = {
    baseUrl: DEFAULT_BASE_URL,
    viewport: '375x812',
    clicks: [],
    prompt: DEFAULT_PROMPT,
    model: process.env.VLMKIT_VISION_MODEL || DEFAULT_MODEL,
    apiBase: process.env.VLMKIT_VISION_API_BASE || DEFAULT_API_BASE,
    out: null,
    json: false,
  };
  for (let i = 0; i < argv.length; i += 1) {
    const flag = argv[i];
    if (flag === '--base-url') args.baseUrl = argv[++i];
    else if (flag === '--viewport') args.viewport = argv[++i];
    else if (flag === '--click') args.clicks.push(argv[++i]);
    else if (flag === '--prompt') args.prompt = argv[++i];
    else if (flag === '--model') args.model = argv[++i];
    else if (flag === '--out') args.out = argv[++i];
    else if (flag === '--json') args.json = true;
    else if (flag === '--help' || flag === '-h') {
      console.log('usage: OPENCODE_GO_API_KEY=… node tools/vlmkit/vision-review.mjs [--base-url <url>]');
      console.log('         [--viewport WxH] [--click <label>]… [--prompt <text>] [--model <id>] [--out <dir>] [--json]');
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

async function clickByLabel(page, label) {
  const escaped = label.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  await page.locator('flt-semantics[role=button]', { hasText: new RegExp(`^${escaped}$`) }).first().click({ timeout: 10_000 });
  await page.waitForTimeout(800);
}

async function ask({ apiBase, apiKey, model, prompt, dataUrl }) {
  const response = await fetch(`${apiBase}/chat/completions`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
      // The Go relay rejects a request without a session id and a non-browser user agent.
      'x-opencode-session': `vlmkit-vision-${process.pid}-${Date.now()}`,
      'User-Agent': 'vlmkit-vision-review/1.0',
      'X-Title': 'ofc-app verification',
    },
    body: JSON.stringify({
      model,
      max_tokens: 1200,
      messages: [
        {
          role: 'user',
          content: [
            { type: 'text', text: prompt },
            { type: 'image_url', image_url: { url: dataUrl } },
          ],
        },
      ],
    }),
  });
  const text = await response.text();
  if (!response.ok) throw new Error(`${response.status} from ${apiBase}: ${text.slice(0, 300)}`);
  const payload = JSON.parse(text);
  const message = payload.choices?.[0]?.message ?? {};
  return (message.content || message.reasoning_content || '').trim() || '(empty reply)';
}

async function main() {
  const args = readArgs(process.argv.slice(2));
  const apiKey = process.env.OPENCODE_GO_API_KEY;
  if (!apiKey) {
    console.error('vision-review: OPENCODE_GO_API_KEY is not set — skipping (this script never runs in CI).');
    process.exitCode = 2;
    return;
  }

  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: args.width, height: args.height } });
  let reply;
  let shot;
  try {
    await page.goto(args.baseUrl, { waitUntil: 'load' });
    // The host is zero-sized until the tree is built, so wait for attach, not visibility.
    await page.waitForSelector('flt-semantics-host', { state: 'attached', timeout: 20_000 });
    for (const label of args.clicks) await clickByLabel(page, label);
    await page.waitForTimeout(500);
    shot = await page.screenshot();
    reply = await ask({
      apiBase: args.apiBase,
      apiKey,
      model: args.model,
      prompt: args.prompt,
      dataUrl: `data:image/png;base64,${shot.toString('base64')}`,
    });
  } finally {
    await browser.close();
  }

  if (args.out) {
    await mkdir(args.out, { recursive: true });
    const imagePath = join(args.out, `screen-${args.width}x${args.height}.png`);
    await writeFile(imagePath, shot);
    await writeFile(
      join(args.out, 'report.md'),
      [
        `# Vision review (${args.model})`,
        '',
        `- page: \`${args.baseUrl}\``,
        `- viewport: ${args.viewport}`,
        `- clicks before capture: ${args.clicks.length ? args.clicks.map((c) => `\`${c}\``).join(', ') : '(none)'}`,
        `- screenshot: \`${imagePath}\``,
        '',
        '## Question',
        '',
        args.prompt,
        '',
        '## Reply',
        '',
        reply,
        '',
        'Every line above is a hypothesis: confirm it against the accessibility tree',
        '(`tools/vlmkit/contrast-audit.mjs`, `vlmkit check …`) before turning it into a finding.',
      ].join('\n'),
    );
  }

  if (args.json) {
    console.log(JSON.stringify({ model: args.model, viewport: args.viewport, clicks: args.clicks, reply }, null, 2));
  } else {
    console.log(`vision review: ${args.baseUrl} at ${args.viewport} via ${args.model}`);
    if (args.clicks.length) console.log(`clicked first: ${args.clicks.join(' -> ')}`);
    console.log(`\n${reply}`);
  }
}

main().catch((error) => {
  console.error(`vision-review: ${error.message}`);
  process.exitCode = 1;
});
