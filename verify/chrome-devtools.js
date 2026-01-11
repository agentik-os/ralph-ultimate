#!/usr/bin/env node
/**
 * Ralph Ultimate v4 - Chrome DevTools Logs Capture
 * Captures console, network, performance, and errors
 */

const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

async function captureDevToolsLogs(url, options = {}) {
  const {
    outputPath = '.claude/logs/devtools.json',
    timeout = 30000,
    waitTime = 5000,
    headless = true,
    capturePerformance = true,
    captureNetwork = true,
    captureConsole = true
  } = options;

  // Ensure output directory exists
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });

  const browser = await chromium.launch({ headless });
  const context = await browser.newContext({
    viewport: { width: 1920, height: 1080 }
  });
  const page = await context.newPage();

  const logs = {
    url,
    capturedAt: new Date().toISOString(),
    console: [],
    network: {
      requests: [],
      failed: [],
      slow: []
    },
    performance: {
      timing: {},
      webVitals: {},
      resources: []
    },
    errors: [],
    warnings: [],
    summary: {
      totalRequests: 0,
      failedRequests: 0,
      slowRequests: 0,
      consoleErrors: 0,
      consoleWarnings: 0,
      jsErrors: 0
    }
  };

  // Track request timings
  const requestTimings = new Map();

  if (captureConsole) {
    page.on('console', msg => {
      const entry = {
        type: msg.type(),
        text: msg.text(),
        location: msg.location(),
        timestamp: Date.now()
      };

      logs.console.push(entry);

      if (msg.type() === 'error') {
        logs.summary.consoleErrors++;
      } else if (msg.type() === 'warning') {
        logs.summary.consoleWarnings++;
      }
    });

    page.on('pageerror', error => {
      logs.errors.push({
        type: 'javascript',
        message: error.message,
        stack: error.stack,
        timestamp: Date.now()
      });
      logs.summary.jsErrors++;
    });
  }

  if (captureNetwork) {
    page.on('request', request => {
      const reqData = {
        id: request.url() + Date.now(),
        url: request.url(),
        method: request.method(),
        resourceType: request.resourceType(),
        headers: request.headers(),
        startTime: Date.now()
      };
      requestTimings.set(request.url(), reqData);
      logs.summary.totalRequests++;
    });

    page.on('response', async response => {
      const reqData = requestTimings.get(response.url());
      if (reqData) {
        reqData.status = response.status();
        reqData.statusText = response.statusText();
        reqData.endTime = Date.now();
        reqData.duration = reqData.endTime - reqData.startTime;
        reqData.responseHeaders = response.headers();

        // Try to get response size
        try {
          const body = await response.body();
          reqData.size = body.length;
        } catch (e) {
          reqData.size = 0;
        }

        logs.network.requests.push(reqData);

        // Track failed requests
        if (response.status() >= 400) {
          logs.network.failed.push({
            url: response.url(),
            status: response.status(),
            statusText: response.statusText()
          });
          logs.summary.failedRequests++;
        }

        // Track slow requests (>3s)
        if (reqData.duration > 3000) {
          logs.network.slow.push({
            url: response.url(),
            duration: reqData.duration,
            resourceType: reqData.resourceType
          });
          logs.summary.slowRequests++;
        }
      }
    });

    page.on('requestfailed', request => {
      logs.network.failed.push({
        url: request.url(),
        error: request.failure()?.errorText || 'Unknown error',
        resourceType: request.resourceType()
      });
      logs.summary.failedRequests++;
    });
  }

  console.log(`📊 Capturing DevTools logs for: ${url}`);

  try {
    // Navigate
    const startTime = Date.now();
    await page.goto(url, { waitUntil: 'networkidle', timeout });
    const loadTime = Date.now() - startTime;

    // Basic timing
    logs.performance.timing.navigationToLoad = loadTime;

    if (capturePerformance) {
      // Wait for page to stabilize
      await page.waitForTimeout(waitTime);

      // Get Navigation Timing
      const navTiming = await page.evaluate(() => {
        const timing = performance.timing;
        return {
          dns: timing.domainLookupEnd - timing.domainLookupStart,
          tcp: timing.connectEnd - timing.connectStart,
          ttfb: timing.responseStart - timing.navigationStart,
          download: timing.responseEnd - timing.responseStart,
          domInteractive: timing.domInteractive - timing.navigationStart,
          domContentLoaded: timing.domContentLoadedEventEnd - timing.navigationStart,
          load: timing.loadEventEnd - timing.navigationStart
        };
      });
      logs.performance.timing = { ...logs.performance.timing, ...navTiming };

      // Get Web Vitals (best effort)
      const webVitals = await page.evaluate(() => {
        return new Promise(resolve => {
          const vitals = {};

          // LCP
          try {
            const lcpEntries = performance.getEntriesByType('largest-contentful-paint');
            if (lcpEntries.length > 0) {
              vitals.lcp = lcpEntries[lcpEntries.length - 1].startTime;
            }
          } catch (e) {}

          // FCP
          try {
            const fcpEntry = performance.getEntriesByName('first-contentful-paint')[0];
            if (fcpEntry) {
              vitals.fcp = fcpEntry.startTime;
            }
          } catch (e) {}

          // CLS (cumulative)
          try {
            let cls = 0;
            const clsEntries = performance.getEntriesByType('layout-shift');
            clsEntries.forEach(entry => {
              if (!entry.hadRecentInput) cls += entry.value;
            });
            vitals.cls = cls;
          } catch (e) {}

          // Resource timing
          try {
            const resources = performance.getEntriesByType('resource');
            vitals.resourceCount = resources.length;
            vitals.totalResourceSize = resources.reduce((sum, r) => sum + (r.transferSize || 0), 0);
          } catch (e) {}

          setTimeout(() => resolve(vitals), 1000);
        });
      });
      logs.performance.webVitals = webVitals;

      // Get resource breakdown
      const resources = await page.evaluate(() => {
        return performance.getEntriesByType('resource').map(r => ({
          name: r.name,
          type: r.initiatorType,
          duration: r.duration,
          size: r.transferSize || 0,
          startTime: r.startTime
        }));
      });
      logs.performance.resources = resources;
    }

  } catch (error) {
    logs.errors.push({
      type: 'navigation',
      message: error.message,
      timestamp: Date.now()
    });
  }

  await browser.close();

  // Generate summary
  logs.summary.loadTime = logs.performance.timing.load || logs.performance.timing.navigationToLoad;

  // Performance grades
  logs.summary.grades = {
    ttfb: logs.performance.timing.ttfb < 200 ? 'good' :
      logs.performance.timing.ttfb < 500 ? 'needs-improvement' : 'poor',
    lcp: logs.performance.webVitals.lcp < 2500 ? 'good' :
      logs.performance.webVitals.lcp < 4000 ? 'needs-improvement' : 'poor',
    cls: logs.performance.webVitals.cls < 0.1 ? 'good' :
      logs.performance.webVitals.cls < 0.25 ? 'needs-improvement' : 'poor'
  };

  // Write logs
  fs.writeFileSync(outputPath, JSON.stringify(logs, null, 2));
  console.log(`\n📁 DevTools logs saved to: ${outputPath}`);

  // Print summary
  console.log('\n📊 Summary:');
  console.log(`   Load time: ${logs.summary.loadTime}ms`);
  console.log(`   TTFB: ${logs.performance.timing.ttfb}ms (${logs.summary.grades.ttfb})`);
  if (logs.performance.webVitals.lcp) {
    console.log(`   LCP: ${Math.round(logs.performance.webVitals.lcp)}ms (${logs.summary.grades.lcp})`);
  }
  if (logs.performance.webVitals.cls !== undefined) {
    console.log(`   CLS: ${logs.performance.webVitals.cls.toFixed(3)} (${logs.summary.grades.cls})`);
  }
  console.log(`   Total requests: ${logs.summary.totalRequests}`);
  console.log(`   Failed requests: ${logs.summary.failedRequests}`);
  console.log(`   Slow requests (>3s): ${logs.summary.slowRequests}`);
  console.log(`   Console errors: ${logs.summary.consoleErrors}`);
  console.log(`   JS errors: ${logs.summary.jsErrors}`);

  return logs;
}

async function captureMultiplePages(urls, options = {}) {
  const results = [];

  for (const url of urls) {
    const outputPath = options.outputDir
      ? path.join(options.outputDir, `devtools-${new URL(url).pathname.replace(/\//g, '-')}.json`)
      : `.claude/logs/devtools-${Date.now()}.json`;

    const result = await captureDevToolsLogs(url, { ...options, outputPath });
    results.push(result);
  }

  return results;
}

// CLI usage
if (require.main === module) {
  const args = process.argv.slice(2);

  if (args.length < 1) {
    console.log('Usage: chrome-devtools.js <url> [outputPath]');
    console.log('       chrome-devtools.js --urls <url1> <url2> ... [--output-dir <dir>]');
    process.exit(1);
  }

  if (args[0] === '--urls') {
    const urls = [];
    let outputDir = '.claude/logs';

    for (let i = 1; i < args.length; i++) {
      if (args[i] === '--output-dir') {
        outputDir = args[++i];
      } else {
        urls.push(args[i]);
      }
    }

    captureMultiplePages(urls, { outputDir }).then(() => {
      console.log('\n✅ All pages captured');
    });
  } else {
    const url = args[0];
    const outputPath = args[1] || `.claude/logs/devtools-${Date.now()}.json`;

    captureDevToolsLogs(url, { outputPath }).then(logs => {
      const hasErrors = logs.summary.jsErrors > 0 || logs.summary.failedRequests > 0;
      process.exit(hasErrors ? 1 : 0);
    });
  }
}

module.exports = { captureDevToolsLogs, captureMultiplePages };
