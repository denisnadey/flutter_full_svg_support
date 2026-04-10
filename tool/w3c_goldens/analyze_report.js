#!/usr/bin/env node
/* eslint-disable no-console */

const fs = require("fs");
const path = require("path");

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (!token.startsWith("--")) {
      continue;
    }
    const key = token.slice(2);
    const next = argv[i + 1];
    if (!next || next.startsWith("--")) {
      args[key] = true;
      continue;
    }
    args[key] = next;
    i += 1;
  }
  return args;
}

function safePercent(value) {
  if (typeof value !== "number" || Number.isNaN(value)) {
    return "-";
  }
  return `${(value * 100).toFixed(1)}%`;
}

function toNumber(value) {
  if (typeof value === "number") {
    return value;
  }
  const parsed = Number(value);
  if (Number.isNaN(parsed)) {
    return null;
  }
  return parsed;
}

function computeStatusCounts(results) {
  const counts = {};
  for (const result of results) {
    const status = result.status || "unknown";
    counts[status] = (counts[status] || 0) + 1;
  }
  return counts;
}

function groupByCategory(results) {
  const grouped = new Map();
  for (const result of results) {
    const category = result.category || "unknown";
    if (!grouped.has(category)) {
      grouped.set(category, {
        category,
        total: 0,
        pass: 0,
        failThreshold: 0,
        technicalFail: 0,
      });
    }
    const row = grouped.get(category);
    row.total += 1;
    if (result.status === "pass") {
      row.pass += 1;
    } else if (result.status === "fail_threshold") {
      row.failThreshold += 1;
    } else if (result.status === "capture_failed" || result.status === "compare_failed") {
      row.technicalFail += 1;
    }
  }
  return [...grouped.values()].sort((a, b) => {
    if (b.failThreshold !== a.failThreshold) {
      return b.failThreshold - a.failThreshold;
    }
    if (b.technicalFail !== a.technicalFail) {
      return b.technicalFail - a.technicalFail;
    }
    return a.category.localeCompare(b.category);
  });
}

function buildMarkdown(report, reportPath) {
  const results = Array.isArray(report.results) ? report.results : [];
  const statusCounts = report.statusCounts || computeStatusCounts(results);
  const selectedCases = report?.counts?.selectedCases ?? results.length;
  const recordedResults = report?.counts?.recordedResults ?? results.length;
  const missingResultIds = Array.isArray(report.missingResultIds)
    ? report.missingResultIds
    : [];
  const byCategory = groupByCategory(results);

  const thresholdFailures = results
    .filter((r) => r.status === "fail_threshold")
    .sort((a, b) => {
      const aSimilarity = toNumber(a.similarity);
      const bSimilarity = toNumber(b.similarity);
      if (aSimilarity == null && bSimilarity == null) {
        return 0;
      }
      if (aSimilarity == null) {
        return 1;
      }
      if (bSimilarity == null) {
        return -1;
      }
      return aSimilarity - bSimilarity;
    });

  const technicalFailures = results.filter(
    (r) => r.status === "capture_failed" || r.status === "compare_failed",
  );

  const lines = [];
  lines.push("# W3C Diagnostic Report");
  lines.push("");
  lines.push(`- Source: \`${reportPath}\``);
  lines.push(`- Generated at: \`${report.generatedAt || "unknown"}\``);
  lines.push(`- Selected cases: **${selectedCases}**`);
  lines.push(`- Recorded results: **${recordedResults}**`);
  lines.push("");
  lines.push("## Status Counts");
  lines.push("");
  lines.push("| Status | Count |");
  lines.push("|---|---:|");
  for (const [status, count] of Object.entries(statusCounts).sort((a, b) => {
    if (b[1] !== a[1]) {
      return b[1] - a[1];
    }
    return a[0].localeCompare(b[0]);
  })) {
    lines.push(`| ${status} | ${count} |`);
  }
  lines.push("");
  lines.push("## Category Breakdown");
  lines.push("");
  lines.push("| Category | Total | Pass | Threshold Fails | Technical Fails |");
  lines.push("|---|---:|---:|---:|---:|");
  for (const row of byCategory) {
    lines.push(
      `| ${row.category} | ${row.total} | ${row.pass} | ${row.failThreshold} | ${row.technicalFail} |`,
    );
  }
  lines.push("");
  lines.push("## Top Threshold Failures");
  lines.push("");
  lines.push("| ID | Category | Tier | Similarity | Threshold | Diff Pixels |");
  lines.push("|---|---|---|---:|---:|---:|");
  for (const row of thresholdFailures.slice(0, 50)) {
    const differentPixels = toNumber(row.differentPixels);
    const totalPixels = toNumber(row.totalPixels);
    const diffText =
      differentPixels != null && totalPixels != null
        ? `${differentPixels}/${totalPixels}`
        : "-";
    lines.push(
      `| ${row.id} | ${row.category || "unknown"} | ${row.tier || "unknown"} | ${safePercent(
        toNumber(row.similarity),
      )} | ${safePercent(toNumber(row.threshold))} | ${diffText} |`,
    );
  }
  if (thresholdFailures.length === 0) {
    lines.push("| - | - | - | - | - | - |");
  }
  lines.push("");
  lines.push("## Technical Failures");
  lines.push("");
  if (technicalFailures.length === 0) {
    lines.push("- None");
  } else {
    for (const row of technicalFailures) {
      lines.push(
        `- \`${row.id}\` (${row.status})${row.message ? `: ${row.message}` : ""}`,
      );
    }
  }
  lines.push("");
  lines.push("## Missing Results");
  lines.push("");
  if (missingResultIds.length === 0) {
    lines.push("- None");
  } else {
    for (const id of missingResultIds.slice(0, 100)) {
      lines.push(`- \`${id}\``);
    }
    if (missingResultIds.length > 100) {
      lines.push(`- ... and ${missingResultIds.length - 100} more`);
    }
  }
  lines.push("");

  return lines.join("\n");
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const inputPath = path.resolve(
    args.input || "test/goldens/w3c/reports/w3c_latest_report.json",
  );
  const outputPath = path.resolve(
    args.output || inputPath.replace(/\.json$/i, ".md"),
  );

  if (!fs.existsSync(inputPath)) {
    console.error(`Report file not found: ${inputPath}`);
    process.exit(1);
  }

  const report = JSON.parse(fs.readFileSync(inputPath, "utf8"));
  const markdown = buildMarkdown(report, inputPath);

  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, markdown);

  const results = Array.isArray(report.results) ? report.results : [];
  const statusCounts = report.statusCounts || computeStatusCounts(results);
  const thresholdFails = statusCounts.fail_threshold || 0;
  const technicalFails = (statusCounts.capture_failed || 0) + (statusCounts.compare_failed || 0);

  console.log(`Input report : ${inputPath}`);
  console.log(`Output report: ${outputPath}`);
  console.log(`Total results: ${results.length}`);
  console.log(`Threshold fails: ${thresholdFails}`);
  console.log(`Technical fails: ${technicalFails}`);
}

main();
