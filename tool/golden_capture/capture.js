#!/usr/bin/env node

/**
 * SVG Golden Reference Capture Script
 * 
 * Renders SVG files in headless Chromium and captures PNG screenshots
 * as golden reference images for visual regression testing.
 * 
 * Usage:
 *   node capture.js [options] <svg-files...>
 * 
 * Options:
 *   --width <n>     Viewport width (default: 800)
 *   --height <n>    Viewport height (default: 600)
 *   --output <dir>  Output directory (default: test/goldens/browser/)
 * 
 * Examples:
 *   node capture.js example/assets/astronaut_helmet.svg
 *   node capture.js --width 400 --height 300 example/assets/*.svg
 *   node capture.js --output ./goldens example/assets/logo.svg
 */

const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

// Parse command-line arguments
function parseArgs(args) {
  const options = {
    width: 800,
    height: 600,
    output: 'test/goldens/browser/',
    files: []
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

// Generate HTML page that embeds the SVG inline
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

// Capture a single SVG file
async function captureSvg(page, svgPath, outputDir, width, height) {
  const absolutePath = path.resolve(process.cwd(), svgPath);
  const baseName = path.basename(svgPath, '.svg');
  const outputPath = path.join(outputDir, `${baseName}.png`);

  // Read SVG content
  const svgContent = fs.readFileSync(absolutePath, 'utf-8');

  // Generate HTML with embedded SVG
  const html = generateHtml(svgContent, width, height);

  // Set viewport
  await page.setViewport({ width, height });

  // Load the HTML content
  await page.setContent(html, { waitUntil: 'networkidle0' });

  // Wait for fonts to load
  await page.evaluate(() => document.fonts.ready);

  // Additional delay for any remaining rendering
  await new Promise(resolve => setTimeout(resolve, 100));

  // Capture screenshot
  await page.screenshot({
    type: 'png',
    path: outputPath,
    clip: { x: 0, y: 0, width, height }
  });

  return outputPath;
}

// Main capture function
async function main() {
  const args = process.argv.slice(2);
  const options = parseArgs(args);

  if (options.files.length === 0) {
    console.error('Usage: node capture.js [options] <svg-files...>');
    console.error('');
    console.error('Options:');
    console.error('  --width <n>     Viewport width (default: 800)');
    console.error('  --height <n>    Viewport height (default: 600)');
    console.error('  --output <dir>  Output directory (default: test/goldens/browser/)');
    console.error('');
    console.error('Examples:');
    console.error('  node capture.js example/assets/astronaut_helmet.svg');
    console.error('  node capture.js --width 400 --height 300 example/assets/*.svg');
    process.exit(1);
  }

  // Create output directory if it doesn't exist
  const outputDir = path.resolve(process.cwd(), options.output);
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  // Track results
  const results = {
    success: [],
    failed: []
  };

  // Launch browser
  console.log(`Launching headless browser (viewport: ${options.width}x${options.height})...`);
  const browser = await puppeteer.launch({
    headless: 'new'
  });

  try {
    const page = await browser.newPage();

    // Process each SVG file
    for (const svgPath of options.files) {
      const absolutePath = path.resolve(process.cwd(), svgPath);
      
      // Check if file exists
      if (!fs.existsSync(absolutePath)) {
        console.error(`Error: File not found: ${svgPath}`);
        results.failed.push({ path: svgPath, error: 'File not found' });
        continue;
      }

      // Check if it's an SVG file
      if (!svgPath.toLowerCase().endsWith('.svg')) {
        console.error(`Error: Not an SVG file: ${svgPath}`);
        results.failed.push({ path: svgPath, error: 'Not an SVG file' });
        continue;
      }

      try {
        const relativeSvgPath = path.relative(process.cwd(), absolutePath);
        const outputPath = await captureSvg(page, absolutePath, outputDir, options.width, options.height);
        const relativeOutputPath = path.relative(process.cwd(), outputPath);
        
        console.log(`Capturing: ${relativeSvgPath} -> ${relativeOutputPath}`);
        results.success.push({ input: relativeSvgPath, output: relativeOutputPath });
      } catch (err) {
        console.error(`Error capturing ${svgPath}: ${err.message}`);
        results.failed.push({ path: svgPath, error: err.message });
      }
    }
  } finally {
    await browser.close();
  }

  // Print summary
  console.log('');
  console.log('='.repeat(50));
  
  if (results.success.length > 0) {
    console.log(`Captured ${results.success.length} SVG(s) successfully`);
  }
  
  if (results.failed.length > 0) {
    console.log(`Failed to capture ${results.failed.length} file(s):`);
    for (const fail of results.failed) {
      console.log(`  - ${fail.path}: ${fail.error}`);
    }
  }

  // Exit with error code if any failures
  process.exit(results.failed.length > 0 ? 1 : 0);
}

// Run main function
main().catch(err => {
  console.error('Fatal error:', err.message);
  process.exit(1);
});
