# Ralph Ultimate v4 🤖

> Autonomous AI coding loop with **AI Flow Testing** + **Chrome DevTools Logs** for Claude Code

**Ralph Ultimate** is a terminal-based autonomous development system that works with Claude Code to execute complex features while you sleep. It verifies every step with Playwright (build + screenshot + console errors + **AI flow testing** + **performance metrics**) and auto-fixes issues.

## ✨ Features

| Feature | v4 | Description |
|---------|:--:|-------------|
| **Unlimited Duration** | ✓ | No 2-3h session limits - runs as long as needed |
| **Auto-Resume** | ✓ | Automatically resumes after Claude's 5h API limit |
| **Checkpoints** | ✓ | Saves state, can resume after crash/reboot |
| **Playwright Verification** | ✓ | Proves work is done with screenshots + console checks |
| **Auto-Fix** | ✓ | On failure → asks Claude to fix → re-verifies (max 3x) |
| **Circuit Breaker** | ✓ | Detects infinite loops, prevents token waste |
| **AI Flow Testing** | ⭐ NEW | Simulates user interactions (click, type, navigate, assert) |
| **Chrome DevTools Logs** | ⭐ NEW | Captures network, console, performance metrics |
| **Web Vitals** | ⭐ NEW | LCP, CLS, FCP, TTFB with quality grades |
| **HTML Reports** | ⭐ NEW | Visual summary with screenshots, videos, timeline |
| **JSON Output Mode** | ⭐ NEW | For Claude Code background task integration |
| **Video Recording** | ⭐ NEW | Records video of flow tests |

## 🚀 Quick Start

### Prerequisites

- [Claude Code CLI](https://claude.ai/code) installed and authenticated
- Node.js 18+
- Playwright installed (`npx playwright install chromium`)

### Installation

```bash
# Clone the repo
git clone https://github.com/agentik-os/ralph-ultimate.git ~/.ralph-ultimate

# Make executable
chmod +x ~/.ralph-ultimate/ralph-ultimate.sh

# Add to PATH (add to .bashrc/.zshrc)
export PATH="$HOME/.ralph-ultimate:$PATH"

# Create symlink for easy access
sudo ln -sf ~/.ralph-ultimate/ralph-ultimate.sh /usr/local/bin/ralph-ultimate
```

### Initialize a Project

```bash
cd /your/project
ralph-init
```

This creates:
- `prd.json` - Your tasks/user stories with test scenarios
- `prompt.md` - Instructions for Claude
- `.claude/` - Checkpoints, logs, screenshots, videos

## 📖 Usage

### Basic Commands

```bash
# Start autonomous loop (recommended with monitor)
ralph-ultimate --monitor

# Start without tmux dashboard
ralph-ultimate

# Check status
ralph-ultimate --status

# Generate HTML report only
ralph-ultimate --report

# Show checkpoints
ralph-ultimate --show-checkpoints

# Reset circuit breaker if stuck
ralph-ultimate --reset-circuit
```

### v4 Options

```bash
# Disable AI flow testing
ralph-ultimate --no-flow-test

# Disable Chrome DevTools logging
ralph-ultimate --no-devtools

# Disable HTML report generation
ralph-ultimate --no-report

# Enable JSON output (for Claude Code background tasks)
ralph-ultimate --json-output
```

### Verification Options

```bash
# Disable all verification (faster but risky)
ralph-ultimate --no-verify

# Skip specific checks
ralph-ultimate --no-build-check     # Skip npm run build
ralph-ultimate --no-screenshot      # Skip Playwright screenshot
ralph-ultimate --no-console-check   # Skip console error check

# Enable server logs check
ralph-ultimate --with-logs

# Set max retries on failure (default: 3)
ralph-ultimate --verify-retries 5

# Override dev server URL
ralph-ultimate --dev-url http://localhost:3000
```

## 🔄 v4 Workflow

```
┌─────────────────────────────────────────────────────────────┐
│                    YOUR FEATURE REQUEST                      │
│            "Add user notifications system"                   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      PRD GENERATION                          │
│         Creates prd.json with user stories + testScenarios   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    RALPH ULTIMATE v4 LOOP                    │
│                                                              │
│   For EACH user story:                                       │
│   ┌──────────────────────────────────────────────────────┐  │
│   │ 1. Claude executes the task                          │  │
│   │ 2. npm run build → Check passes                      │  │
│   │ 3. Playwright screenshot → Visual verification       │  │
│   │ 4. Console errors → No JS errors                     │  │
│   │ 5. ⭐ AI Flow Test → Simulate user interactions      │  │
│   │ 6. ⭐ Chrome DevTools → Network, perf, errors        │  │
│   │ 7. If FAIL → Claude fixes → Re-verify (max 3x)       │  │
│   │ 8. If OK → Mark task complete, commit, next          │  │
│   └──────────────────────────────────────────────────────┘  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    ⭐ HTML REPORT                            │
│   Screenshots • Videos • Performance Metrics • Timeline      │
└─────────────────────────────────────────────────────────────┘
```

## 📁 Project Structure

```
.ralph-ultimate/
├── ralph-ultimate.sh      # Main script (v4)
├── ralph-init.sh          # Project initializer
├── ralph-unified.sh       # Unified orchestrator
├── lib/
│   ├── circuit-breaker.sh # Infinite loop protection
│   ├── checkpoint.sh      # State management
│   └── ...
├── verify/
│   ├── ralph-verify.sh    # Basic verification script
│   ├── flow-test.js       # ⭐ AI Flow Testing (v4)
│   ├── chrome-devtools.js # ⭐ DevTools capture (v4)
│   └── generate-report.js # ⭐ HTML report generator (v4)
├── templates/
│   ├── prd.json           # Task file template
│   └── prompt.md          # Claude prompt template
└── logs/                  # Execution logs
```

## 📋 prd.json Format (v4)

```json
{
  "project": "my-app",
  "feature": "user-notifications",
  "createdAt": "2024-01-15T10:00:00Z",
  "verification": {
    "devServerUrl": "http://localhost:3000",
    "screenshotDir": ".claude/screenshots",
    "playwrightPath": "/home/user/.x-navigate",
    "flowTestingEnabled": true,
    "chromeLogs": true
  },
  "userStories": [
    {
      "id": "US-001",
      "title": "Create notification component",
      "description": "As a user, I want to see notifications",
      "acceptanceCriteria": [
        "Component renders correctly",
        "Build passes",
        "No console errors"
      ],
      "verification": {
        "type": "ui",
        "screenshotUrl": "/dashboard",
        "checkConsole": true
      },
      "testScenarios": [
        {
          "name": "User sees notification",
          "steps": [
            { "action": "navigate", "url": "/dashboard" },
            { "action": "waitFor", "selector": ".notification" },
            { "action": "assert", "selector": ".notification", "visible": true },
            { "action": "screenshot", "name": "notification-visible" }
          ]
        }
      ],
      "priority": 1,
      "status": "pending",
      "passes": false
    }
  ]
}
```

## 🎬 AI Flow Testing Actions

| Action | Parameters | Description |
|--------|------------|-------------|
| `navigate` | `url` | Navigate to URL |
| `click` | `selector` | Click element |
| `doubleClick` | `selector` | Double click element |
| `type` | `selector`, `text`, `delay?` | Type text with optional delay |
| `fill` | `selector`, `value` | Clear and fill input |
| `press` | `key` | Press keyboard key (Enter, Tab, etc.) |
| `waitFor` | `selector`, `timeout?`, `state?` | Wait for element |
| `waitForNavigation` | `timeout?` | Wait for navigation |
| `waitForURL` | `url`, `timeout?` | Wait for specific URL |
| `assert` | `selector`, `contains?`, `visible?`, `count?`, `value?` | Assert conditions |
| `screenshot` | `name`, `fullPage?` | Take named screenshot |
| `scroll` | `selector?`, `direction?`, `position?` | Scroll page |
| `hover` | `selector` | Hover over element |
| `select` | `selector`, `value` | Select dropdown option |
| `check` / `uncheck` | `selector` | Toggle checkbox |
| `focus` / `blur` | `selector` | Focus/blur element |
| `upload` | `selector`, `files` | Upload files |
| `drag` | `source`, `target` | Drag and drop |
| `wait` | `duration` | Wait N milliseconds |
| `evaluate` | `script` | Run JavaScript |
| `reload` | - | Reload page |
| `goBack` / `goForward` | - | Navigate history |

## 📊 Chrome DevTools Logs

Ralph captures:

| Type | Data |
|------|------|
| **Console** | All console.log, warn, error with location |
| **Network** | Requests (URL, method, status, duration, size) |
| **Failed Requests** | Status >= 400 or failed requests |
| **Slow Requests** | Duration > 3 seconds |
| **Performance** | Navigation timing (DNS, TCP, TTFB, etc.) |
| **Web Vitals** | LCP, FCP, CLS with quality grades |
| **Resources** | Resource breakdown (size, type, duration) |

### Quality Grades

| Metric | Good | Needs Improvement | Poor |
|--------|------|-------------------|------|
| **TTFB** | < 200ms | 200-500ms | > 500ms |
| **LCP** | < 2.5s | 2.5-4s | > 4s |
| **CLS** | < 0.1 | 0.1-0.25 | > 0.25 |

## 🛡️ Safety Features

### Circuit Breaker
Detects when Ralph is stuck in a loop and stops automatically:
- Max consecutive failures
- Token usage monitoring
- Time-based limits

### Checkpoints
Automatically saves progress:
```bash
# View checkpoints
ralph-ultimate --show-checkpoints

# Resume from checkpoint
ralph-ultimate  # Automatically detects and resumes
```

### Verification Pipeline
Every step must pass:
1. **Build Check** - `npm run build` must succeed
2. **Screenshot** - Playwright captures the page
3. **Console Errors** - No JavaScript errors allowed
4. **AI Flow Tests** - User interaction simulation
5. **DevTools Logs** - Performance metrics check

## 🔧 Configuration

### Per-Project Config

Create `.ralph-config` in your project:

```bash
MAX_LOOPS=100
VERIFY_ENABLED=true
VERIFY_BUILD=true
VERIFY_SCREENSHOT=true
VERIFY_CONSOLE=true
VERIFY_LOGS=false
DEV_SERVER_URL=http://localhost:3000

# v4 Options
FLOW_TESTING_ENABLED=true
DEVTOOLS_LOGS_ENABLED=true
REPORT_ENABLED=true
JSON_OUTPUT=false
```

## 🎯 Best Practices

### DO ✅
- Use for features with 3+ tasks
- Let it run overnight for big features
- Keep tasks atomic (1 task = 1 iteration)
- Include "Build passes" in acceptance criteria
- Add `testScenarios` for UI features

### DON'T ❌
- Use for critical production bugs (need human diagnosis)
- Use for architecture decisions (need human validation)
- Use for single small tasks (overhead not worth it)
- Use for auth/payment code (needs human review)

## 📊 Monitoring

### With tmux Dashboard
```bash
ralph-ultimate --monitor
```

Shows:
- Current task
- Loop count
- Verification status
- Recent logs

### JSON Output Mode (for Claude Code)
```bash
ralph-ultimate --json-output
```

Outputs structured JSON status for background task integration.

### View Logs
```bash
tail -f ~/.ralph-ultimate/logs/ralph-ultimate.log
```

### View DevTools Logs
```bash
cat .claude/logs/devtools-*.json | jq .
```

## 🤝 Integration with Claude Code

### Using /ralph Skill (v4)

If you have the `/ralph` skill installed:

```
/ralph "Add user authentication with Clerk"
/ralph status
/ralph verify http://localhost:3000
/ralph resume
/ralph report
```

### Background Task Integration

The `/ralph` skill can now launch Ralph as a background task from Claude Code:
- No need to manually run terminal commands
- Use `/ralph status` to check progress
- JSON output mode for structured status

## 📝 License

MIT License - Use it, modify it, share it!

## 🙏 Credits

Created by [AgentikOS](https://github.com/agentik-os) for the Claude Code ecosystem.

Built on top of:
- [Claude Code](https://claude.ai/code) by Anthropic
- [Playwright](https://playwright.dev/) for browser automation

---

**⭐ Star this repo if Ralph helps you code while you sleep!**
