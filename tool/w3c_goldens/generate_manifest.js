#!/usr/bin/env node

/**
 * Generate W3C SVG manifest for screenshot comparison pipeline.
 *
 * Usage:
 *   node tool/w3c_goldens/generate_manifest.js
 *   node tool/w3c_goldens/generate_manifest.js --index <path> --out <path>
 */

const fs = require('fs');
const path = require('path');

const PROJECT_ROOT = path.resolve(__dirname, '..', '..');
const SUITE_ROOT = path.join(PROJECT_ROOT, 'W3C_SVG_11_TestSuite');

const DEFAULT_INDEX = path.join(
  SUITE_ROOT,
  'harness',
  'htmlObjectApproved',
  'index.html',
);
const DEFAULT_OUT = path.join(__dirname, 'w3c_manifest.json');

// Curated stable smoke set for initial rollout.
const SMOKE_IDS = new Set([
  'color-prop-01-b',
  'color-prop-02-f',
  'coords-coord-01-t',
  'coords-coord-02-t',
  'coords-trans-01-b',
  'coords-trans-02-t',
  'coords-trans-03-t',
  'coords-trans-04-t',
  'coords-viewattr-01-b',
  'coords-viewattr-03-b',
  'shapes-circle-01-t',
  'shapes-circle-02-t',
  'shapes-ellipse-01-t',
  'shapes-line-01-t',
  'shapes-polygon-01-t',
  'shapes-polyline-01-t',
  'shapes-rect-01-t',
  'shapes-rect-02-t',
  'shapes-rect-03-t',
  'paths-data-01-t',
  'paths-data-02-t',
  'paths-data-04-t',
  'paths-data-05-t',
  'paths-data-07-t',
  'paths-data-09-t',
  'paths-data-10-t',
  'painting-fill-01-t',
  'painting-fill-02-t',
  'painting-stroke-01-t',
  'painting-stroke-02-t',
  'painting-stroke-03-t',
  'painting-stroke-04-t',
  'pservers-grad-01-b',
  'pservers-grad-02-b',
  'pservers-grad-03-b',
  'pservers-grad-04-b',
  'pservers-grad-06-b',
  'pservers-grad-08-b',
  'filters-gauss-01-b',
  'filters-offset-01-b',
]);

const CORE_CATEGORIES = new Set([
  'color',
  'coords',
  'filters',
  'linking',
  'masking',
  'painting',
  'paths',
  'pservers',
  'render',
  'shapes',
  'struct',
  'styling',
  'types',
]);

const CATEGORY_SKIP_REASONS = {
  animate:
    'Animation cases require dedicated time sampling; skipped for initial static rollout.',
  fonts:
    'Font-focused cases are unstable in headless Flutter tests (Ahem/system-font mismatch).',
  interact:
    'Interaction/event cases are non-deterministic for screenshot comparison.',
  script: 'Script-driven cases are non-deterministic for screenshot comparison.',
  svgdom: 'DOM scripting case; excluded from deterministic screenshot comparison.',
  text:
    'Text-focused cases are unstable in headless Flutter tests (Ahem/system-font mismatch).',
};

function parseArgs(argv) {
  const options = {
    index: DEFAULT_INDEX,
    out: DEFAULT_OUT,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--index' && i + 1 < argv.length) {
      options.index = path.resolve(argv[i + 1]);
      i += 1;
    } else if (arg === '--out' && i + 1 < argv.length) {
      options.out = path.resolve(argv[i + 1]);
      i += 1;
    } else if (arg === '--help' || arg === '-h') {
      printUsage();
      process.exit(0);
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }

  return options;
}

function printUsage() {
  console.log('Usage: node tool/w3c_goldens/generate_manifest.js [options]');
  console.log('');
  console.log('Options:');
  console.log('  --index <path>   Path to htmlObjectApproved/index.html');
  console.log('  --out <path>     Output JSON path');
}

function toRel(filePath) {
  return path.relative(PROJECT_ROOT, filePath).replace(/\\/g, '/');
}

function extract(pattern, content) {
  const match = content.match(pattern);
  return match ? match[1] : null;
}

function thresholdFor(category, tier) {
  if (tier === 'smoke') {
    return 0.12;
  }

  switch (category) {
    case 'coords':
    case 'shapes':
    case 'paths':
    case 'painting':
    case 'pservers':
    case 'color':
      return 0.10;
    case 'filters':
    case 'masking':
      return 0.08;
    default:
      return 0.08;
  }
}

function categoryOf(id) {
  const dash = id.indexOf('-');
  if (dash === -1) {
    return id;
  }
  return id.slice(0, dash);
}

function countBy(items, keyFn) {
  const out = {};
  for (const item of items) {
    const key = keyFn(item);
    out[key] = (out[key] || 0) + 1;
  }
  return out;
}

function getCaseFlags(svgContent) {
  return {
    hasAnimation: /<(?:animate|animateTransform|animateMotion|animateColor|set)\b/i.test(
      svgContent,
    ),
    hasExternalImageRef: /\.\.\/images\//.test(svgContent),
    hasImageElement: /<image\b[^>]*(?:xlink:href|href)=/i.test(svgContent),
    hasResourceRef: /\.\.\/resources\//.test(svgContent),
    hasScript: /<script\b/i.test(svgContent),
    hasTextElement: /<text\b/i.test(svgContent),
  };
}

function buildManifest(indexPath) {
  if (!fs.existsSync(indexPath)) {
    throw new Error(`Index file not found: ${indexPath}`);
  }

  const indexHtml = fs.readFileSync(indexPath, 'utf8');
  const ids = [];
  const seen = new Set();

  for (const match of indexHtml.matchAll(/href="([^"]+)\.html"/g)) {
    const id = match[1];
    if (!seen.has(id)) {
      ids.push(id);
      seen.add(id);
    }
  }

  const cases = ids.map((id) => {
    const category = categoryOf(id);
    const harnessHtmlPath = toRel(
      path.join(SUITE_ROOT, 'harness', 'htmlObjectApproved', `${id}.html`),
    );
    const svgPathAbs = path.join(SUITE_ROOT, 'svg', `${id}.svg`);
    const pngPathAbs = path.join(SUITE_ROOT, 'png', `${id}.png`);
    const svgExists = fs.existsSync(svgPathAbs);
    const pngExists = fs.existsSync(pngPathAbs);

    let svgContent = '';
    let flags = {
      hasAnimation: false,
      hasExternalImageRef: false,
      hasImageElement: false,
      hasResourceRef: false,
      hasScript: false,
      hasTextElement: false,
    };
    let status = null;
    let baseProfile = null;

    if (svgExists) {
      svgContent = fs.readFileSync(svgPathAbs, 'utf8');
      flags = getCaseFlags(svgContent);
      status = extract(/\bstatus="([^"]+)"/i, svgContent);
      baseProfile = extract(/\bbaseProfile="([^"]+)"/i, svgContent);
    }

    let skip = false;
    let skipReason = null;

    if (!svgExists) {
      skip = true;
      skipReason = 'Source SVG is missing in W3C_SVG_11_TestSuite/svg.';
    } else if (status && status !== 'accepted') {
      skip = true;
      skipReason = `Case status is "${status}" (only accepted cases are enabled).`;
    } else if (CATEGORY_SKIP_REASONS[category]) {
      skip = true;
      skipReason = CATEGORY_SKIP_REASONS[category];
    } else if (flags.hasExternalImageRef) {
      skip = true;
      skipReason =
        'Contains ../images references; excluded until relative image loading is wired for Flutter-side rendering.';
    } else if (flags.hasScript) {
      skip = true;
      skipReason = 'Contains <script>; excluded from deterministic screenshot pipeline.';
    } else if (flags.hasAnimation) {
      skip = true;
      skipReason =
        'Contains animation elements; include later with controlled animation time sampling.';
    }

    let tier = 'extended';
    if (!skip && SMOKE_IDS.has(id)) {
      tier = 'smoke';
    } else if (!skip && CORE_CATEGORIES.has(category)) {
      tier = 'core';
    }

    return {
      id,
      category,
      tier,
      threshold: thresholdFor(category, tier),
      perPixelThreshold: 0.20,
      animationTimeMs: 0,
      skip,
      skipReason,
      status,
      baseProfile,
      svgPath: toRel(svgPathAbs),
      harnessHtmlPath,
      referencePngPath: toRel(pngPathAbs),
      referencePngExists: pngExists,
      browserGoldenPath: `test/goldens/w3c/browser/${id}.png`,
      flutterGoldenPath: `test/goldens/w3c/flutter/${id}.png`,
      diffPath: `test/goldens/w3c/diff/${id}.png`,
      flags,
    };
  });

  const manifest = {
    schemaVersion: 1,
    generatedAt: new Date().toISOString(),
    source: {
      suiteRoot: toRel(SUITE_ROOT),
      harnessIndex: toRel(indexPath),
      generator: toRel(path.join(__dirname, 'generate_manifest.js')),
    },
    summary: {
      totalCases: cases.length,
      byTier: countBy(cases, (c) => c.tier),
      skipped: cases.filter((c) => c.skip).length,
      runnable: cases.filter((c) => !c.skip).length,
      byCategory: countBy(cases, (c) => c.category),
    },
    cases,
  };

  return manifest;
}

function main() {
  const options = parseArgs(process.argv.slice(2));
  const manifest = buildManifest(options.index);

  fs.mkdirSync(path.dirname(options.out), { recursive: true });
  fs.writeFileSync(options.out, `${JSON.stringify(manifest, null, 2)}\n`);

  const smokeRunnable = manifest.cases.filter(
    (c) => c.tier === 'smoke' && !c.skip,
  ).length;
  const coreRunnable = manifest.cases.filter(
    (c) => c.tier === 'core' && !c.skip,
  ).length;
  const extendedRunnable = manifest.cases.filter(
    (c) => c.tier === 'extended' && !c.skip,
  ).length;

  console.log(`Manifest written: ${options.out}`);
  console.log(`Total cases: ${manifest.summary.totalCases}`);
  console.log(`Runnable: ${manifest.summary.runnable}`);
  console.log(`Skipped: ${manifest.summary.skipped}`);
  console.log(`Runnable by tier: smoke=${smokeRunnable}, core=${coreRunnable}, extended=${extendedRunnable}`);
}

try {
  main();
} catch (error) {
  console.error(`Error: ${error.message}`);
  process.exit(1);
}
