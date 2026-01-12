# Ralph Ultimate

> **Autonomous AI Coding Loop with Unlimited Mode + Playwright Verification for Claude Code**

[![GitHub](https://img.shields.io/github/license/agentik-os/ralph-ultimate)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/agentik-os/ralph-ultimate?style=social)](https://github.com/agentik-os/ralph-ultimate)

**Ralph Ultimate** is a terminal-based autonomous development system that works with Claude Code to execute complex features while you sleep. It runs **without rate limits**, auto-resumes after API limits, and verifies work with Playwright screenshots.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  🤖 RALPH works autonomously → You sleep → Wake up to completed features   │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Why Ralph Ultimate?

| Problem | Ralph Solution |
|---------|----------------|
| Claude stops after 5h API limit | **Auto-resumes** after 65 min wait |
| Hard to know if code actually works | **Playwright screenshots** after each loop |
| Gets stuck in infinite loops | **Circuit breaker** detects and stops stagnation |
| Complex features need many sessions | **Unlimited mode** - runs until done |
| Difficult to monitor progress | **tmux dashboard** shows real-time status |

---

## One-Line Installation

```bash
curl -fsSL https://raw.githubusercontent.com/agentik-os/ralph-ultimate/main/install.sh | bash
```

Or clone and install manually:

```bash
git clone https://github.com/agentik-os/ralph-ultimate.git ~/.ralph
cd ~/.ralph && ./install.sh
```

---

## Prerequisites

| Requirement | Version | Required |
|-------------|---------|----------|
| [Claude Code CLI](https://claude.ai/code) | Latest | Yes |
| Node.js | 18+ | Yes |
| Git | Any | Yes |
| tmux | Any | Optional (for --monitor) |
| Playwright | Any | Optional (for screenshots) |

### Install Claude Code CLI

```bash
# Via npm
npm install -g @anthropic-ai/claude-code

# Authenticate
claude login
```

---

## Quick Start (3 Steps)

### 1. Initialize your project

```bash
cd /your/project
ralph-setup
```

This creates:
- `PROMPT.md` - Instructions for Claude
- `@fix_plan.md` - Task list with checkboxes
- `@AGENT.md` - Build/run/test commands

### 2. Edit your tasks

```markdown
## Tasks
- [ ] Add user authentication with Clerk
- [ ] Create dashboard page with charts
- [ ] Implement payment flow with Stripe
- [ ] Add unit tests for core functions

## Validation
- [ ] Build passes
- [ ] No TypeScript errors
```

### 3. Launch Ralph

```bash
# With tmux dashboard (recommended)
ralph --monitor

# Or without dashboard
ralph
```

**That's it!** Ralph will work through each task autonomously.

---

## How It Works

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         RALPH UNLIMITED LOOP                                 │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │  1. Read PROMPT.md (your instructions)                                 │ │
│  │  2. Read @fix_plan.md (task list)                                      │ │
│  │  3. Launch Claude Code                                                 │ │
│  │  4. Claude works on a task                                             │ │
│  │  5. ✨ Playwright Verification (if dev server active)                  │ │
│  │     - Screenshot of the app                                            │ │
│  │     - Check console errors                                             │ │
│  │  6. Check if done (exit detection)                                     │ │
│  │  7. If not done → go back to step 3                                    │ │
│  │  8. If done → STOP                                                     │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  🔄 Infinite loop until completion                                          │
│  ⏰ If 5h API limit → wait 65 min → resume automatically                    │
│  📸 Auto screenshots in logs/screenshots/                                   │
│  🛡️ Circuit breaker stops infinite loops                                   │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Commands Reference

### Basic Commands

```bash
ralph                    # Start autonomous loop
ralph --monitor          # Start with tmux dashboard
ralph --status           # Show current status
ralph --help             # Show help
```

### Options

```bash
ralph --prompt FILE          # Use alternate prompt file
ralph --timeout 30           # Timeout per loop (default: 15 min)
ralph --verbose              # Verbose output

# Playwright options
ralph --no-playwright        # Disable screenshot verification
ralph --playwright-port 3001 # Specify dev server port
```

### Project Setup

```bash
ralph-setup              # Interactive project setup
ralph-init               # Quick minimal setup
ralph-import file.md     # Import requirements from file
```

### Circuit Breaker

```bash
ralph --circuit-status   # Show circuit breaker state
ralph --reset-circuit    # Reset if stuck
```

---

## Project Structure

When you run `ralph-setup`, it creates:

```
your-project/
├── PROMPT.md          # 📋 Instructions for Claude (objective, context)
├── @fix_plan.md       # ✅ Task list with checkboxes [ ] / [x]
├── @AGENT.md          # 🔧 Build/run/test commands
├── status.json        # 📊 Current state (auto-generated)
└── logs/
    ├── ralph.log      # 📝 Execution logs
    └── screenshots/   # 📸 Playwright screenshots
```

Ralph reads from `~/.ralph/`:

```
~/.ralph/
├── ralph.sh              # Main loop script
├── ralph-setup.sh        # Interactive setup
├── ralph-monitor.sh      # tmux dashboard
├── ralph-init.sh         # Quick init
├── ralph-import.sh       # Import requirements
└── lib/
    ├── circuit_breaker.sh   # Infinite loop protection
    ├── date_utils.sh        # Date utilities
    ├── response_analyzer.sh # Response analysis
    ├── playwright_verify.sh # Screenshot verification
    └── auto_refactor.sh     # Large file splitting
```

---

## Configuration

### Default Settings

```bash
# No rate limiting (unlimited mode)
RATE_LIMIT_ENABLED=false
MAX_CALLS_PER_HOUR=999999999

# Auto-resume on 5h API limit
AUTO_RESUME_ON_5H_LIMIT=true
API_LIMIT_WAIT_MINUTES=65

# Playwright verification
PLAYWRIGHT_ENABLED=true
PLAYWRIGHT_DEV_PORTS="3000 3001 5173 8080"
```

### Custom Configuration

Create `.ralph-config` in your project to override:

```bash
# .ralph-config
CLAUDE_TIMEOUT_MINUTES=20     # Claude timeout per loop
VERBOSE_PROGRESS=true         # Verbose output
PLAYWRIGHT_ENABLED=false      # Disable screenshots
PLAYWRIGHT_DEV_PORTS="3001"   # Custom dev port
```

---

## Task File Formats

Ralph supports 3 task file formats:

### 1. @fix_plan.md (Recommended)

Simple markdown checklist:

```markdown
## Tasks
- [ ] Add login page
- [ ] Create user dashboard
- [ ] Implement API endpoints

## Validation
- [ ] Build passes
- [ ] Tests pass
```

### 2. prd.json (Structured)

JSON with user stories:

```json
{
  "project": "my-app",
  "userStories": [
    {
      "id": "US-001",
      "title": "User Login",
      "description": "As a user, I want to log in",
      "acceptanceCriteria": ["Email/password form", "Build passes"],
      "priority": 1,
      "passes": false
    }
  ]
}
```

### 3. .claude/step.json (Claude Code format)

```json
{
  "project": "my-app",
  "steps": [
    {
      "id": 1,
      "name": "Authentication",
      "tasks": [
        {"name": "Add login", "done": false}
      ]
    }
  ]
}
```

---

## Playwright Verification

After each loop, Ralph automatically:

1. **Detects** running dev server (ports: 3000, 3001, 5173, 8080)
2. **Takes screenshot** of the app
3. **Checks** for JavaScript console errors
4. **Logs** results

Screenshots saved as: `logs/screenshots/loop_5_20260112_143025.png`

### Manual Screenshot Setup

```bash
# Install Playwright
npx playwright install chromium

# Test it works
npx playwright screenshot https://localhost:3000 test.png
```

---

## Monitoring

### tmux Dashboard

```bash
ralph --monitor
```

Shows split view:
- Left: Ralph execution
- Right: Real-time monitor

**tmux commands:**
```
Ctrl+B then D         # Detach (leave running)
tmux attach -t ralph  # Reattach
Ctrl+C                # Stop Ralph
tmux kill-session     # Kill everything
```

### View Logs

```bash
tail -f logs/ralph.log        # Real-time logs
ls logs/screenshots/          # View screenshots
cat @fix_plan.md              # Check completed tasks
cat status.json               # Detailed status
git log --oneline -10         # Recent commits
```

---

## Safety Features

### Circuit Breaker

Detects when Ralph is stuck and stops automatically:
- Too many consecutive failures
- No progress after X loops
- Repeated same errors

```bash
# Check status
ralph --circuit-status

# Reset if stuck
ralph --reset-circuit
```

### Auto-Refactoring

If Claude encounters "max tokens" error, Ralph:
1. Detects the oversized file
2. Queues it for splitting
3. Creates smaller focused files
4. Continues with the task

---

## Best Practices

### DO

- Use for features with 3+ tasks
- Let it run overnight for big features
- Keep tasks atomic (1 task = 1 iteration)
- Include "Build passes" in acceptance criteria
- Have dev server running for Playwright verification
- Review commits in the morning

### DON'T

- Use for critical production bugs (need human diagnosis)
- Use for architecture decisions (need human validation)
- Use for single small tasks (overhead not worth it)
- Skip reviewing Ralph's work before deploying

---

## Troubleshooting

### Ralph won't start

```bash
# Check Claude Code is installed
claude --version

# Check you're in a project directory
ls PROMPT.md @fix_plan.md

# Initialize if missing
ralph-setup
```

### Ralph is stuck in a loop

```bash
# Check circuit breaker
ralph --circuit-status

# Reset it
ralph --reset-circuit

# Check what's happening
cat logs/ralph.log | tail -50
```

### API limit reached

Ralph auto-resumes after 65 minutes. If you see:
```
Claude API 5-hour limit reached
AUTO-RESUME: Waiting 65 minutes...
```

Just wait. Ralph will continue automatically.

### Playwright not working

```bash
# Check dev server is running
curl http://localhost:3000

# Install Playwright
npx playwright install chromium

# Force specific port
ralph --playwright-port 3000
```

### Commands not found

```bash
# Source your shell config
source ~/.bashrc  # or ~/.zshrc

# Or add to PATH manually
export PATH="$HOME/.ralph:$PATH"
```

---

## Integration with Claude Code

Claude Code can launch Ralph directly! When you ask for a complex feature:

1. Claude prepares the task files (PROMPT.md, @fix_plan.md)
2. Claude launches Ralph in background
3. You monitor progress or go to sleep
4. Wake up to completed features

Example prompt to Claude:
> "Create a user dashboard with charts and authentication. Use Ralph to implement it autonomously."

---

## Updating Ralph

```bash
cd ~/.ralph
git pull origin main
chmod +x *.sh lib/*.sh
```

Or reinstall:

```bash
curl -fsSL https://raw.githubusercontent.com/agentik-os/ralph-ultimate/main/install.sh | bash
```

---

## Uninstall

```bash
# Remove installation
rm -rf ~/.ralph

# Remove symlinks
sudo rm -f /usr/local/bin/ralph*

# Remove from shell config (edit manually)
# Remove lines containing RALPH_HOME from ~/.bashrc or ~/.zshrc
```

---

## Contributing

Contributions welcome! Please:

1. Fork the repo
2. Create a feature branch
3. Make your changes
4. Test with `ralph --help` and `ralph-setup`
5. Submit a PR

---

## Credits

Created by [AgentikOS](https://github.com/agentik-os) for the Claude Code ecosystem.

Based on concepts from:
- [frankbria/ralph-claude-code](https://github.com/frankbria/ralph-claude-code) - Original Ralph concept
- [Claude Code](https://claude.ai/code) by Anthropic
- [Playwright](https://playwright.dev/) for browser automation

---

## License

MIT License - Use it, modify it, share it!

---

## Support

- **GitHub Issues**: [Report bugs or request features](https://github.com/agentik-os/ralph-ultimate/issues)
- **Discussions**: [Ask questions](https://github.com/agentik-os/ralph-ultimate/discussions)

---

**Star this repo if Ralph helps you code while you sleep!**
