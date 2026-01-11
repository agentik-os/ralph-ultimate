# Ralph Ultimate v3 🤖

> Autonomous AI coding loop with Playwright verification for Claude Code

**Ralph Ultimate** is a terminal-based autonomous development system that works with Claude Code to execute complex features while you sleep. It verifies every step with Playwright (build + screenshot + console errors) and auto-fixes issues.

## ✨ Features

| Feature | Description |
|---------|-------------|
| **Unlimited Duration** | No 2-3h session limits - runs as long as needed |
| **Auto-Resume** | Automatically resumes after Claude's 5h API limit |
| **Checkpoints** | Saves state, can resume after crash/reboot |
| **Playwright Verification** | Proves work is done with screenshots + console checks |
| **Auto-Fix** | On failure → asks Claude to fix → re-verifies (max 3x) |
| **Circuit Breaker** | Detects infinite loops, prevents token waste |

## 🚀 Quick Start

### Prerequisites

- [Claude Code CLI](https://claude.ai/code) installed and authenticated
- Node.js 18+
- Playwright installed (`npx playwright install chromium`)

### Installation

```bash
# Clone the repo
git clone https://github.com/anthropics/claude-code.git
cd claude-code/ralph-ultimate

# Or directly
git clone https://github.com/DafnckStudio/ralph-ultimate.git ~/.ralph-ultimate

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
- `prd.json` - Your tasks/user stories
- `prompt.md` - Instructions for Claude
- `.claude/` - Checkpoints and logs

## 📖 Usage

### Basic Commands

```bash
# Start autonomous loop (recommended with monitor)
ralph-ultimate --monitor

# Start without tmux dashboard
ralph-ultimate

# Check status
ralph-ultimate --status

# Show checkpoints
ralph-ultimate --show-checkpoints

# Reset circuit breaker if stuck
ralph-ultimate --reset-circuit
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

## 🔄 Workflow

```
┌─────────────────────────────────────────────────────────────┐
│                    YOUR FEATURE REQUEST                      │
│            "Add user notifications system"                   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      PRD GENERATION                          │
│              Creates prd.json with user stories              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    RALPH ULTIMATE LOOP                       │
│                                                              │
│   For EACH user story:                                       │
│   ┌──────────────────────────────────────────────────────┐  │
│   │ 1. Claude executes the task                          │  │
│   │ 2. npm run build → Check passes                      │  │
│   │ 3. Playwright screenshot → Visual verification       │  │
│   │ 4. Console errors → No JS errors                     │  │
│   │ 5. If FAIL → Claude fixes → Re-verify (max 3x)       │  │
│   │ 6. If OK → Mark task complete, commit, next          │  │
│   └──────────────────────────────────────────────────────┘  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      FINAL REPORT                            │
│         All tasks done, screenshots saved, git pushed        │
└─────────────────────────────────────────────────────────────┘
```

## 📁 Project Structure

```
.ralph-ultimate/
├── ralph-ultimate.sh      # Main script (v3 with Playwright)
├── ralph-init.sh          # Project initializer
├── ralph-unified.sh       # Unified orchestrator
├── lib/
│   ├── circuit-breaker.sh # Infinite loop protection
│   ├── checkpoint.sh      # State management
│   └── ...
├── verify/
│   └── ralph-verify.sh    # Playwright verification script
├── templates/
│   ├── prd.json           # Task file template
│   └── prompt.md          # Claude prompt template
└── logs/                  # Execution logs
```

## 📋 prd.json Format

```json
{
  "project": "my-app",
  "feature": "user-notifications",
  "createdAt": "2024-01-15T10:00:00Z",
  "verification": {
    "devServerUrl": "http://localhost:3000",
    "screenshotDir": ".claude/screenshots",
    "playwrightPath": "/home/user/.x-navigate"
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
      "priority": 1,
      "status": "pending",
      "passes": false
    }
  ]
}
```

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
4. **Server Logs** - (Optional) Check for backend errors

## 🔧 Configuration

### Environment Variables

```bash
# In your project's .env or export
RALPH_MAX_LOOPS=50              # Max iterations
RALPH_VERIFY_RETRIES=3          # Retries per step
RALPH_DEV_URL=http://localhost:3000
```

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
```

## 🎯 Best Practices

### DO ✅
- Use for features with 3+ tasks
- Let it run overnight for big features
- Keep tasks atomic (1 task = 1 iteration)
- Include "Build passes" in acceptance criteria

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

### Check Status
```bash
ralph-ultimate --status
```

### View Logs
```bash
tail -f ~/.ralph-ultimate/logs/ralph-ultimate.log
```

## 🤝 Integration with Claude Code

### Using /ralph Skill

If you have the `/ralph` skill installed:

```
/ralph "Add user authentication with Clerk"
/ralph status
/ralph verify http://localhost:3000
/ralph resume
```

## 📝 License

MIT License - Use it, modify it, share it!

## 🙏 Credits

Created by [DafnckStudio](https://github.com/DafnckStudio) for the Claude Code ecosystem.

Built on top of:
- [Claude Code](https://claude.ai/code) by Anthropic
- [Playwright](https://playwright.dev/) for browser automation

---

**⭐ Star this repo if Ralph helps you code while you sleep!**
