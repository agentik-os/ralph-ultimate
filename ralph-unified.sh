#!/bin/bash

# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║                      RALPH UNIFIED COMMAND SYSTEM                              ║
# ║   Combining: ralph-ultimate + ralph-orchestrator + ralph-loop plugin           ║
# ║                                                                                ║
# ║  Author: Gareth (DafnckStudio)                                                ║
# ║  Version: 3.1.0 - Now with plugin integration!                                ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

set -e

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
VERSION="3.1.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# ═══════════════════════════════════════════════════════════════════════════════
# UNIFIED HELP
# ═══════════════════════════════════════════════════════════════════════════════

show_help() {
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════════════════╗
║                      RALPH UNIFIED COMMAND SYSTEM v3.1                         ║
║    Combining: ralph-ultimate + ralph-orchestrator + ralph-loop plugin          ║
╚═══════════════════════════════════════════════════════════════════════════════╝

USAGE: ralph-unified <command> [options]

COMMANDS:

  ╔═══════════════════════════════════════════════════════════════════════════╗
  ║                         EXECUTION MODES                                    ║
  ╚═══════════════════════════════════════════════════════════════════════════╝

  loop, run, ultimate     Start autonomous development loop (DafnckStudio)
                          → Uses custom ralph-ultimate.sh with context management
                          → Best for: Terminal-based long-running tasks
                          → Runs OUTSIDE Claude session

  in-session <prompt>     Start Ralph loop INSIDE current Claude session
                          → Uses official /ralph-loop plugin (Anthropic)
                          → Best for: Tasks where you want to monitor progress
                          → Uses Stop Hook to prevent exit until complete
                          → Options: --max-iterations N, --completion-promise "TEXT"

  orchestrate, orch       Start ralph-orchestrator (Python, multi-agent)
                          → Uses mikeyobrien/ralph-orchestrator
                          → Best for: Multi-agent workflows, ACP protocol

  quick <prompt>          Quick one-shot task with ralph-orchestrator
                          → Example: ralph-unified quick "Fix the login bug"

  ╔═══════════════════════════════════════════════════════════════════════════╗
  ║                          PROJECT SETUP                                     ║
  ╚═══════════════════════════════════════════════════════════════════════════╝

  init [format]           Initialize project for Ralph
                          Formats: fixplan (default), prd, stepjson
                          → Creates task file + PROMPT.md

  setup                   Full setup with ralph-orchestrator
                          → Creates ralph.yml, .agent/, PROMPT.md

  import <file>           Import PRD/requirements into Ralph format
                          → Converts markdown/txt to @fix_plan.md

  ╔═══════════════════════════════════════════════════════════════════════════╗
  ║                         MONITORING & STATUS                                ║
  ╚═══════════════════════════════════════════════════════════════════════════╝

  status                  Show current Ralph status (all systems)
  monitor                 Start live monitoring dashboard
  checkpoints             List all checkpoints
  doctor                  Run diagnostic checks
  cancel                  Cancel active in-session Ralph loop

  ╔═══════════════════════════════════════════════════════════════════════════╗
  ║                            UTILITIES                                       ║
  ╚═══════════════════════════════════════════════════════════════════════════╝

  clean                   Clean up agent workspace
  reset                   Reset circuit breaker
  version                 Show versions of all Ralph components

OPTIONS (for loop/run/ultimate):
  -m, --monitor           Start with tmux monitoring
  -v, --verbose           Enable verbose progress
  -q, --quiet             Disable verbose progress
  -t, --timeout MIN       Set execution timeout (default: 30)
  --max-turns N           Max Claude turns per execution (default: 5)
  --reset-interval N      Context reset interval in loops (default: 3)
  --no-checkpoints        Disable checkpoint system

OPTIONS (for in-session):
  --max-iterations N      Safety limit for iterations (recommended!)
  --completion-promise T  Exact phrase to signal completion

OPTIONS (for orchestrate/orch):
  -a, --agent AGENT       AI agent: claude, gemini, kiro, acp, auto
  -i, --iterations N      Maximum iterations (default: 100)
  -p, --prompt TEXT       Inline prompt text
  -P, --prompt-file FILE  Prompt file path
  --dry-run               Test mode without executing

EXAMPLES:

  # Terminal-based autonomous loop (outside Claude)
  ralph-unified loop --monitor

  # In-session loop (inside Claude) - with safety limits!
  ralph-unified in-session "Build REST API" --max-iterations 20 --completion-promise "DONE"

  # Multi-agent orchestration
  ralph-unified orch -a claude -i 50

  # Quick task
  ralph-unified quick "Add dark mode toggle"

  # Initialize project
  ralph-unified init prd

  # Check status
  ralph-unified status

═══════════════════════════════════════════════════════════════════════════════
PHILOSOPHY: "Ralph is a Bash loop" - Persistent iteration over perfection
═══════════════════════════════════════════════════════════════════════════════

EOF
}

# ═══════════════════════════════════════════════════════════════════════════════
# COMMAND HANDLERS
# ═══════════════════════════════════════════════════════════════════════════════

cmd_loop() {
    echo -e "${CYAN}Starting Ralph Ultimate (DafnckStudio)...${NC}"
    exec "$SCRIPT_DIR/ralph-ultimate.sh" "$@"
}

cmd_in_session() {
    # This command should be run from within Claude Code
    # It outputs instructions for the /ralph-loop plugin command

    local prompt=""
    local max_iterations=""
    local completion_promise=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --max-iterations)
                max_iterations="$2"
                shift 2
                ;;
            --completion-promise)
                completion_promise="$2"
                shift 2
                ;;
            *)
                if [[ -z "$prompt" ]]; then
                    prompt="$1"
                else
                    prompt="$prompt $1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$prompt" ]]; then
        echo -e "${RED}Error: Please provide a prompt${NC}"
        echo "Usage: ralph-unified in-session \"Your task\" --max-iterations 20 --completion-promise \"DONE\""
        exit 1
    fi

    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              RALPH IN-SESSION LOOP (Plugin Mode)               ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}This command must be run INSIDE Claude Code.${NC}"
    echo ""
    echo -e "${GREEN}Run this command in Claude Code:${NC}"
    echo ""

    # Build the command
    local cmd="/ralph-loop:ralph-loop \"$prompt\""
    [[ -n "$max_iterations" ]] && cmd="$cmd --max-iterations $max_iterations"
    [[ -n "$completion_promise" ]] && cmd="$cmd --completion-promise '$completion_promise'"

    echo -e "${BLUE}$cmd${NC}"
    echo ""
    echo -e "${YELLOW}Or if you prefer the alternate plugin:${NC}"
    echo -e "${BLUE}/ralph-wiggum:ralph-loop \"$prompt\"${max_iterations:+ --max-iterations $max_iterations}${completion_promise:+ --completion-promise '$completion_promise'}${NC}"
    echo ""

    # Also check if we're already in Claude and can create the state file
    if [[ -n "$CLAUDE_CODE_ENTRYPOINT" ]] || [[ -d ".claude" ]]; then
        echo -e "${GREEN}Detected Claude Code environment. Creating state file...${NC}"
        mkdir -p .claude

        local promise_yaml="null"
        [[ -n "$completion_promise" ]] && promise_yaml="\"$completion_promise\""

        cat > .claude/ralph-loop.local.md << EOF
---
active: true
iteration: 1
max_iterations: ${max_iterations:-0}
completion_promise: $promise_yaml
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
---

$prompt
EOF
        echo -e "${GREEN}State file created: .claude/ralph-loop.local.md${NC}"
        echo ""
        echo -e "${YELLOW}The Stop Hook will now intercept exit attempts.${NC}"
        echo -e "${YELLOW}To cancel: /ralph-loop:cancel-ralph or ralph-unified cancel${NC}"
    fi
}

cmd_orchestrate() {
    echo -e "${CYAN}Starting Ralph Orchestrator (mikeyobrien)...${NC}"
    if command -v ralph &> /dev/null; then
        exec ralph run "$@"
    else
        echo -e "${RED}Error: ralph-orchestrator not installed${NC}"
        echo "Install with: pipx install ralph-orchestrator"
        exit 1
    fi
}

cmd_quick() {
    local prompt="$1"
    shift 2>/dev/null || true
    if [[ -z "$prompt" ]]; then
        echo -e "${RED}Error: Please provide a prompt${NC}"
        echo "Usage: ralph-unified quick \"Your task here\""
        exit 1
    fi
    echo -e "${CYAN}Running quick task: $prompt${NC}"
    if command -v ralph &> /dev/null; then
        ralph run -p "$prompt" -i 20 "$@"
    else
        echo -e "${YELLOW}ralph-orchestrator not available, using ralph-ultimate...${NC}"
        echo "$prompt" > /tmp/ralph_quick_prompt.md
        "$SCRIPT_DIR/ralph-ultimate.sh" --timeout 15
    fi
}

cmd_init() {
    local format="${1:-fixplan}"
    echo -e "${CYAN}Initializing Ralph project (format: $format)...${NC}"
    "$SCRIPT_DIR/ralph-init.sh" "$(pwd)"
}

cmd_setup() {
    echo -e "${CYAN}Running full Ralph setup with orchestrator...${NC}"
    if command -v ralph &> /dev/null; then
        ralph init "$@"
    else
        echo -e "${YELLOW}ralph-orchestrator not available, using ralph-init...${NC}"
        "$SCRIPT_DIR/ralph-init.sh" "$(pwd)"
    fi
}

cmd_import() {
    local file="$1"
    if [[ -z "$file" ]] || [[ ! -f "$file" ]]; then
        echo -e "${RED}Error: Please provide a valid file to import${NC}"
        exit 1
    fi
    echo -e "${CYAN}Importing $file...${NC}"

    # Check if it looks like a PRD
    if grep -qE '(user story|acceptance criteria|feature|requirement)' "$file" 2>/dev/null; then
        echo -e "${BLUE}Detected PRD/Requirements format${NC}"
        # Convert to @fix_plan.md format
        echo "## Imported Tasks from $file" > @fix_plan.md
        echo "" >> @fix_plan.md
        grep -E '^[-*]|^[0-9]+\.' "$file" | sed 's/^[-*]/- [ ]/' | sed 's/^[0-9]+\./- [ ]/' >> @fix_plan.md
        echo "" >> @fix_plan.md
        echo "## Validation" >> @fix_plan.md
        echo "- [ ] Build passes" >> @fix_plan.md
        echo "- [ ] Tests pass" >> @fix_plan.md
        echo -e "${GREEN}Created @fix_plan.md with imported tasks${NC}"
    else
        echo -e "${YELLOW}Generic file detected, creating simple task list${NC}"
        echo "## Tasks from $file" > @fix_plan.md
        echo "" >> @fix_plan.md
        echo "- [ ] Review and implement: $file" >> @fix_plan.md
        echo -e "${GREEN}Created @fix_plan.md${NC}"
    fi
}

cmd_status() {
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    RALPH STATUS                            ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # In-session Ralph Loop status
    echo -e "${BLUE}▶ Ralph In-Session Loop (Plugin):${NC}"
    if [[ -f ".claude/ralph-loop.local.md" ]]; then
        local iteration=$(grep '^iteration:' .claude/ralph-loop.local.md | sed 's/iteration: *//')
        local max_iter=$(grep '^max_iterations:' .claude/ralph-loop.local.md | sed 's/max_iterations: *//')
        local started=$(grep '^started_at:' .claude/ralph-loop.local.md | sed 's/started_at: *//' | tr -d '"')
        echo -e "  ${GREEN}● ACTIVE${NC}"
        echo "    Iteration: $iteration"
        echo "    Max iterations: ${max_iter:-unlimited}"
        echo "    Started: $started"
    else
        echo "  No active in-session loop"
    fi
    echo ""

    # Ralph Ultimate status
    echo -e "${BLUE}▶ Ralph Ultimate (Terminal):${NC}"
    if [[ -f "status.json" ]]; then
        cat status.json | jq . 2>/dev/null || cat status.json
    else
        echo "  No active terminal session"
    fi
    echo ""

    # Ralph Orchestrator status
    echo -e "${BLUE}▶ Ralph Orchestrator (Python):${NC}"
    if command -v ralph &> /dev/null; then
        ralph status 2>/dev/null || echo "  No active session"
    else
        echo "  Not installed"
    fi
    echo ""

    # Task files
    echo -e "${BLUE}▶ Task Files:${NC}"
    [[ -f "@fix_plan.md" ]] && echo "  ✓ @fix_plan.md"
    [[ -f "prd.json" ]] && echo "  ✓ prd.json"
    [[ -f ".claude/step.json" ]] && echo "  ✓ .claude/step.json"
    [[ -f "PROMPT.md" ]] && echo "  ✓ PROMPT.md"
    [[ -f "ralph.yml" ]] && echo "  ✓ ralph.yml"

    # Check if any task file exists
    if [[ ! -f "@fix_plan.md" ]] && [[ ! -f "prd.json" ]] && [[ ! -f ".claude/step.json" ]]; then
        echo "  ⚠ No task file found. Run 'ralph-unified init' first."
    fi
}

cmd_monitor() {
    echo -e "${CYAN}Starting monitoring dashboard...${NC}"

    # Check for tmux
    if ! command -v tmux &> /dev/null; then
        echo -e "${RED}Error: tmux is required for monitoring${NC}"
        echo "Install with: sudo apt install tmux"
        exit 1
    fi

    # Try ralph-orchestrator monitor first
    if command -v ralph &> /dev/null && [[ -f "ralph.yml" ]]; then
        echo -e "${BLUE}Using ralph-orchestrator monitor...${NC}"
        ralph run --verbose
    else
        # Use simple tail-based monitor
        echo -e "${BLUE}Starting log monitor...${NC}"
        if [[ -d "logs" ]]; then
            tail -f logs/*.log 2>/dev/null || echo "No logs yet"
        else
            echo "No logs directory. Start a Ralph session first."
        fi
    fi
}

cmd_checkpoints() {
    echo -e "${CYAN}Checkpoints:${NC}"

    # Ralph Ultimate checkpoints
    if [[ -d ".claude/checkpoints" ]]; then
        echo -e "${BLUE}▶ Ralph Ultimate checkpoints:${NC}"
        ls -la .claude/checkpoints/ 2>/dev/null
        if [[ -f ".claude/checkpoints/session.json" ]]; then
            echo ""
            echo "Session info:"
            cat .claude/checkpoints/session.json | jq . 2>/dev/null
        fi
    fi

    # Ralph Orchestrator checkpoints
    if [[ -d ".agent/checkpoints" ]]; then
        echo ""
        echo -e "${BLUE}▶ Ralph Orchestrator checkpoints:${NC}"
        ls -la .agent/checkpoints/ 2>/dev/null
    fi
}

cmd_cancel() {
    echo -e "${CYAN}Cancelling Ralph loops...${NC}"

    # Cancel in-session loop
    if [[ -f ".claude/ralph-loop.local.md" ]]; then
        local iteration=$(grep '^iteration:' .claude/ralph-loop.local.md | sed 's/iteration: *//')
        rm -f .claude/ralph-loop.local.md
        echo -e "${GREEN}Cancelled in-session Ralph loop (was at iteration $iteration)${NC}"
    else
        echo "No active in-session Ralph loop"
    fi

    # Also clean terminal session if present
    if [[ -f ".ralph_paused_at" ]]; then
        rm -f .ralph_paused_at
        echo "Removed terminal loop pause marker"
    fi
}

cmd_doctor() {
    echo -e "${CYAN}Running Ralph diagnostics...${NC}"
    echo ""

    echo -e "${BLUE}▶ Components:${NC}"

    # Check ralph-ultimate
    if [[ -x "$SCRIPT_DIR/ralph-ultimate.sh" ]]; then
        echo -e "  ${GREEN}✓${NC} ralph-ultimate.sh"
    else
        echo -e "  ${RED}✗${NC} ralph-ultimate.sh not found or not executable"
    fi

    # Check ralph-orchestrator
    if command -v ralph &> /dev/null; then
        local orch_version=$(ralph --help 2>&1 | grep -oE 'version [0-9.]+' | head -1 || echo "installed")
        echo -e "  ${GREEN}✓${NC} ralph-orchestrator ($orch_version)"
    else
        echo -e "  ${YELLOW}○${NC} ralph-orchestrator not installed"
    fi

    # Check plugins
    echo ""
    echo -e "${BLUE}▶ Plugins:${NC}"

    local plugin_cache="$HOME/.claude/plugins/cache/claude-plugins-official/ralph-loop"
    if [[ -d "$plugin_cache" ]]; then
        echo -e "  ${GREEN}✓${NC} ralph-loop@claude-plugins-official"
    else
        echo -e "  ${YELLOW}○${NC} ralph-loop plugin not cached"
    fi

    local wiggum_cache="$HOME/.claude/plugins/cache/claude-code-plugins/ralph-wiggum"
    if [[ -d "$wiggum_cache" ]]; then
        echo -e "  ${GREEN}✓${NC} ralph-wiggum@claude-code-plugins"
    else
        echo -e "  ${YELLOW}○${NC} ralph-wiggum plugin not cached"
    fi

    # Check Claude CLI
    if command -v claude &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} claude CLI"
    else
        echo -e "  ${RED}✗${NC} claude CLI not found"
    fi

    # Check tmux
    if command -v tmux &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} tmux"
    else
        echo -e "  ${YELLOW}○${NC} tmux not installed (optional)"
    fi

    # Check jq
    if command -v jq &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} jq"
    else
        echo -e "  ${YELLOW}○${NC} jq not installed (optional)"
    fi

    echo ""
    echo -e "${BLUE}▶ Project Status:${NC}"

    # Check active loops
    if [[ -f ".claude/ralph-loop.local.md" ]]; then
        echo -e "  ${GREEN}●${NC} In-session loop ACTIVE"
    fi

    # Check task files
    local has_tasks=false
    if [[ -f "@fix_plan.md" ]]; then
        local total=$(grep -c "^- \[" @fix_plan.md 2>/dev/null || echo "0")
        local done=$(grep -c "^- \[x\]" @fix_plan.md 2>/dev/null || echo "0")
        echo -e "  ${GREEN}✓${NC} @fix_plan.md ($done/$total tasks done)"
        has_tasks=true
    fi
    if [[ -f "prd.json" ]]; then
        local total=$(jq '.userStories | length' prd.json 2>/dev/null || echo "?")
        local done=$(jq '[.userStories[] | select(.passes == true)] | length' prd.json 2>/dev/null || echo "?")
        echo -e "  ${GREEN}✓${NC} prd.json ($done/$total stories done)"
        has_tasks=true
    fi
    if [[ -f ".claude/step.json" ]]; then
        echo -e "  ${GREEN}✓${NC} .claude/step.json"
        has_tasks=true
    fi

    if [[ "$has_tasks" == "false" ]]; then
        echo -e "  ${YELLOW}⚠${NC} No task file found"
        echo "     Run: ralph-unified init"
    fi

    # Check if build works
    echo ""
    echo -e "${BLUE}▶ Build Check:${NC}"
    if [[ -f "package.json" ]]; then
        if npm run build --dry-run &>/dev/null; then
            echo -e "  ${GREEN}✓${NC} npm build configured"
        else
            echo -e "  ${YELLOW}○${NC} npm build check skipped"
        fi
    else
        echo -e "  ${YELLOW}○${NC} No package.json (not a Node project)"
    fi

    echo ""
    echo -e "${GREEN}Diagnostics complete!${NC}"
}

cmd_clean() {
    echo -e "${CYAN}Cleaning up...${NC}"

    # Clean ralph-ultimate files
    rm -f status.json progress.json .exit_signals .refactor_queue .ralph_paused_at 2>/dev/null

    # Clean in-session state
    rm -f .claude/ralph-loop.local.md 2>/dev/null

    # Clean ralph-orchestrator
    if command -v ralph &> /dev/null; then
        ralph clean 2>/dev/null || true
    fi

    echo -e "${GREEN}Cleaned up Ralph workspace${NC}"
}

cmd_reset() {
    echo -e "${CYAN}Resetting circuit breaker...${NC}"
    source "$SCRIPT_DIR/lib/circuit_breaker.sh" 2>/dev/null || true
    if type reset_circuit_breaker &>/dev/null; then
        reset_circuit_breaker "Manual reset via ralph-unified"
    fi
    rm -f .circuit_breaker_state 2>/dev/null
    echo -e "${GREEN}Circuit breaker reset${NC}"
}

cmd_version() {
    echo -e "${CYAN}Ralph Unified System v$VERSION${NC}"
    echo ""
    echo "Components:"
    echo "  • ralph-ultimate: v2.0 (DafnckStudio)"
    echo "  • frankbria libs: v1.0.0"
    if command -v ralph &> /dev/null; then
        echo "  • ralph-orchestrator: $(ralph --help 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo 'installed')"
    else
        echo "  • ralph-orchestrator: not installed"
    fi
    echo ""
    echo "Plugins:"
    [[ -d "$HOME/.claude/plugins/cache/claude-plugins-official/ralph-loop" ]] && echo "  • ralph-loop@claude-plugins-official ✓"
    [[ -d "$HOME/.claude/plugins/cache/claude-code-plugins/ralph-wiggum" ]] && echo "  • ralph-wiggum@claude-code-plugins ✓"
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN ROUTER
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    local command="${1:-help}"
    shift 2>/dev/null || true

    case "$command" in
        # Execution modes
        loop|run|ultimate)
            cmd_loop "$@"
            ;;
        in-session|insession|session|plugin)
            cmd_in_session "$@"
            ;;
        orchestrate|orch)
            cmd_orchestrate "$@"
            ;;
        quick|q)
            cmd_quick "$@"
            ;;

        # Setup
        init)
            cmd_init "$@"
            ;;
        setup)
            cmd_setup "$@"
            ;;
        import)
            cmd_import "$@"
            ;;

        # Monitoring
        status|st)
            cmd_status "$@"
            ;;
        monitor|mon)
            cmd_monitor "$@"
            ;;
        checkpoints|cp)
            cmd_checkpoints "$@"
            ;;
        doctor|diag)
            cmd_doctor "$@"
            ;;
        cancel|stop)
            cmd_cancel "$@"
            ;;

        # Utilities
        clean)
            cmd_clean "$@"
            ;;
        reset)
            cmd_reset "$@"
            ;;
        version|v|-v|--version)
            cmd_version
            ;;

        # Help
        help|-h|--help)
            show_help
            ;;

        *)
            echo -e "${RED}Unknown command: $command${NC}"
            echo "Run 'ralph-unified help' for usage"
            exit 1
            ;;
    esac
}

main "$@"
