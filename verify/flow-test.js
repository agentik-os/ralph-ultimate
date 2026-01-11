#!/usr/bin/env node
/**
 * Ralph Ultimate v4 - AI Flow Testing
 * Simulates user interactions with Playwright
 */

const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

async function runFlowTest(scenario, baseUrl, options = {}) {
  const {
    screenshotDir = '.claude/screenshots',
    videoDir = '.claude/videos',
    timeout = 10000,
    headless = true
  } = options;

  // Ensure directories exist
  fs.mkdirSync(screenshotDir, { recursive: true });
  fs.mkdirSync(videoDir, { recursive: true });

  const browser = await chromium.launch({ headless });
  const context = await browser.newContext({
    viewport: { width: 1920, height: 1080 },
    recordVideo: { dir: videoDir }
  });
  const page = await context.newPage();

  const results = {
    scenario: scenario.name,
    passed: true,
    startTime: Date.now(),
    steps: [],
    errors: [],
    screenshots: [],
    video: null
  };

  console.log(`\n🎬 Running flow test: ${scenario.name}`);

  for (let i = 0; i < scenario.steps.length; i++) {
    const step = scenario.steps[i];
    const stepResult = {
      index: i + 1,
      action: step.action,
      params: { ...step },
      status: 'pending',
      duration: 0
    };
    delete stepResult.params.action;

    const stepStart = Date.now();

    try {
      console.log(`  Step ${i + 1}: ${step.action} ${step.selector || step.url || step.key || ''}`);

      switch (step.action) {
        case 'navigate':
          const url = step.url.startsWith('http') ? step.url : baseUrl + step.url;
          await page.goto(url, { waitUntil: 'networkidle', timeout });
          break;

        case 'click':
          await page.waitForSelector(step.selector, { timeout });
          await page.click(step.selector);
          break;

        case 'doubleClick':
          await page.waitForSelector(step.selector, { timeout });
          await page.dblclick(step.selector);
          break;

        case 'type':
          await page.waitForSelector(step.selector, { timeout });
          await page.type(step.selector, step.text, { delay: step.delay || 50 });
          break;

        case 'fill':
          await page.waitForSelector(step.selector, { timeout });
          await page.fill(step.selector, step.value);
          break;

        case 'clear':
          await page.waitForSelector(step.selector, { timeout });
          await page.fill(step.selector, '');
          break;

        case 'press':
          await page.keyboard.press(step.key);
          break;

        case 'waitFor':
          await page.waitForSelector(step.selector, {
            timeout: step.timeout || timeout,
            state: step.state || 'visible'
          });
          break;

        case 'waitForNavigation':
          await page.waitForNavigation({ timeout: step.timeout || timeout });
          break;

        case 'waitForURL':
          await page.waitForURL(step.url, { timeout: step.timeout || timeout });
          break;

        case 'waitForLoadState':
          await page.waitForLoadState(step.state || 'networkidle');
          break;

        case 'assert':
          if (step.contains) {
            const element = await page.waitForSelector(step.selector, { timeout });
            const text = await element.textContent();
            if (!text || !text.includes(step.contains)) {
              throw new Error(`Expected text "${step.contains}" not found in "${text}"`);
            }
          }
          if (step.visible !== undefined) {
            const isVisible = await page.isVisible(step.selector);
            if (isVisible !== step.visible) {
              throw new Error(`Expected element ${step.selector} visibility: ${step.visible}, got: ${isVisible}`);
            }
          }
          if (step.count !== undefined) {
            const count = await page.locator(step.selector).count();
            if (count !== step.count) {
              throw new Error(`Expected ${step.count} elements matching ${step.selector}, found ${count}`);
            }
          }
          if (step.value !== undefined) {
            const inputValue = await page.inputValue(step.selector);
            if (inputValue !== step.value) {
              throw new Error(`Expected input value "${step.value}", got "${inputValue}"`);
            }
          }
          if (step.attribute) {
            const attrValue = await page.getAttribute(step.selector, step.attribute);
            if (attrValue !== step.expectedValue) {
              throw new Error(`Expected attribute ${step.attribute}="${step.expectedValue}", got "${attrValue}"`);
            }
          }
          break;

        case 'screenshot':
          const screenshotPath = path.join(screenshotDir, `${step.name || `step-${i + 1}`}.png`);
          await page.screenshot({ path: screenshotPath, fullPage: step.fullPage || false });
          results.screenshots.push(screenshotPath);
          break;

        case 'scroll':
          if (step.selector) {
            await page.locator(step.selector).scrollIntoViewIfNeeded();
          } else if (step.position) {
            await page.evaluate(({ x, y }) => window.scrollTo(x, y), step.position);
          } else {
            const delta = step.direction === 'up' ? -500 : 500;
            await page.evaluate((d) => window.scrollBy(0, d), delta);
          }
          break;

        case 'hover':
          await page.waitForSelector(step.selector, { timeout });
          await page.hover(step.selector);
          break;

        case 'select':
          await page.waitForSelector(step.selector, { timeout });
          await page.selectOption(step.selector, step.value);
          break;

        case 'check':
          await page.waitForSelector(step.selector, { timeout });
          await page.check(step.selector);
          break;

        case 'uncheck':
          await page.waitForSelector(step.selector, { timeout });
          await page.uncheck(step.selector);
          break;

        case 'focus':
          await page.waitForSelector(step.selector, { timeout });
          await page.focus(step.selector);
          break;

        case 'blur':
          await page.evaluate((sel) => document.querySelector(sel)?.blur(), step.selector);
          break;

        case 'upload':
          await page.waitForSelector(step.selector, { timeout });
          await page.setInputFiles(step.selector, step.files);
          break;

        case 'drag':
          await page.dragAndDrop(step.source, step.target);
          break;

        case 'wait':
          await page.waitForTimeout(step.duration || 1000);
          break;

        case 'evaluate':
          await page.evaluate(step.script);
          break;

        case 'reload':
          await page.reload({ waitUntil: 'networkidle' });
          break;

        case 'goBack':
          await page.goBack({ waitUntil: 'networkidle' });
          break;

        case 'goForward':
          await page.goForward({ waitUntil: 'networkidle' });
          break;

        default:
          throw new Error(`Unknown action: ${step.action}`);
      }

      stepResult.status = 'passed';
      stepResult.duration = Date.now() - stepStart;
      console.log(`    ✅ Passed (${stepResult.duration}ms)`);

    } catch (error) {
      stepResult.status = 'failed';
      stepResult.error = error.message;
      stepResult.duration = Date.now() - stepStart;
      results.passed = false;
      results.errors.push({
        step: i + 1,
        action: step.action,
        error: error.message
      });

      console.log(`    ❌ Failed: ${error.message}`);

      // Screenshot on failure
      const errorScreenshot = path.join(screenshotDir, `error-${scenario.name}-step-${i + 1}-${Date.now()}.png`);
      try {
        await page.screenshot({ path: errorScreenshot, fullPage: true });
        results.screenshots.push(errorScreenshot);
      } catch (e) {
        console.log(`    ⚠️ Could not take error screenshot: ${e.message}`);
      }

      // Stop on failure unless continueOnError is set
      if (!options.continueOnError) {
        break;
      }
    }

    results.steps.push(stepResult);
  }

  results.endTime = Date.now();
  results.duration = results.endTime - results.startTime;

  // Get video path
  const videoPath = await page.video()?.path();
  if (videoPath) {
    results.video = videoPath;
  }

  await context.close();
  await browser.close();

  console.log(`\n${results.passed ? '✅' : '❌'} Flow test ${results.passed ? 'PASSED' : 'FAILED'} in ${results.duration}ms`);

  return results;
}

async function runAllFlowTests(prdPath, options = {}) {
  const prd = JSON.parse(fs.readFileSync(prdPath, 'utf8'));
  const baseUrl = prd.verification?.devServerUrl || 'http://localhost:3000';

  const allResults = {
    totalScenarios: 0,
    passed: 0,
    failed: 0,
    scenarios: []
  };

  for (const story of prd.userStories) {
    if (!story.testScenarios || story.testScenarios.length === 0) {
      continue;
    }

    for (const scenario of story.testScenarios) {
      allResults.totalScenarios++;
      const result = await runFlowTest(scenario, baseUrl, {
        screenshotDir: prd.verification?.screenshotDir || '.claude/screenshots',
        ...options
      });

      if (result.passed) {
        allResults.passed++;
      } else {
        allResults.failed++;
      }

      allResults.scenarios.push({
        storyId: story.id,
        ...result
      });
    }
  }

  return allResults;
}

// CLI usage
if (require.main === module) {
  const args = process.argv.slice(2);

  if (args.length < 1) {
    console.log('Usage: flow-test.js <prd.json> [baseUrl]');
    console.log('       flow-test.js --scenario <scenario.json> <baseUrl>');
    process.exit(1);
  }

  if (args[0] === '--scenario') {
    const scenario = JSON.parse(fs.readFileSync(args[1], 'utf8'));
    const baseUrl = args[2] || 'http://localhost:3000';
    runFlowTest(scenario, baseUrl).then(results => {
      console.log(JSON.stringify(results, null, 2));
      process.exit(results.passed ? 0 : 1);
    });
  } else {
    const prdPath = args[0];
    runAllFlowTests(prdPath).then(results => {
      console.log('\n📊 Summary:');
      console.log(`   Total: ${results.totalScenarios}`);
      console.log(`   Passed: ${results.passed}`);
      console.log(`   Failed: ${results.failed}`);

      // Save results
      const outputPath = '.claude/logs/flow-test-results.json';
      fs.mkdirSync(path.dirname(outputPath), { recursive: true });
      fs.writeFileSync(outputPath, JSON.stringify(results, null, 2));
      console.log(`\n📁 Results saved to ${outputPath}`);

      process.exit(results.failed > 0 ? 1 : 0);
    });
  }
}

module.exports = { runFlowTest, runAllFlowTests };
