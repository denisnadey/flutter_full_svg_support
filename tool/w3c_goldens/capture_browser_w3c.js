#!/usr/bin/env node

/**
 * Capture browser goldens for W3C SVG manifest cases.
 *
 * Usage:
 *   node tool/w3c_goldens/capture_browser_w3c.js
 *   node tool/w3c_goldens/capture_browser_w3c.js --tier smoke --update-baseline
 *   node tool/w3c_goldens/capture_browser_w3c.js --case coords-trans-01-b
 */

const fs = require('fs');
const http = require('http');
const path = require('path');

const PROJECT_ROOT = path.resolve(__dirname, '..', '..');
const DEFAULT_MANIFEST = path.join(__dirname, 'w3c_manifest.json');
const DEFAULT_OUTPUT = path.join(PROJECT_ROOT, 'test', 'goldens', 'w3c', 'browser');

function loadPuppeteer() {
  try {
    return require('puppeteer');
  } catch (_error) {
    const fallback = path.join(
      __dirname,
      '..',
      'golden_capture',
      'node_modules',
      'puppeteer',
    );
    try {
      return require(fallback);
    } catch (fallbackError) {
      throw new Error(
        'Puppeteer is not installed. Run npm install in tool/golden_capture or install puppeteer in this workspace.',
      );
    }
  }
}

function parseArgs(argv) {
  const options = {
    animationTimeMs: 0,
    cases: [],
    headful: false,
    height: 600,
    limit: null,
    manifest: DEFAULT_MANIFEST,
    output: DEFAULT_OUTPUT,
    tier: 'smoke',
    updateBaseline: false,
    width: 800,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];

    if (arg === '--manifest' && i + 1 < argv.length) {
      options.manifest = path.resolve(argv[i + 1]);
      i += 1;
    } else if (arg === '--output' && i + 1 < argv.length) {
      options.output = path.resolve(argv[i + 1]);
      i += 1;
    } else if (arg === '--tier' && i + 1 < argv.length) {
      options.tier = argv[i + 1];
      i += 1;
    } else if (arg === '--case' && i + 1 < argv.length) {
      options.cases.push(argv[i + 1]);
      i += 1;
    } else if (arg === '--width' && i + 1 < argv.length) {
      options.width = Number.parseInt(argv[i + 1], 10);
      i += 1;
    } else if (arg === '--height' && i + 1 < argv.length) {
      options.height = Number.parseInt(argv[i + 1], 10);
      i += 1;
    } else if (arg === '--animation-time-ms' && i + 1 < argv.length) {
      options.animationTimeMs = Number.parseInt(argv[i + 1], 10);
      i += 1;
    } else if (arg === '--limit' && i + 1 < argv.length) {
      options.limit = Number.parseInt(argv[i + 1], 10);
      i += 1;
    } else if (arg === '--update-baseline') {
      options.updateBaseline = true;
    } else if (arg === '--headful') {
      options.headful = true;
    } else if (arg === '--help' || arg === '-h') {
      printUsage();
      process.exit(0);
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }

  if (!Number.isFinite(options.width) || options.width <= 0) {
    throw new Error('--width must be a positive integer');
  }
  if (!Number.isFinite(options.height) || options.height <= 0) {
    throw new Error('--height must be a positive integer');
  }
  if (!Number.isFinite(options.animationTimeMs) || options.animationTimeMs < 0) {
    throw new Error('--animation-time-ms must be a non-negative integer');
  }

  return options;
}

function printUsage() {
  console.log('Usage: node tool/w3c_goldens/capture_browser_w3c.js [options]');
  console.log('');
  console.log('Options:');
  console.log('  --manifest <path>         Manifest JSON path (default: tool/w3c_goldens/w3c_manifest.json)');
  console.log('  --output <dir>            Output directory for browser PNGs');
  console.log('  --tier <smoke|core|extended|all>');
  console.log('  --case <id>               Capture a specific case (repeatable)');
  console.log('  --width <n>               Viewport width (default: 800)');
  console.log('  --height <n>              Viewport height (default: 600)');
  console.log('  --animation-time-ms <n>   Wait after load before screenshot');
  console.log('  --limit <n>               Limit selected cases');
  console.log('  --update-baseline         Overwrite existing PNGs');
  console.log('  --headful                 Launch Chromium in headful mode');
}

function loadManifest(manifestPath) {
  if (!fs.existsSync(manifestPath)) {
    throw new Error(`Manifest not found: ${manifestPath}`);
  }

  const raw = fs.readFileSync(manifestPath, 'utf8');
  const manifest = JSON.parse(raw);

  if (!Array.isArray(manifest.cases)) {
    throw new Error('Manifest JSON does not contain a valid "cases" array.');
  }

  return manifest;
}

function toContentType(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  switch (ext) {
    case '.css':
      return 'text/css; charset=utf-8';
    case '.gif':
      return 'image/gif';
    case '.html':
      return 'text/html; charset=utf-8';
    case '.js':
      return 'application/javascript; charset=utf-8';
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.json':
      return 'application/json; charset=utf-8';
    case '.png':
      return 'image/png';
    case '.svg':
      return 'image/svg+xml';
    case '.svgz':
      return 'image/svg+xml';
    case '.ttf':
      return 'font/ttf';
    case '.woff':
      return 'font/woff';
    case '.woff2':
      return 'font/woff2';
    case '.xml':
      return 'application/xml; charset=utf-8';
    default:
      return 'application/octet-stream';
  }
}

function startStaticServer(rootDir) {
  return new Promise((resolve, reject) => {
    const server = http.createServer((req, res) => {
      try {
        const requestPath = decodeURIComponent((req.url || '/').split('?')[0]);
        const safePath = path.normalize(requestPath).replace(/^\/+/, '');
        const fullPath = path.join(rootDir, safePath);

        if (!fullPath.startsWith(rootDir)) {
          res.writeHead(403, { 'Content-Type': 'text/plain; charset=utf-8' });
          res.end('Forbidden');
          return;
        }

        let filePath = fullPath;
        if (fs.existsSync(filePath) && fs.statSync(filePath).isDirectory()) {
          filePath = path.join(filePath, 'index.html');
        }

        if (!fs.existsSync(filePath) || !fs.statSync(filePath).isFile()) {
          res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
          res.end('Not Found');
          return;
        }

        const headers = {
          'Access-Control-Allow-Origin': '*',
          'Cache-Control': 'no-store',
          'Content-Type': toContentType(filePath),
        };

        if (path.extname(filePath).toLowerCase() === '.svgz') {
          headers['Content-Encoding'] = 'gzip';
        }

        res.writeHead(200, headers);
        fs.createReadStream(filePath).pipe(res);
      } catch (error) {
        res.writeHead(500, { 'Content-Type': 'text/plain; charset=utf-8' });
        res.end(`Server error: ${error.message}`);
      }
    });

    server.on('error', reject);
    server.listen(0, '127.0.0.1', () => {
      const address = server.address();
      resolve({
        server,
        baseUrl: `http://127.0.0.1:${address.port}`,
      });
    });
  });
}

function selectCases(manifestCases, options) {
  const allowedTiers = new Set(['smoke', 'core', 'extended', 'all']);
  if (!allowedTiers.has(options.tier)) {
    throw new Error(`Invalid --tier value: ${options.tier}`);
  }

  let selected = manifestCases.filter((testCase) => !testCase.skip);

  if (options.tier !== 'all') {
    selected = selected.filter((testCase) => testCase.tier === options.tier);
  }

  if (options.cases.length > 0) {
    const caseSet = new Set(options.cases);
    selected = selected.filter((testCase) => caseSet.has(testCase.id));
  }

  selected.sort((a, b) => a.id.localeCompare(b.id));

  if (options.limit && options.limit > 0) {
    selected = selected.slice(0, options.limit);
  }

  return selected;
}

function renderWrapperHtml(svgUrl, width, height) {
  return `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <style>
    html, body {
      margin: 0;
      padding: 0;
      width: ${width}px;
      height: ${height}px;
      overflow: hidden;
      background: #ffffff;
    }
    #root {
      width: ${width}px;
      height: ${height}px;
      display: flex;
      align-items: center;
      justify-content: center;
      background: #ffffff;
    }
    #target {
      width: 100%;
      height: 100%;
      object-fit: contain;
      display: block;
      background: #ffffff;
    }
  </style>
</head>
<body>
  <div id="root">
    <img id="target" src="${svgUrl}" alt="svg" />
  </div>
</body>
</html>`;
}

async function captureCase({ page, testCase, outputPath, options, baseUrl }) {
  const svgUrl = `${baseUrl}/${testCase.svgPath}`;

  await page.setViewport({
    width: options.width,
    height: options.height,
    deviceScaleFactor: 1,
  });

  await page.setContent(renderWrapperHtml(svgUrl, options.width, options.height), {
    waitUntil: 'networkidle0',
  });

  await page.waitForFunction(
    () => {
      const img = document.getElementById('target');
      return img && img.complete && img.naturalWidth > 0 && img.naturalHeight > 0;
    },
    { timeout: 20000 },
  );

  const caseWaitMs =
    Number.isFinite(testCase.animationTimeMs) && testCase.animationTimeMs > 0
      ? testCase.animationTimeMs
      : options.animationTimeMs;

  if (caseWaitMs > 0) {
    await new Promise((resolve) => setTimeout(resolve, caseWaitMs));
  }

  await page.screenshot({
    path: outputPath,
    type: 'png',
    clip: {
      x: 0,
      y: 0,
      width: options.width,
      height: options.height,
    },
  });
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const manifest = loadManifest(options.manifest);
  const selected = selectCases(manifest.cases, options);

  if (selected.length === 0) {
    console.log('No runnable cases selected.');
    return;
  }

  fs.mkdirSync(options.output, { recursive: true });

  console.log(`Manifest: ${options.manifest}`);
  console.log(`Tier: ${options.tier}`);
  if (options.cases.length > 0) {
    console.log(`Case filter: ${options.cases.join(', ')}`);
  }
  console.log(`Selected cases: ${selected.length}`);
  console.log(`Output: ${options.output}`);

  const { server, baseUrl } = await startStaticServer(PROJECT_ROOT);
  const puppeteer = loadPuppeteer();

  const results = {
    captured: [],
    failed: [],
    skippedExisting: [],
  };

  let browser;

  try {
    browser = await puppeteer.launch({
      headless: options.headful ? false : 'new',
    });

    const page = await browser.newPage();

    for (let i = 0; i < selected.length; i += 1) {
      const testCase = selected[i];
      const outputPath = path.join(options.output, `${testCase.id}.png`);
      const svgPathAbs = path.join(PROJECT_ROOT, testCase.svgPath);

      const prefix = `[${i + 1}/${selected.length}] ${testCase.id}`;

      if (!fs.existsSync(svgPathAbs)) {
        console.error(`${prefix} -> FAIL (missing SVG: ${testCase.svgPath})`);
        results.failed.push({ id: testCase.id, error: 'missing_svg' });
        continue;
      }

      if (!options.updateBaseline && fs.existsSync(outputPath)) {
        console.log(`${prefix} -> SKIP (already exists)`);
        results.skippedExisting.push(testCase.id);
        continue;
      }

      try {
        await captureCase({
          page,
          testCase,
          outputPath,
          options,
          baseUrl,
        });
        console.log(`${prefix} -> OK`);
        results.captured.push(testCase.id);
      } catch (error) {
        console.error(`${prefix} -> FAIL (${error.message})`);
        results.failed.push({ id: testCase.id, error: error.message });
      }
    }
  } finally {
    if (browser) {
      await browser.close();
    }
    server.close();
  }

  console.log('');
  console.log('Capture summary');
  console.log('==============');
  console.log(`Captured: ${results.captured.length}`);
  console.log(`Skipped existing: ${results.skippedExisting.length}`);
  console.log(`Failed: ${results.failed.length}`);

  if (results.failed.length > 0) {
    process.exit(1);
  }
}

main().catch((error) => {
  console.error(`Fatal error: ${error.message}`);
  process.exit(1);
});
