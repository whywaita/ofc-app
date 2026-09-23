#!/usr/bin/env node
/**
 * Static server for the Flutter web build, wired for vlmkit verification.
 *
 * Why this file exists
 * --------------------
 * Flutter paints the app into a canvas inside <flt-glass-pane>. The page DOM therefore
 * holds no app content, and every DOM-geometry gate in vlmkit measures an empty page:
 *
 *   $ npx vlmkit check integrity https://whywaita.github.io/ofc-app/
 *   verdict: CLEAN (0 fail, 0 warn, 0 exempted)
 *     1280x800: 4 component(s), ink 1.7%, 0 text block(s)
 *
 * `0 text block(s)` on a screen full of text is the tell. The library's documented answer
 * for canvas UIs is to hand element rects in by hand (`check integrity --elements … --image …`),
 * which covers 6 of its 18 integrity rules. Flutter can do better than that: the engine
 * already owns a real accessibility DOM — roles, names, rects, checked/disabled state —
 * it just does not build it until something asks. Clicking the `flt-semantics-placeholder`
 * element the engine installs *is* that request. Afterwards the page carries ordinary
 * `<flt-semantics role="button" aria-label="…">` elements and the unmodified DOM gates
 * work: integrity, a11y touch/contrast/focus, copy, design, interactions.
 *
 * Why the click is injected here rather than driven by Playwright
 * --------------------------------------------------------------
 * The placeholder is a 1x1 element parked at (-1,-1), so Playwright's own actionability
 * checks (visible, stable, receives events) reject it — `vlmkit inspect interact` fails
 * that step with a 5s timeout, and no gate accepts a pre-navigation script. Injecting four
 * lines into the served copy of index.html is the smallest remaining hook, and it keeps the
 * app itself untouched: this file and the injection exist only for verification runs, and
 * the deployed build never sees them.
 *
 * Usage
 * -----
 *   node tools/vlmkit/serve-web.mjs [--root <dir>] [--port <n>] [--no-semantics]
 *
 * Defaults to app/build/web relative to this file, port 4173. Started automatically as the
 * `webServer` of vlmkit.gates.json; run it by hand to poke at the app in a browser.
 */

import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { extname, join, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = fileURLToPath(new URL('.', import.meta.url));
const DEFAULT_ROOT = resolve(HERE, '..', '..', 'app', 'build', 'web');

function readArgs(argv) {
  const args = { root: DEFAULT_ROOT, port: Number(process.env.PORT ?? 4173), semantics: true };
  for (let i = 0; i < argv.length; i += 1) {
    const flag = argv[i];
    if (flag === '--root') args.root = resolve(argv[++i]);
    else if (flag === '--port') args.port = Number(argv[++i]);
    else if (flag === '--no-semantics') args.semantics = false;
    else if (flag === '--help' || flag === '-h') {
      console.log('usage: node tools/vlmkit/serve-web.mjs [--root <dir>] [--port <n>] [--no-semantics]');
      process.exit(0);
    } else {
      throw new Error(`unknown argument: ${flag}`);
    }
  }
  return args;
}

/**
 * Runs at document start, before flutter_bootstrap.js. The engine installs the placeholder
 * during startup, so poll for it rather than trusting one event; give up after ~10s so a
 * page that never boots does not poll forever.
 */
const SEMANTICS_BOOTSTRAP = `
<script id="vlmkit-semantics-bootstrap">
// Verification harness only (see tools/vlmkit/serve-web.mjs). Enables Flutter's
// accessibility DOM so DOM-geometry gates have elements to measure.
(function () {
  var done = false, tries = 0;
  function enable() {
    if (done) return;
    var placeholder = document.querySelector('flt-semantics-placeholder');
    if (!placeholder) return;
    done = true;
    placeholder.click();
    window.__vlmkitSemanticsEnabled = true;
  }
  window.addEventListener('flutter-first-frame', enable);
  var timer = setInterval(function () {
    enable();
    if (done || ++tries > 200) clearInterval(timer);
  }, 50);
  enable();
})();
</script>
`;

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.xml': 'application/xml',
  '.txt': 'text/plain; charset=utf-8',
  '.map': 'application/json; charset=utf-8',
};

function resolveWithinRoot(root, urlPath) {
  const decoded = decodeURIComponent(urlPath.split('?')[0].split('#')[0]);
  const candidate = resolve(join(root, decoded));
  if (candidate !== root && !candidate.startsWith(root + sep)) return null;
  return candidate;
}

/**
 * Map a request path to a file inside the build. A directory (or a path that resolves to
 * one) becomes its index.html, and the *resolved file* is what decides the content type —
 * serving index.html as application/octet-stream makes Chromium download it instead of
 * rendering it, which surfaces as `page.goto: Download is starting`.
 */
async function resolveFile(urlPath) {
  const candidate = resolveWithinRoot(root, urlPath);
  if (candidate === null) return null;
  try {
    const info = await stat(candidate);
    return info.isDirectory() ? join(candidate, 'index.html') : candidate;
  } catch {
    return candidate;
  }
}

const { root, port, semantics } = readArgs(process.argv.slice(2));

const server = createServer(async (req, res) => {
  const target = await resolveFile(req.url ?? '/');
  if (target === null) {
    res.writeHead(403).end('forbidden');
    return;
  }
  try {
    const body = await readFile(target);
    const type = MIME[extname(target).toLowerCase()] ?? 'application/octet-stream';
    const payload = semantics && target.endsWith(`${sep}index.html`)
      ? Buffer.from(body.toString('utf8').replace('</body>', `${SEMANTICS_BOOTSTRAP}</body>`))
      : body;
    res.writeHead(200, {
      'content-type': type,
      'cache-control': 'no-store',
      'content-length': payload.length,
    });
    res.end(req.method === 'HEAD' ? undefined : payload);
  } catch {
    res.writeHead(404, { 'content-type': 'text/plain; charset=utf-8' }).end('not found');
  }
});

server.listen(port, '127.0.0.1', () => {
  console.log(`serving ${root}`);
  console.log(`  http://127.0.0.1:${port}/  (Flutter semantics bootstrap: ${semantics ? 'on' : 'off'})`);
});
