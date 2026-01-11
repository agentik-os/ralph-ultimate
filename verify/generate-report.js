#!/usr/bin/env node
/**
 * Ralph Ultimate v4 - HTML Report Generator
 * Generates a comprehensive visual report of the session
 */

const fs = require('fs');
const path = require('path');

function generateReport(options = {}) {
  const {
    prdPath = 'prd.json',
    logsDir = '.claude/logs',
    screenshotsDir = '.claude/screenshots',
    videosDir = '.claude/videos',
    outputPath = '.claude/reports'
  } = options;

  // Ensure output directory exists
  fs.mkdirSync(outputPath, { recursive: true });

  // Read PRD
  let prd = { userStories: [], project: 'Unknown', feature: 'Unknown' };
  try {
    prd = JSON.parse(fs.readFileSync(prdPath, 'utf8'));
  } catch (e) {
    console.log('⚠️ Could not read prd.json');
  }

  // Read flow test results
  let flowResults = { scenarios: [] };
  try {
    flowResults = JSON.parse(fs.readFileSync(path.join(logsDir, 'flow-test-results.json'), 'utf8'));
  } catch (e) {}

  // Read devtools logs
  let devtoolsLogs = [];
  try {
    const files = fs.readdirSync(logsDir).filter(f => f.startsWith('devtools-'));
    devtoolsLogs = files.map(f => JSON.parse(fs.readFileSync(path.join(logsDir, f), 'utf8')));
  } catch (e) {}

  // Get screenshots
  let screenshots = [];
  try {
    screenshots = fs.readdirSync(screenshotsDir)
      .filter(f => f.endsWith('.png'))
      .map(f => path.join(screenshotsDir, f));
  } catch (e) {}

  // Get videos
  let videos = [];
  try {
    videos = fs.readdirSync(videosDir)
      .filter(f => f.endsWith('.webm') || f.endsWith('.mp4'))
      .map(f => path.join(videosDir, f));
  } catch (e) {}

  // Calculate stats
  const stats = {
    totalStories: prd.userStories.length,
    completedStories: prd.userStories.filter(s => s.passes).length,
    totalScenarios: flowResults.totalScenarios || 0,
    passedScenarios: flowResults.passed || 0,
    failedScenarios: flowResults.failed || 0,
    totalScreenshots: screenshots.length,
    totalVideos: videos.length,
    avgLoadTime: devtoolsLogs.length > 0
      ? Math.round(devtoolsLogs.reduce((sum, l) => sum + (l.summary?.loadTime || 0), 0) / devtoolsLogs.length)
      : 0,
    totalErrors: devtoolsLogs.reduce((sum, l) => sum + (l.summary?.jsErrors || 0), 0)
  };

  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const reportFile = path.join(outputPath, `ralph-report-${timestamp}.html`);

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Ralph Ultimate Report - ${prd.project}/${prd.feature}</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: #0f172a;
      color: #e2e8f0;
      line-height: 1.6;
    }
    .container { max-width: 1400px; margin: 0 auto; padding: 2rem; }
    header {
      background: linear-gradient(135deg, #1e3a5f 0%, #0f172a 100%);
      padding: 2rem;
      border-radius: 1rem;
      margin-bottom: 2rem;
      border: 1px solid #334155;
    }
    h1 { font-size: 2rem; margin-bottom: 0.5rem; color: #60a5fa; }
    h2 { font-size: 1.5rem; margin: 2rem 0 1rem; color: #94a3b8; border-bottom: 1px solid #334155; padding-bottom: 0.5rem; }
    h3 { font-size: 1.1rem; margin: 1rem 0 0.5rem; color: #cbd5e1; }
    .meta { color: #64748b; font-size: 0.9rem; }
    .stats-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
      gap: 1rem;
      margin: 1.5rem 0;
    }
    .stat-card {
      background: #1e293b;
      padding: 1.5rem;
      border-radius: 0.75rem;
      border: 1px solid #334155;
      text-align: center;
    }
    .stat-value {
      font-size: 2.5rem;
      font-weight: 700;
      color: #60a5fa;
    }
    .stat-value.success { color: #22c55e; }
    .stat-value.warning { color: #eab308; }
    .stat-value.error { color: #ef4444; }
    .stat-label { color: #94a3b8; font-size: 0.85rem; margin-top: 0.5rem; }
    .story-card {
      background: #1e293b;
      border-radius: 0.75rem;
      padding: 1.5rem;
      margin-bottom: 1rem;
      border: 1px solid #334155;
    }
    .story-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 1rem;
    }
    .story-id { color: #64748b; font-family: monospace; }
    .badge {
      padding: 0.25rem 0.75rem;
      border-radius: 9999px;
      font-size: 0.75rem;
      font-weight: 600;
    }
    .badge.passed { background: #166534; color: #86efac; }
    .badge.failed { background: #991b1b; color: #fca5a5; }
    .badge.pending { background: #854d0e; color: #fde047; }
    .criteria-list {
      list-style: none;
      margin-top: 1rem;
    }
    .criteria-list li {
      padding: 0.5rem 0;
      padding-left: 1.5rem;
      position: relative;
      border-bottom: 1px solid #334155;
    }
    .criteria-list li::before {
      content: '○';
      position: absolute;
      left: 0;
      color: #64748b;
    }
    .criteria-list li.checked::before {
      content: '✓';
      color: #22c55e;
    }
    .scenario-card {
      background: #0f172a;
      border-radius: 0.5rem;
      padding: 1rem;
      margin: 0.5rem 0;
      border: 1px solid #1e293b;
    }
    .step-list {
      font-family: monospace;
      font-size: 0.85rem;
      margin-top: 0.5rem;
    }
    .step { padding: 0.25rem 0; }
    .step.passed { color: #86efac; }
    .step.failed { color: #fca5a5; }
    .screenshots-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
      gap: 1rem;
      margin-top: 1rem;
    }
    .screenshot-card {
      background: #1e293b;
      border-radius: 0.5rem;
      overflow: hidden;
      border: 1px solid #334155;
    }
    .screenshot-card img {
      width: 100%;
      height: 200px;
      object-fit: cover;
      cursor: pointer;
      transition: transform 0.2s;
    }
    .screenshot-card img:hover { transform: scale(1.02); }
    .screenshot-card .caption {
      padding: 0.75rem;
      font-size: 0.8rem;
      color: #94a3b8;
      word-break: break-all;
    }
    .perf-table {
      width: 100%;
      border-collapse: collapse;
      margin-top: 1rem;
    }
    .perf-table th, .perf-table td {
      padding: 0.75rem;
      text-align: left;
      border-bottom: 1px solid #334155;
    }
    .perf-table th { color: #94a3b8; font-weight: 500; }
    .grade {
      display: inline-block;
      width: 20px;
      height: 20px;
      border-radius: 50%;
      margin-right: 0.5rem;
    }
    .grade.good { background: #22c55e; }
    .grade.needs-improvement { background: #eab308; }
    .grade.poor { background: #ef4444; }
    .error-list {
      background: #450a0a;
      border: 1px solid #7f1d1d;
      border-radius: 0.5rem;
      padding: 1rem;
      margin-top: 1rem;
    }
    .error-item {
      padding: 0.5rem 0;
      border-bottom: 1px solid #7f1d1d;
      font-family: monospace;
      font-size: 0.85rem;
    }
    .error-item:last-child { border-bottom: none; }
    .timeline {
      position: relative;
      padding-left: 2rem;
      margin-top: 1rem;
    }
    .timeline::before {
      content: '';
      position: absolute;
      left: 0.5rem;
      top: 0;
      bottom: 0;
      width: 2px;
      background: #334155;
    }
    .timeline-item {
      position: relative;
      padding-bottom: 1.5rem;
    }
    .timeline-item::before {
      content: '';
      position: absolute;
      left: -1.65rem;
      width: 12px;
      height: 12px;
      border-radius: 50%;
      background: #60a5fa;
      border: 2px solid #0f172a;
    }
    .timeline-item.success::before { background: #22c55e; }
    .timeline-item.error::before { background: #ef4444; }
    footer {
      text-align: center;
      padding: 2rem;
      color: #64748b;
      font-size: 0.85rem;
    }
    .modal {
      display: none;
      position: fixed;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      background: rgba(0,0,0,0.9);
      z-index: 1000;
      justify-content: center;
      align-items: center;
    }
    .modal.active { display: flex; }
    .modal img {
      max-width: 95%;
      max-height: 95%;
      border-radius: 0.5rem;
    }
    .modal-close {
      position: absolute;
      top: 1rem;
      right: 1rem;
      color: white;
      font-size: 2rem;
      cursor: pointer;
    }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <h1>🤖 Ralph Ultimate Report</h1>
      <p class="meta">
        Project: <strong>${prd.project}</strong> |
        Feature: <strong>${prd.feature}</strong> |
        Generated: ${new Date().toLocaleString()}
      </p>
    </header>

    <section>
      <h2>📊 Overview</h2>
      <div class="stats-grid">
        <div class="stat-card">
          <div class="stat-value ${stats.completedStories === stats.totalStories ? 'success' : 'warning'}">
            ${stats.completedStories}/${stats.totalStories}
          </div>
          <div class="stat-label">User Stories Completed</div>
        </div>
        <div class="stat-card">
          <div class="stat-value ${stats.failedScenarios === 0 ? 'success' : 'error'}">
            ${stats.passedScenarios}/${stats.totalScenarios}
          </div>
          <div class="stat-label">Flow Tests Passed</div>
        </div>
        <div class="stat-card">
          <div class="stat-value">${stats.avgLoadTime}ms</div>
          <div class="stat-label">Avg Page Load Time</div>
        </div>
        <div class="stat-card">
          <div class="stat-value ${stats.totalErrors === 0 ? 'success' : 'error'}">
            ${stats.totalErrors}
          </div>
          <div class="stat-label">JS Errors</div>
        </div>
        <div class="stat-card">
          <div class="stat-value">${stats.totalScreenshots}</div>
          <div class="stat-label">Screenshots</div>
        </div>
        <div class="stat-card">
          <div class="stat-value">${stats.totalVideos}</div>
          <div class="stat-label">Videos</div>
        </div>
      </div>
    </section>

    <section>
      <h2>📋 User Stories</h2>
      ${prd.userStories.map(story => `
        <div class="story-card">
          <div class="story-header">
            <div>
              <span class="story-id">${story.id}</span>
              <h3>${story.title}</h3>
            </div>
            <span class="badge ${story.passes ? 'passed' : story.status === 'in_progress' ? 'pending' : 'failed'}">
              ${story.passes ? 'PASSED' : story.status}
            </span>
          </div>
          <p>${story.description || ''}</p>
          ${story.acceptanceCriteria ? `
            <ul class="criteria-list">
              ${story.acceptanceCriteria.map(c => `<li class="${story.passes ? 'checked' : ''}">${c}</li>`).join('')}
            </ul>
          ` : ''}
          ${story.testScenarios ? `
            <h4 style="margin-top: 1rem; color: #64748b;">Test Scenarios</h4>
            ${story.testScenarios.map(scenario => {
              const result = flowResults.scenarios?.find(s => s.scenario === scenario.name);
              return `
                <div class="scenario-card">
                  <strong>${scenario.name}</strong>
                  ${result ? `<span class="badge ${result.passed ? 'passed' : 'failed'}" style="margin-left: 0.5rem;">
                    ${result.passed ? 'PASSED' : 'FAILED'}
                  </span>` : ''}
                  <div class="step-list">
                    ${scenario.steps.map((step, i) => {
                      const stepResult = result?.steps?.[i];
                      return `<div class="step ${stepResult?.status || ''}">${i + 1}. ${step.action} ${step.selector || step.url || ''}</div>`;
                    }).join('')}
                  </div>
                </div>
              `;
            }).join('')}
          ` : ''}
        </div>
      `).join('')}
    </section>

    ${devtoolsLogs.length > 0 ? `
      <section>
        <h2>⚡ Performance</h2>
        <table class="perf-table">
          <thead>
            <tr>
              <th>Page</th>
              <th>TTFB</th>
              <th>LCP</th>
              <th>CLS</th>
              <th>Load Time</th>
              <th>Requests</th>
              <th>Errors</th>
            </tr>
          </thead>
          <tbody>
            ${devtoolsLogs.map(log => `
              <tr>
                <td>${new URL(log.url).pathname}</td>
                <td>
                  <span class="grade ${log.summary?.grades?.ttfb || 'pending'}"></span>
                  ${log.performance?.timing?.ttfb || '-'}ms
                </td>
                <td>
                  <span class="grade ${log.summary?.grades?.lcp || 'pending'}"></span>
                  ${log.performance?.webVitals?.lcp ? Math.round(log.performance.webVitals.lcp) + 'ms' : '-'}
                </td>
                <td>
                  <span class="grade ${log.summary?.grades?.cls || 'pending'}"></span>
                  ${log.performance?.webVitals?.cls?.toFixed(3) || '-'}
                </td>
                <td>${log.summary?.loadTime || '-'}ms</td>
                <td>${log.summary?.totalRequests || 0} (${log.summary?.failedRequests || 0} failed)</td>
                <td>${log.summary?.jsErrors || 0}</td>
              </tr>
            `).join('')}
          </tbody>
        </table>
      </section>
    ` : ''}

    ${screenshots.length > 0 ? `
      <section>
        <h2>📸 Screenshots</h2>
        <div class="screenshots-grid">
          ${screenshots.map(s => `
            <div class="screenshot-card">
              <img src="${s}" alt="${path.basename(s)}" onclick="openModal('${s}')">
              <div class="caption">${path.basename(s)}</div>
            </div>
          `).join('')}
        </div>
      </section>
    ` : ''}

    ${flowResults.scenarios?.some(s => s.errors?.length > 0) ? `
      <section>
        <h2>❌ Errors</h2>
        <div class="error-list">
          ${flowResults.scenarios.filter(s => s.errors?.length > 0).map(s => `
            <div style="margin-bottom: 1rem;">
              <strong>${s.scenario}</strong>
              ${s.errors.map(e => `<div class="error-item">${e.error || e}</div>`).join('')}
            </div>
          `).join('')}
        </div>
      </section>
    ` : ''}

    <footer>
      <p>Generated by Ralph Ultimate v4 | ${new Date().toISOString()}</p>
    </footer>
  </div>

  <div class="modal" id="imageModal" onclick="closeModal()">
    <span class="modal-close">&times;</span>
    <img id="modalImage" src="" alt="">
  </div>

  <script>
    function openModal(src) {
      document.getElementById('modalImage').src = src;
      document.getElementById('imageModal').classList.add('active');
    }
    function closeModal() {
      document.getElementById('imageModal').classList.remove('active');
    }
    document.addEventListener('keydown', e => {
      if (e.key === 'Escape') closeModal();
    });
  </script>
</body>
</html>`;

  fs.writeFileSync(reportFile, html);
  console.log(`\n📄 Report generated: ${reportFile}`);

  return reportFile;
}

// CLI usage
if (require.main === module) {
  const args = process.argv.slice(2);

  const options = {};
  for (let i = 0; i < args.length; i += 2) {
    const key = args[i].replace('--', '');
    options[key] = args[i + 1];
  }

  generateReport(options);
}

module.exports = { generateReport };
