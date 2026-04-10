#!/usr/bin/env node

/**
 * Lower per-case thresholds in W3C manifest based on a measured report.
 *
 * Usage:
 *   node tool/w3c_goldens/calibrate_thresholds.js \
 *     --report test/goldens/w3c/reports/w3c_report_all_*.json \
 *     --manifest tool/w3c_goldens/w3c_manifest.json \
 *     --margin 0.01
 */

const fs = require('fs');
const path = require('path');

function parseArgs(argv) {
  const options = {
    report: null,
    manifest: path.resolve(process.cwd(), 'tool/w3c_goldens/w3c_manifest.json'),
    margin: 0.01,
    minThreshold: 0.0,
    dryRun: false,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--report' && i + 1 < argv.length) {
      options.report = path.resolve(argv[i + 1]);
      i += 1;
    } else if (arg === '--manifest' && i + 1 < argv.length) {
      options.manifest = path.resolve(argv[i + 1]);
      i += 1;
    } else if (arg === '--margin' && i + 1 < argv.length) {
      options.margin = Number(argv[i + 1]);
      i += 1;
    } else if (arg === '--min-threshold' && i + 1 < argv.length) {
      options.minThreshold = Number(argv[i + 1]);
      i += 1;
    } else if (arg === '--dry-run') {
      options.dryRun = true;
    } else if (arg === '--help' || arg === '-h') {
      printHelp();
      process.exit(0);
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }

  if (!options.report) {
    throw new Error('--report is required.');
  }
  if (!Number.isFinite(options.margin) || options.margin < 0 || options.margin > 1) {
    throw new Error('--margin must be in range [0, 1].');
  }
  if (!Number.isFinite(options.minThreshold) || options.minThreshold < 0 || options.minThreshold > 1) {
    throw new Error('--min-threshold must be in range [0, 1].');
  }

  return options;
}

function printHelp() {
  console.log('Usage: node tool/w3c_goldens/calibrate_thresholds.js --report <report.json> [options]');
  console.log('');
  console.log('Options:');
  console.log('  --manifest <path>       Manifest path (default: tool/w3c_goldens/w3c_manifest.json)');
  console.log('  --margin <number>       Safety margin subtracted from measured similarity (default: 0.01)');
  console.log('  --min-threshold <num>   Lower bound for thresholds (default: 0.0)');
  console.log('  --dry-run               Print summary without writing manifest');
}

function round4(value) {
  return Math.round(value * 10000) / 10000;
}

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

function main() {
  const options = parseArgs(process.argv.slice(2));

  const manifest = JSON.parse(fs.readFileSync(options.manifest, 'utf8'));
  const report = JSON.parse(fs.readFileSync(options.report, 'utf8'));

  const similarities = new Map();
  for (const result of report.results || []) {
    if (!result || typeof result.id !== 'string') {
      continue;
    }
    if (typeof result.similarity !== 'number') {
      continue;
    }
    similarities.set(result.id, result.similarity);
  }

  let changed = 0;
  let unchanged = 0;
  let missing = 0;

  for (const testCase of manifest.cases || []) {
    const similarity = similarities.get(testCase.id);
    if (similarity == null) {
      missing += 1;
      continue;
    }

    const oldThreshold = Number(testCase.threshold);
    if (!Number.isFinite(oldThreshold)) {
      missing += 1;
      continue;
    }

    const calibrated = clamp(similarity - options.margin, options.minThreshold, 1);
    const newThreshold = round4(Math.min(oldThreshold, calibrated));

    if (newThreshold < oldThreshold) {
      testCase.threshold = newThreshold;
      changed += 1;
    } else {
      unchanged += 1;
    }
  }

  manifest.generatedAt = new Date().toISOString();
  manifest.calibratedFrom = {
    reportPath: path.relative(process.cwd(), options.report).replace(/\\/g, '/'),
    margin: options.margin,
    minThreshold: options.minThreshold,
    updatedAt: new Date().toISOString(),
  };

  if (!options.dryRun) {
    fs.writeFileSync(options.manifest, `${JSON.stringify(manifest, null, 2)}\n`);
  }

  console.log(`Manifest: ${options.manifest}`);
  console.log(`Report  : ${options.report}`);
  console.log(`Changed : ${changed}`);
  console.log(`Unchanged: ${unchanged}`);
  console.log(`Missing : ${missing}`);
  console.log(`Mode    : ${options.dryRun ? 'dry-run' : 'written'}`);
}

try {
  main();
} catch (error) {
  console.error(`Error: ${error.message}`);
  process.exit(1);
}
