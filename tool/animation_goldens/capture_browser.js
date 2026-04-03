#!/usr/bin/env node

/**
 * Animated SVG Frame Capture Script
 *
 * Renders animated SVG files in headless Chromium and captures PNG frames
 * at specified time points using the SVG DOM API (pauseAnimations + setCurrentTime).
 *
 * Usage:
 *   node capture_browser.js [options] <svg-files...>
 *
 * Options:
 *   --width <n>       Viewport width (default: 800)
 *   --height <n>      Viewport height (default: 600)
 *   --duration <n>    Total animation duration in seconds (default: 15)
 *   --frames <n>      Number of frames to capture (default: 15)
 *   --output <dir>    Output directory (default: test/animation_goldens/browser/)
 *
 * Examples:
 *   node capture_browser.js test/animation_goldens/svg_fixtures/*.svg
 *   node capture_browser.js --frames 30 --duration 10 test/animation_goldens/svg_fixtures/animate_position.svg
 */

const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

// ---------------------------------------------------------------------------
// Argument parsing
// ---------------------------------------------------------------------------

function parseArgs(args) {
  const options = {
    width: 800,
    height: 600,
    duration: 15,
    frames: 15,
    output: 'test/animation_goldens/browser/',
    files: [],
  };

  let i = 0;
  while (i < args.length) {
    const arg = args[i];
    if (arg === '--width' && i + 1 < args.length) {
      options.width = parseInt(args[i + 1], 10);
      i += 2;
    } else if (arg === '--height' && i + 1 < args.length) {
      options.height = parseInt(args[i + 1], 10);
      i += 2;
    } else if (arg === '--duration' && i + 1 < args.length) {
      options.duration = parseFloat(args[i + 1]);
      i += 2;
    } else if (arg === '--frames' && i + 1 < args.length) {
      options.frames = parseInt(args[i + 1], 10);
      i += 2;
    } else if (arg === '--output' && i + 1 < args.length) {
      options.output = args[i + 1];
      i += 2;
    } else if (!arg.startsWith('--')) {
      options.files.push(arg);
      i++;
    } else {
      console.error(`Unknown option: ${arg}`);
      i++;
    }
  }

  return options;
}

// ---------------------------------------------------------------------------
// HTML generation
// ---------------------------------------------------------------------------

function generateHtml(svgContent, width, height) {
  return `<!DOCTYPE html>
<html>
<head>
  <style>
    * { margin: 0; padding: 0; }
    body { width: ${width}px; height: ${height}px; overflow: hidden; background: white; }
    svg { width: 100%; height: 100%; display: block; }
  </style>
</head>
<body>${svgContent}</body>
</html>`;
}

// ---------------------------------------------------------------------------
// Frame capture for a single SVG
// ---------------------------------------------------------------------------

async function captureAnimationFrames(page, svgPath, outputDir, options) {
  const { width, height, duration, frames } = options;
  const absolutePath = path.resolve(process.cwd(), svgPath);
  const baseName = path.basename(svgPath, '.svg');
  const svgOutputDir = path.join(outputDir, baseName);

  // Create per-SVG output directory
  if (!fs.existsSync(svgOutputDir)) {
    fs.mkdirSync(svgOutputDir, { recursive: true });
  }

  // Read SVG content
  const svgContent = fs.readFileSync(absolutePath, 'utf-8');
  const html = generateHtml(svgContent, width, height);

  // Set viewport
  await page.setViewport({ width, height });

  // Load HTML
  await page.setContent(html, { waitUntil: 'networkidle0' });

  // Wait for fonts
  await page.evaluate(() => document.fonts.ready);

  // Small initial delay
  await new Promise((r) => setTimeout(r, 100));

  // Pause all SMIL animations so we can seek deterministically
  await page.evaluate(() => {
    const svg = document.querySelector('svg');
    if (svg && typeof svg.pauseAnimations === 'function') {
      svg.pauseAnimations();
    }
  });

  // Pause CSS animations via Web Animations API for precise seeking.
  // Using getAnimations() + currentTime instead of animation-delay hack
  // avoids Chrome's imprecise behavior with animation-delay: -0s not
  // properly computing stop-color values on gradient stops.
  const hasWebAnimations = await page.evaluate(() => {
    const allAnimations = document.getAnimations();
    if (allAnimations.length > 0) {
      allAnimations.forEach((anim) => anim.pause());
      return true;
    }
    // Fallback: pause via style for SVGs without Web Animations support
    document.querySelectorAll('*').forEach((el) => {
      el.style.animationPlayState = 'paused';
    });
    return false;
  });

  const capturedFrames = [];

  for (let i = 0; i < frames; i++) {
    // Include both loop endpoints: t=0 and t=duration.
    const frameProgress = frames > 1 ? i / (frames - 1) : 0;
    const timeSeconds = duration * frameProgress;
    const frameIndex = String(i).padStart(2, '0');
    const framePath = path.join(svgOutputDir, `frame_${frameIndex}.png`);

    // Seek SMIL to the target time
    await page.evaluate((t) => {
      const svg = document.querySelector('svg');
      if (svg && typeof svg.setCurrentTime === 'function') {
        svg.setCurrentTime(t);
      }
    }, timeSeconds);

    // Seek CSS animations to the target time
    if (hasWebAnimations) {
      await page.evaluate((t) => {
        const allAnimations = document.getAnimations();
        allAnimations.forEach((anim) => {
          anim.currentTime = t * 1000;
        });
      }, timeSeconds);
    } else {
      await page.evaluate((t) => {
        document.querySelectorAll('*').forEach((el) => {
          if (el.style) {
            el.style.animationDelay = `-${t}s`;
            el.style.animationPlayState = 'paused';
          }
        });
      }, timeSeconds);
    }

    // Small settle delay for rendering
    await new Promise((r) => setTimeout(r, 50));

    // Capture screenshot
    await page.screenshot({
      type: 'png',
      path: framePath,
      clip: { x: 0, y: 0, width, height },
    });

    capturedFrames.push({ frame: i, time: timeSeconds, path: framePath });
  }

  return { svg: baseName, frames: capturedFrames };
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  const args = process.argv.slice(2);
  const options = parseArgs(args);

  if (options.files.length === 0) {
    console.error('Usage: node capture_browser.js [options] <svg-files...>');
    console.error('');
    console.error('Options:');
    console.error('  --width <n>       Viewport width (default: 800)');
    console.error('  --height <n>      Viewport height (default: 600)');
    console.error('  --duration <n>    Animation duration in seconds (default: 15)');
    console.error('  --frames <n>      Number of frames (default: 15)');
    console.error('  --output <dir>    Output directory (default: test/animation_goldens/browser/)');
    process.exit(1);
  }

  const outputDir = path.resolve(process.cwd(), options.output);
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  console.log('='.repeat(60));
  console.log('  Animated SVG Browser Frame Capture');
  console.log('='.repeat(60));
  console.log(`  Viewport : ${options.width}x${options.height}`);
  console.log(`  Duration : ${options.duration}s`);
  console.log(`  Frames   : ${options.frames}`);
  console.log(`  Output   : ${outputDir}`);
  console.log(`  SVGs     : ${options.files.length}`);
  console.log('='.repeat(60));
  console.log('');

  const results = { success: [], failed: [] };

  // Launch browser
  console.log('Launching headless browser...');
  const browser = await puppeteer.launch({ headless: 'new' });

  try {
    const page = await browser.newPage();

    for (const svgPath of options.files) {
      const absolutePath = path.resolve(process.cwd(), svgPath);

      if (!fs.existsSync(absolutePath)) {
        console.error(`  ERROR: File not found: ${svgPath}`);
        results.failed.push({ path: svgPath, error: 'File not found' });
        continue;
      }

      if (!svgPath.toLowerCase().endsWith('.svg')) {
        console.error(`  ERROR: Not an SVG file: ${svgPath}`);
        results.failed.push({ path: svgPath, error: 'Not an SVG file' });
        continue;
      }

      try {
        const baseName = path.basename(svgPath, '.svg');
        console.log(`  Capturing: ${baseName} (${options.frames} frames)...`);

        const result = await captureAnimationFrames(page, svgPath, outputDir, options);
        results.success.push(result);

        console.log(`    -> ${result.frames.length} frames saved to ${path.relative(process.cwd(), path.join(outputDir, baseName))}/`);
      } catch (err) {
        console.error(`  ERROR capturing ${svgPath}: ${err.message}`);
        results.failed.push({ path: svgPath, error: err.message });
      }
    }
  } finally {
    await browser.close();
  }

  // Summary
  console.log('');
  console.log('='.repeat(60));
  console.log(`  Captured: ${results.success.length} SVGs (${results.success.reduce((s, r) => s + r.frames.length, 0)} total frames)`);
  if (results.failed.length > 0) {
    console.log(`  Failed  : ${results.failed.length}`);
    for (const f of results.failed) {
      console.log(`    - ${f.path}: ${f.error}`);
    }
  }
  console.log('='.repeat(60));

  process.exit(results.failed.length > 0 ? 1 : 0);
}

main().catch((err) => {
  console.error('Fatal error:', err.message);
  process.exit(1);
});
