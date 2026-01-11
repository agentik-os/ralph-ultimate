#!/bin/bash

# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║                           RALPH ULTIMATE v3                                    ║
# ║         Full Autonomous AI Development Loop - ZERO LIMITS                      ║
# ║                                                                                ║
# ║  Based on: frankbria/ralph-claude-code + DafnckStudio Ralph                   ║
# ║  Author: Gareth (DafnckStudio)                                                ║
# ║  v3: + Playwright Verification (Build + Screenshot + Console + Logs)          ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

set -e

# ==============================================================================
# CONFIGURATION - FULL AUTONOMY MODE
# ==============================================================================

# ZERO RATE LIMITS - Run without any restrictions
MAX_CALLS_PER_HOUR=999999999
RATE_LIMIT_ENABLED=false

# 5-Hour API Limit Handling - AUTO RESUME
AUTO_RESUME_ON_5H_LIMIT=true
FIVE_HOUR_WAIT_MINUTES=65

# Auto-Refactoring - Keep code quality high
AUTO_REFACTOR_ENABLED=true
MAX_FILE_LINES=300
MAX_FUNCTION_LINES=50

# ═══════════════════════════════════════════════════════════════════════════════
# FIX: CONTEXT RESET / PROMPT TOO LONG
# ═══════════════════════════════════════════════════════════════════════════════

# CRITICAL: Limit Claude's conversation depth to prevent "Prompt too long"
MAX_TURNS_PER_EXECUTION=5        # Claude can do max 5 tool calls per execution
CONTEXT_RESET_INTERVAL=3         # Force context reset every N loops
MAX_PROMPT_CHARS=4000            # Maximum characters in prompt
CHECKPOINT_ENABLED=true          # Enable checkpoint system

# Execution Settings
CLAUDE_TIMEOUT_MINUTES=30
VERBOSE_PROGRESS=true
USE_TMUX=false

# ═══════════════════════════════════════════════════════════════════════════════
# v3: PLAYWRIGHT VERIFICATION
# ═══════════════════════════════════════════════════════════════════════════════

VERIFY_ENABLED=true                # Enable Playwright verification after each step
VERIFY_BUILD=true                  # Check npm run build
VERIFY_SCREENSHOT=true             # Take screenshot with Playwright
VERIFY_CONSOLE=true                # Check console errors
VERIFY_LOGS=false                  # Check server logs (optional)
VERIFY_MAX_RETRIES=3               # Max retries per step if verification fails
DEV_SERVER_URL=""                  # Auto-detected or from prd.json
PLAYWRIGHT_PATH="/home/hacker/.x-navigate"
VERIFY_SCRIPT="$SCRIPT_DIR/verify/ralph-verify.sh"

# Loop Control
MAX_ITERATIONS=999999
PAUSE_BETWEEN_LOOPS=5
ERROR_RETRY_DELAY=30

# Files
# Resolve symlink to get real script directory
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LOG_DIR="logs"
STATUS_FILE="status.json"
PROGRESS_FILE="progress.json"
EXIT_SIGNALS_FILE=".exit_signals"
REFACTOR_LOG=".refactor_history"

# ═══════════════════════════════════════════════════════════════════════════════
# PROJECT-SPECIFIC CHECKPOINT DIRECTORY
# ═══════════════════════════════════════════════════════════════════════════════
CHECKPOINT_DIR=".claude/checkpoints"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# ==============================================================================
# SOURCE LIBRARY COMPONENTS
# ==============================================================================

source "$SCRIPT_DIR/lib/date_utils.sh"
source "$SCRIPT_DIR/lib/circuit_breaker.sh"
source "$SCRIPT_DIR/lib/response_analyzer.sh"
source "$SCRIPT_DIR/lib/auto_refactor.sh"

# ==============================================================================
# v3: PLAYWRIGHT VERIFICATION SYSTEM
# ==============================================================================

detect_dev_server_url() {
    # 1. Check prd.json for verification.devServerUrl
    if [[ -f "prd.json" ]]; then
        local url=$(jq -r '.verification.devServerUrl // empty' prd.json 2>/dev/null)
        if [[ -n "$url" ]]; then
            DEV_SERVER_URL="$url"
            log_status "INFO" "Dev server URL (from prd.json): $DEV_SERVER_URL"
            return 0
        fi
    fi

    # 2. Check for running Next.js server
    local port=$(lsof -i -P 2>/dev/null | grep LISTEN | grep node | grep -oE ':[0-9]+' | head -1 | tr -d ':')
    if [[ -n "$port" ]]; then
        DEV_SERVER_URL="http://localhost:$port"
        log_status "INFO" "Dev server URL (auto-detected): $DEV_SERVER_URL"
        return 0
    fi

    # 3. Check package.json for port
    if [[ -f "package.json" ]]; then
        local port=$(grep -oE '"dev".*-p\s*([0-9]+)' package.json 2>/dev/null | grep -oE '[0-9]+' | tail -1)
        if [[ -n "$port" ]]; then
            DEV_SERVER_URL="http://localhost:$port"
            log_status "INFO" "Dev server URL (from package.json): $DEV_SERVER_URL"
            return 0
        fi
    fi

    # Default
    DEV_SERVER_URL="http://localhost:3000"
    log_status "WARN" "Using default dev server URL: $DEV_SERVER_URL"
}

get_current_step_verification() {
    # Get verification info for current step from prd.json
    if [[ -f "prd.json" ]]; then
        local current_step=$(jq -r '[.userStories[] | select(.passes != true)][0]' prd.json 2>/dev/null)
        if [[ -n "$current_step" && "$current_step" != "null" ]]; then
            echo "$current_step"
            return 0
        fi
    fi
    echo "{}"
}

run_verification() {
    local loop_count=$1
    local retry_count=${2:-0}

    if [[ "$VERIFY_ENABLED" != "true" ]]; then
        return 0
    fi

    log_status "INFO" "🔍 Running Playwright verification (attempt $((retry_count + 1))/$VERIFY_MAX_RETRIES)"

    mkdir -p .claude/screenshots
    mkdir -p .claude/logs

    local verify_opts=""
    local step_name="loop-${loop_count}"

    # Get current step info
    local step_info=$(get_current_step_verification)
    local step_url=""

    if [[ -n "$step_info" && "$step_info" != "{}" ]]; then
        step_name=$(echo "$step_info" | jq -r '.id // "step"')
        local verification=$(echo "$step_info" | jq -r '.verification // {}')
        local verify_type=$(echo "$verification" | jq -r '.type // "build"')

        # Get screenshot URL if UI verification
        if [[ "$verify_type" == "ui" ]]; then
            local screenshot_path=$(echo "$verification" | jq -r '.screenshotUrl // "/"')
            step_url="${DEV_SERVER_URL}${screenshot_path}"
        fi
    fi

    # Build verification command
    if [[ "$VERIFY_BUILD" == "true" ]]; then
        verify_opts="$verify_opts --build"
    fi

    if [[ "$VERIFY_SCREENSHOT" == "true" ]] && [[ -n "$step_url" ]]; then
        verify_opts="$verify_opts --screenshot --url \"$step_url\""
    elif [[ "$VERIFY_SCREENSHOT" == "true" ]] && [[ -n "$DEV_SERVER_URL" ]]; then
        verify_opts="$verify_opts --screenshot --url \"$DEV_SERVER_URL\""
    fi

    if [[ "$VERIFY_CONSOLE" == "true" ]] && [[ -n "$DEV_SERVER_URL" ]]; then
        verify_opts="$verify_opts --console"
    fi

    if [[ "$VERIFY_LOGS" == "true" ]]; then
        verify_opts="$verify_opts --logs"
    fi

    verify_opts="$verify_opts --name \"$step_name\""

    # Run verification
    if [[ -f "$VERIFY_SCRIPT" ]]; then
        log_status "INFO" "Running: ralph-verify.sh $verify_opts"

        if eval "$VERIFY_SCRIPT $verify_opts" 2>&1 | tee ".claude/logs/verify-${loop_count}.log"; then
            log_status "SUCCESS" "✅ Verification passed"
            return 0
        else
            log_status "WARN" "❌ Verification failed"

            if [[ $retry_count -lt $((VERIFY_MAX_RETRIES - 1)) ]]; then
                log_status "INFO" "Will fix and retry..."
                return 1  # Signal to fix and retry
            else
                log_status "ERROR" "Max retries reached for verification"
                return 2  # Signal to stop
            fi
        fi
    else
        # Fallback: simple build check
        log_status "WARN" "Verify script not found, using simple build check"
        if npm run build > ".claude/logs/build-${loop_count}.log" 2>&1; then
            log_status "SUCCESS" "✅ Build passed"
            return 0
        else
            log_status "WARN" "❌ Build failed"
            return 1
        fi
    fi
}

# ==============================================================================
# CHECKPOINT SYSTEM (Per-Project)
# ==============================================================================

init_checkpoints() {
    mkdir -p "$CHECKPOINT_DIR"

    # Initialize checkpoint file if not exists
    if [[ ! -f "$CHECKPOINT_DIR/session.json" ]]; then
        cat > "$CHECKPOINT_DIR/session.json" << EOF
{
    "session_id": "$(date +%s)",
    "started_at": "$(date -Iseconds)",
    "last_checkpoint": null,
    "loops_completed": 0,
    "tasks_completed": [],
    "context_resets": 0,
    "last_working_state": null
}
EOF
    fi

    log_status "INFO" "Checkpoints directory: $CHECKPOINT_DIR"
}

save_checkpoint() {
    local loop_count=$1
    local task_completed=$2
    local checkpoint_name="checkpoint_loop_${loop_count}"

    # Save current state
    cat > "$CHECKPOINT_DIR/${checkpoint_name}.json" << EOF
{
    "loop": $loop_count,
    "timestamp": "$(date -Iseconds)",
    "task_completed": "$task_completed",
    "git_status": "$(git status --porcelain 2>/dev/null | wc -l)",
    "git_diff_stat": "$(git diff --stat 2>/dev/null | tail -1)",
    "task_file_state": "$(cat "$TASK_FILE" 2>/dev/null | md5sum | cut -d' ' -f1)"
}
EOF

    # Update session
    local session=$(cat "$CHECKPOINT_DIR/session.json")
    session=$(echo "$session" | jq ".last_checkpoint = \"$checkpoint_name\"")
    session=$(echo "$session" | jq ".loops_completed = $loop_count")
    session=$(echo "$session" | jq ".tasks_completed += [\"$task_completed\"]")
    echo "$session" > "$CHECKPOINT_DIR/session.json"

    log_status "SUCCESS" "Checkpoint saved: $checkpoint_name"

    # Keep only last 10 checkpoints
    ls -t "$CHECKPOINT_DIR"/checkpoint_*.json 2>/dev/null | tail -n +11 | xargs -r rm
}

load_last_checkpoint() {
    if [[ -f "$CHECKPOINT_DIR/session.json" ]]; then
        local last=$(jq -r '.last_checkpoint // empty' "$CHECKPOINT_DIR/session.json")
        if [[ -n "$last" ]] && [[ -f "$CHECKPOINT_DIR/${last}.json" ]]; then
            log_status "INFO" "Found checkpoint: $last"
            cat "$CHECKPOINT_DIR/${last}.json"
            return 0
        fi
    fi
    return 1
}

# ==============================================================================
# CONTEXT RESET SYSTEM
# ==============================================================================

should_reset_context() {
    local loop_count=$1

    # Force reset every N loops to prevent context bloat
    if [[ $((loop_count % CONTEXT_RESET_INTERVAL)) -eq 0 ]] && [[ $loop_count -gt 0 ]]; then
        return 0
    fi

    return 1
}

create_minimal_prompt() {
    local task_info=$1
    local loop_count=$2

    # Create a MINIMAL prompt to avoid "Prompt too long"
    local prompt=""

    # Get only the NEXT task, not all tasks
    case $PROJECT_TYPE in
        "ralph-frankbria")
            local next_task=$(grep "^- \[ \]" "$TASK_FILE" 2>/dev/null | head -1)
            prompt="Complete this task: $next_task"
            ;;
        "ralph-dafnck")
            local next_story=$(jq -r '[.userStories[] | select(.passes != true)][0] | .title + ": " + .description' "$TASK_FILE" 2>/dev/null)
            prompt="Complete this user story: $next_story"
            ;;
        "claude-project")
            local next_step=$(jq -r '[.steps[] | select(.status != "completed")][0] | .name' "$TASK_FILE" 2>/dev/null)
            prompt="Complete this step: $next_step"
            ;;
        *)
            prompt="Continue working on the project. Complete the next pending task."
            ;;
    esac

    # Add minimal context
    prompt="$prompt

Loop #$loop_count. After completing the task:
1. Update the task status to complete
2. If all tasks done, say 'ALL_TASKS_COMPLETE'

Keep responses concise. Focus on implementation."

    # Truncate if too long
    if [[ ${#prompt} -gt $MAX_PROMPT_CHARS ]]; then
        prompt="${prompt:0:$MAX_PROMPT_CHARS}..."
    fi

    echo "$prompt"
}

# ==============================================================================
# INITIALIZATION
# ==============================================================================

mkdir -p "$LOG_DIR"

init_ralph_ultimate() {
    log_status "INIT" "╔═══════════════════════════════════════════════════════════╗"
    log_status "INIT" "║           RALPH ULTIMATE v3 - PLAYWRIGHT VERIFY           ║"
    log_status "INIT" "╚═══════════════════════════════════════════════════════════╝"
    log_status "INFO" ""
    log_status "INFO" "Configuration:"
    log_status "INFO" "  • Rate Limits: ${RED}DISABLED${NC}"
    log_status "INFO" "  • Max Turns per Exec: ${GREEN}$MAX_TURNS_PER_EXECUTION${NC} (prevents prompt overflow)"
    log_status "INFO" "  • Context Reset: Every ${GREEN}$CONTEXT_RESET_INTERVAL${NC} loops"
    log_status "INFO" "  • Checkpoints: ${GREEN}ENABLED${NC} (per-project)"
    log_status "INFO" "  • Auto-Resume on 5h Limit: ${GREEN}ENABLED${NC}"
    log_status "INFO" "  • Playwright Verification: ${GREEN}$VERIFY_ENABLED${NC}"
    log_status "INFO" "    - Build Check: $VERIFY_BUILD"
    log_status "INFO" "    - Screenshot: $VERIFY_SCREENSHOT"
    log_status "INFO" "    - Console Errors: $VERIFY_CONSOLE"
    log_status "INFO" "    - Server Logs: $VERIFY_LOGS"
    log_status "INFO" "    - Max Retries: $VERIFY_MAX_RETRIES"
    log_status "INFO" ""

    init_circuit_breaker
    init_checkpoints

    if [[ ! -f "$EXIT_SIGNALS_FILE" ]]; then
        echo '{"test_only_loops": [], "done_signals": [], "completion_indicators": []}' > "$EXIT_SIGNALS_FILE"
    fi

    detect_project_type

    # v3: Detect dev server URL for Playwright verification
    if [[ "$VERIFY_ENABLED" == "true" ]]; then
        detect_dev_server_url
        mkdir -p .claude/screenshots
        mkdir -p .claude/logs
    fi
}

detect_project_type() {
    if [[ -f "PROMPT.md" ]]; then
        PROJECT_TYPE="ralph-frankbria"
        PROMPT_FILE="PROMPT.md"
        TASK_FILE="@fix_plan.md"
        log_status "INFO" "Detected: frankbria Ralph project"
    elif [[ -f "prd.json" ]]; then
        PROJECT_TYPE="ralph-dafnck"
        PROMPT_FILE="$SCRIPT_DIR/prompt.md"
        TASK_FILE="prd.json"
        log_status "INFO" "Detected: DafnckStudio Ralph project"
    elif [[ -f ".claude/step.json" ]]; then
        PROJECT_TYPE="claude-project"
        PROMPT_FILE="$SCRIPT_DIR/prompt.md"
        TASK_FILE=".claude/step.json"
        log_status "INFO" "Detected: Claude Code project with step.json"
    else
        PROJECT_TYPE="generic"
        PROMPT_FILE="$SCRIPT_DIR/prompt.md"
        TASK_FILE=""
        log_status "WARN" "Generic project (no task tracking file found)"
    fi
}

# ==============================================================================
# LOGGING
# ==============================================================================

log_status() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local color=""

    case $level in
        "INFO")    color=$BLUE ;;
        "WARN")    color=$YELLOW ;;
        "ERROR")   color=$RED ;;
        "SUCCESS") color=$GREEN ;;
        "LOOP")    color=$PURPLE ;;
        "INIT")    color=$CYAN ;;
        "REFACTOR") color=$CYAN ;;
        "CHECKPOINT") color=$GREEN ;;
    esac

    echo -e "${color}[$timestamp] [$level] $message${NC}"
    echo "[$timestamp] [$level] $message" >> "$LOG_DIR/ralph-ultimate.log"
}

# ==============================================================================
# STATUS TRACKING
# ==============================================================================

update_status() {
    local loop_count=$1
    local last_action=$2
    local status=$3
    local exit_reason=${4:-""}

    cat > "$STATUS_FILE" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "loop_count": $loop_count,
    "last_action": "$last_action",
    "status": "$status",
    "exit_reason": "$exit_reason",
    "rate_limits": "DISABLED",
    "max_turns": $MAX_TURNS_PER_EXECUTION,
    "context_reset_interval": $CONTEXT_RESET_INTERVAL,
    "auto_resume": $AUTO_RESUME_ON_5H_LIMIT,
    "auto_refactor": $AUTO_REFACTOR_ENABLED,
    "project_type": "$PROJECT_TYPE"
}
EOF
}

# ==============================================================================
# TASK COMPLETION DETECTION
# ==============================================================================

check_all_tasks_complete() {
    case $PROJECT_TYPE in
        "ralph-frankbria")
            if [[ -f "$TASK_FILE" ]]; then
                local total=$(grep -c "^- \[" "$TASK_FILE" 2>/dev/null | tr -d '\n' || echo "0")
                local done=$(grep -c "^- \[x\]" "$TASK_FILE" 2>/dev/null | tr -d '\n' || echo "0")
                total=$((total + 0))
                done=$((done + 0))
                if [[ $total -gt 0 ]] && [[ $done -eq $total ]]; then
                    log_status "SUCCESS" "All tasks in @fix_plan.md completed! ($done/$total)"
                    return 0
                fi
            fi
            ;;
        "ralph-dafnck")
            if [[ -f "$TASK_FILE" ]]; then
                local incomplete=$(jq '[.userStories[] | select(.passes != true)] | length' "$TASK_FILE" 2>/dev/null || echo "1")
                if [[ "$incomplete" == "0" ]]; then
                    log_status "SUCCESS" "All user stories in prd.json completed!"
                    return 0
                fi
            fi
            ;;
        "claude-project")
            if [[ -f "$TASK_FILE" ]]; then
                local incomplete=$(jq '[.steps[] | select(.status != "completed")] | length' "$TASK_FILE" 2>/dev/null || echo "1")
                if [[ "$incomplete" == "0" ]]; then
                    log_status "SUCCESS" "All steps completed!"
                    return 0
                fi
            fi
            ;;
    esac
    return 1
}

should_exit_gracefully() {
    if check_all_tasks_complete; then
        echo "all_tasks_complete"
        return 0
    fi

    if [[ -f "$EXIT_SIGNALS_FILE" ]]; then
        local signals=$(cat "$EXIT_SIGNALS_FILE")
        local done_signals=$(echo "$signals" | jq '.done_signals | length' 2>/dev/null || echo "0")
        local completion_indicators=$(echo "$signals" | jq '.completion_indicators | length' 2>/dev/null || echo "0")

        if [[ $done_signals -ge 3 ]]; then
            echo "multiple_done_signals"
            return 0
        fi

        if [[ $completion_indicators -ge 2 ]]; then
            echo "strong_completion_indicators"
            return 0
        fi
    fi

    echo ""
    return 1
}

# ==============================================================================
# 5-HOUR API LIMIT HANDLING
# ==============================================================================

handle_5h_api_limit() {
    log_status "WARN" "╔═══════════════════════════════════════════════════════════╗"
    log_status "WARN" "║         5-HOUR API LIMIT DETECTED                         ║"
    log_status "WARN" "╚═══════════════════════════════════════════════════════════╝"

    if [[ "$AUTO_RESUME_ON_5H_LIMIT" == "true" ]]; then
        log_status "INFO" "Auto-resume enabled. Waiting ${FIVE_HOUR_WAIT_MINUTES} minutes..."

        # Save checkpoint before waiting
        save_checkpoint "$loop_count" "paused_5h_limit"

        echo "$(date +%s)" > ".ralph_paused_at"

        local wait_seconds=$((FIVE_HOUR_WAIT_MINUTES * 60))
        while [[ $wait_seconds -gt 0 ]]; do
            local minutes=$((wait_seconds / 60))
            local seconds=$((wait_seconds % 60))

            if [[ $((wait_seconds % 60)) -eq 0 ]]; then
                update_status "$loop_count" "waiting_5h_limit" "paused" "api_limit_wait"
            fi

            printf "\r${YELLOW}Auto-resume in: %02d:%02d${NC}" $minutes $seconds
            sleep 1
            ((wait_seconds--))
        done

        printf "\n"
        rm -f ".ralph_paused_at"
        log_status "SUCCESS" "Wait complete! Resuming autonomous execution..."
        return 0
    else
        log_status "ERROR" "Auto-resume disabled. Stopping execution."
        return 1
    fi
}

# ==============================================================================
# AUTO-REFACTORING
# ==============================================================================

run_auto_refactor() {
    if [[ "$AUTO_REFACTOR_ENABLED" != "true" ]]; then
        return 0
    fi

    local large_files=$(find . -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" 2>/dev/null | \
                        xargs wc -l 2>/dev/null | \
                        awk -v max="$MAX_FILE_LINES" '$1 > max && $2 != "total" {print $2}')

    if [[ -n "$large_files" ]]; then
        log_status "REFACTOR" "Found large files to refactor"
        queue_refactor_task "$large_files"
    fi
}

queue_refactor_task() {
    local files=$1
    cat >> ".refactor_queue" << EOF
REFACTORING REQUIRED:
Files exceeding $MAX_FILE_LINES lines: $files
Split into smaller modules.
EOF
}

# ==============================================================================
# MAIN EXECUTION - FIXED FOR "PROMPT TOO LONG"
# ==============================================================================

execute_claude_code() {
    local loop_count=$1
    local timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
    local output_file="$LOG_DIR/claude_output_${timestamp}.log"
    local timeout_seconds=$((CLAUDE_TIMEOUT_MINUTES * 60))

    log_status "LOOP" "Executing Claude Code (Loop #$loop_count)"

    # ═══════════════════════════════════════════════════════════════════════════
    # FIX: Use minimal prompt + --max-turns to prevent "Prompt too long"
    # ═══════════════════════════════════════════════════════════════════════════

    local prompt_content=$(create_minimal_prompt "" "$loop_count")

    # Add refactoring if queued
    if [[ -f ".refactor_queue" ]]; then
        local refactor_content=$(cat .refactor_queue | head -c 500)  # Limit size
        prompt_content="$prompt_content

$refactor_content"
        rm -f ".refactor_queue"
    fi

    log_status "INFO" "Prompt size: ${#prompt_content} chars (max: $MAX_PROMPT_CHARS)"

    # ═══════════════════════════════════════════════════════════════════════════
    # USE --print AND --max-turns TO PREVENT CONTEXT EXPLOSION
    # ═══════════════════════════════════════════════════════════════════════════

    # Write prompt to temp file (avoids shell escaping issues)
    local prompt_file=$(mktemp)
    echo "$prompt_content" > "$prompt_file"

    # Execute with strict limits
    if timeout ${timeout_seconds}s claude \
        --print \
        --max-turns "$MAX_TURNS_PER_EXECUTION" \
        < "$prompt_file" > "$output_file" 2>&1 &
    then
        local claude_pid=$!
        local progress_counter=0

        while kill -0 $claude_pid 2>/dev/null; do
            progress_counter=$((progress_counter + 1))
            local elapsed=$((progress_counter * 5))

            if [[ "$VERBOSE_PROGRESS" == "true" ]]; then
                local output_size=$(wc -c < "$output_file" 2>/dev/null || echo "0")
                printf "\r${CYAN}[%ds] Output: %s bytes${NC}" $elapsed "$output_size"
            else
                printf "\r${CYAN}Working... [%ds elapsed]${NC}" $elapsed
            fi

            echo "{\"status\": \"executing\", \"elapsed\": $elapsed, \"loop\": $loop_count}" > "$PROGRESS_FILE"
            sleep 5
        done

        printf "\n"
        wait $claude_pid
        local exit_code=$?

        rm -f "$prompt_file"

        if [[ $exit_code -eq 0 ]]; then
            log_status "SUCCESS" "Claude Code execution completed"

            # Analyze response
            analyze_response "$output_file" "$loop_count"
            update_exit_signals
            log_analysis_summary

            # Check for work done
            local files_changed=$(git diff --name-only 2>/dev/null | wc -l || echo 0)
            local has_errors="false"

            if grep -qE '(Error:|ERROR:|error:|Exception|Fatal)' "$output_file" 2>/dev/null; then
                has_errors="true"
            fi

            record_loop_result "$loop_count" "$files_changed" "$has_errors" "$(wc -c < "$output_file")"

            # Save checkpoint on success
            if [[ "$CHECKPOINT_ENABLED" == "true" ]] && [[ $files_changed -gt 0 ]]; then
                save_checkpoint "$loop_count" "task_completed"
            fi

            return 0

        elif grep -qiE '(prompt.*too.*long|context.*length|token.*limit)' "$output_file" 2>/dev/null; then
            log_status "WARN" "Prompt too long detected - forcing context reset"
            return 4  # New code for prompt too long

        elif grep -qi "5.*hour.*limit\|limit.*reached\|usage.*limit" "$output_file" 2>/dev/null; then
            log_status "WARN" "5-hour API limit detected"
            return 2
        else
            log_status "ERROR" "Claude Code execution failed (exit code: $exit_code)"
            log_status "ERROR" "Check: $output_file"
            return 1
        fi
    else
        rm -f "$prompt_file"
        log_status "ERROR" "Failed to start Claude Code"
        return 1
    fi
}

# ==============================================================================
# MAIN LOOP
# ==============================================================================

main() {
    init_ralph_ultimate

    local loop_count=0
    local context_reset_count=0

    log_status "LOOP" "Starting autonomous development loop..."
    log_status "INFO" "Press Ctrl+C to stop at any time"
    log_status "INFO" ""

    while [[ $loop_count -lt $MAX_ITERATIONS ]]; do
        loop_count=$((loop_count + 1))

        log_status "LOOP" "═══════════════════════════════════════════════════════════"
        log_status "LOOP" "                    LOOP #$loop_count"
        log_status "LOOP" "═══════════════════════════════════════════════════════════"

        # ═══════════════════════════════════════════════════════════════════════
        # CONTEXT RESET CHECK
        # ═══════════════════════════════════════════════════════════════════════
        if should_reset_context "$loop_count"; then
            context_reset_count=$((context_reset_count + 1))
            log_status "INFO" "🔄 Context reset #$context_reset_count (preventing prompt overflow)"

            # Update session with context reset count
            if [[ -f "$CHECKPOINT_DIR/session.json" ]]; then
                local session=$(cat "$CHECKPOINT_DIR/session.json")
                session=$(echo "$session" | jq ".context_resets = $context_reset_count")
                echo "$session" > "$CHECKPOINT_DIR/session.json"
            fi
        fi

        # Check circuit breaker
        if should_halt_execution; then
            log_status "ERROR" "Circuit breaker opened - execution halted"
            update_status "$loop_count" "circuit_breaker" "halted" "stagnation_detected"
            break
        fi

        # Check for graceful exit
        local exit_reason=$(should_exit_gracefully)
        if [[ -n "$exit_reason" ]]; then
            log_status "SUCCESS" "╔═══════════════════════════════════════════════════════════╗"
            log_status "SUCCESS" "║         PROJECT COMPLETE!                                 ║"
            log_status "SUCCESS" "╚═══════════════════════════════════════════════════════════╝"
            log_status "SUCCESS" "Exit reason: $exit_reason"
            log_status "SUCCESS" "Total loops: $loop_count"
            log_status "SUCCESS" "Context resets: $context_reset_count"
            save_checkpoint "$loop_count" "project_complete"
            update_status "$loop_count" "graceful_exit" "completed" "$exit_reason"
            break
        fi

        # Run auto-refactor check
        run_auto_refactor

        # Update status
        update_status "$loop_count" "executing" "running"

        # Execute Claude Code
        execute_claude_code "$loop_count"
        local exec_result=$?

        case $exec_result in
            0)
                log_status "SUCCESS" "Loop #$loop_count Claude execution completed"

                # ═══════════════════════════════════════════════════════════════════════
                # v3: PLAYWRIGHT VERIFICATION AFTER SUCCESSFUL EXECUTION
                # ═══════════════════════════════════════════════════════════════════════
                if [[ "$VERIFY_ENABLED" == "true" ]]; then
                    local verify_retry=0
                    local verify_passed=false

                    while [[ $verify_retry -lt $VERIFY_MAX_RETRIES ]]; do
                        run_verification "$loop_count" "$verify_retry"
                        local verify_result=$?

                        case $verify_result in
                            0)
                                verify_passed=true
                                log_status "SUCCESS" "✅ Step #$loop_count verified and validated"
                                break
                                ;;
                            1)
                                # Verification failed - ask Claude to fix
                                verify_retry=$((verify_retry + 1))
                                log_status "WARN" "🔧 Verification failed, asking Claude to fix (retry $verify_retry/$VERIFY_MAX_RETRIES)"

                                # Create fix prompt
                                local fix_prompt="VERIFICATION FAILED - FIX REQUIRED

The previous step failed verification. Check the logs:
- Build log: .claude/logs/build-${loop_count}.log
- Console log: .claude/logs/console-*-${loop_count}.json
- Verify log: .claude/logs/verify-${loop_count}.log

Fix the errors and ensure:
1. npm run build passes
2. No console errors in the browser
3. The UI renders correctly

Focus on fixing the specific errors mentioned in the logs."

                                echo "$fix_prompt" | claude --print --max-turns 3 > "$LOG_DIR/fix_${loop_count}_${verify_retry}.log" 2>&1

                                # Continue to re-verify in next iteration
                                ;;
                            2)
                                # Max retries reached
                                log_status "ERROR" "❌ Max verification retries reached for step #$loop_count"
                                log_status "WARN" "Continuing to next step (manual intervention may be needed)"
                                verify_passed=false
                                break
                                ;;
                        esac
                    done

                    if [[ "$verify_passed" == "true" ]]; then
                        # Mark task as complete in prd.json
                        if [[ -f "prd.json" ]]; then
                            local current_id=$(jq -r '[.userStories[] | select(.passes != true)][0].id' prd.json 2>/dev/null)
                            if [[ -n "$current_id" && "$current_id" != "null" ]]; then
                                jq "(.userStories[] | select(.id == \"$current_id\")).passes = true" prd.json > prd.json.tmp && mv prd.json.tmp prd.json
                                log_status "SUCCESS" "Marked $current_id as complete in prd.json"
                            fi
                        fi
                    fi
                fi

                sleep $PAUSE_BETWEEN_LOOPS
                ;;
            1)
                log_status "WARN" "Error in loop #$loop_count, retrying in ${ERROR_RETRY_DELAY}s..."
                sleep $ERROR_RETRY_DELAY
                ;;
            2)
                if ! handle_5h_api_limit; then
                    log_status "ERROR" "Stopping due to API limit (auto-resume disabled)"
                    break
                fi
                ;;
            3)
                log_status "ERROR" "Circuit breaker triggered"
                break
                ;;
            4)
                # Prompt too long - force minimal prompt on next iteration
                log_status "WARN" "Forcing minimal prompt mode for next loop"
                MAX_PROMPT_CHARS=2000  # Reduce further
                sleep 5
                ;;
        esac

        log_status "LOOP" "Loop #$loop_count finished"
        log_status "INFO" ""
    done

    log_status "INFO" "═══════════════════════════════════════════════════════════"
    log_status "INFO" "          RALPH ULTIMATE v3 SESSION ENDED"
    log_status "INFO" "═══════════════════════════════════════════════════════════"
    log_status "INFO" "Total loops executed: $loop_count"
    log_status "INFO" "Context resets: $context_reset_count"
    log_status "INFO" "Logs available in: $LOG_DIR/"
    log_status "INFO" "Checkpoints in: $CHECKPOINT_DIR/"
}

# ==============================================================================
# CLEANUP
# ==============================================================================

cleanup() {
    log_status "INFO" "Received interrupt signal. Cleaning up..."
    save_checkpoint "$loop_count" "user_interrupt"
    update_status "$loop_count" "interrupted" "stopped" "user_interrupt"
    exit 0
}

trap cleanup SIGINT SIGTERM

# ==============================================================================
# CLI ARGUMENTS
# ==============================================================================

show_help() {
    cat << EOF
╔═══════════════════════════════════════════════════════════════════════════════╗
║                           RALPH ULTIMATE v3                                    ║
║         Full Autonomous AI Development Loop - PLAYWRIGHT VERIFY                ║
╚═══════════════════════════════════════════════════════════════════════════════╝

Usage: ralph-ultimate [OPTIONS]

Options:
    -h, --help              Show this help
    -m, --monitor           Start with tmux monitoring
    -v, --verbose           Enable verbose progress (default: on)
    -q, --quiet             Disable verbose progress
    -t, --timeout MIN       Set execution timeout (default: $CLAUDE_TIMEOUT_MINUTES)
    --max-turns N           Max Claude turns per execution (default: $MAX_TURNS_PER_EXECUTION)
    --reset-interval N      Context reset interval in loops (default: $CONTEXT_RESET_INTERVAL)
    --no-refactor           Disable auto-refactoring
    --no-auto-resume        Disable auto-resume on 5h limit
    --no-checkpoints        Disable checkpoint system
    --status                Show current status
    --reset-circuit         Reset circuit breaker
    --show-checkpoints      List all checkpoints

Verification Options (v3):
    --no-verify             Disable Playwright verification
    --no-build-check        Skip build check in verification
    --no-screenshot         Skip screenshot capture
    --no-console-check      Skip console errors check
    --with-logs             Include server logs check
    --verify-retries N      Max verification retries (default: $VERIFY_MAX_RETRIES)
    --dev-url URL           Override dev server URL

v3 New Features:
    • Playwright verification after each step
    • Auto screenshot + console error detection
    • Build check before marking task complete
    • Auto-fix on verification failure (max $VERIFY_MAX_RETRIES retries)
    • Visual verification via screenshots

v2 Improvements:
    • Fixed "Prompt is too long" error
    • Per-project checkpoint system
    • Context reset every $CONTEXT_RESET_INTERVAL loops
    • Minimal prompts (max $MAX_PROMPT_CHARS chars)
    • --max-turns limit per execution

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -m|--monitor)
            USE_TMUX=true
            shift
            ;;
        -v|--verbose)
            VERBOSE_PROGRESS=true
            shift
            ;;
        -q|--quiet)
            VERBOSE_PROGRESS=false
            shift
            ;;
        -t|--timeout)
            CLAUDE_TIMEOUT_MINUTES="$2"
            shift 2
            ;;
        --max-turns)
            MAX_TURNS_PER_EXECUTION="$2"
            shift 2
            ;;
        --reset-interval)
            CONTEXT_RESET_INTERVAL="$2"
            shift 2
            ;;
        --no-refactor)
            AUTO_REFACTOR_ENABLED=false
            shift
            ;;
        --no-auto-resume)
            AUTO_RESUME_ON_5H_LIMIT=false
            shift
            ;;
        --no-checkpoints)
            CHECKPOINT_ENABLED=false
            shift
            ;;
        --status)
            if [[ -f "$STATUS_FILE" ]]; then
                cat "$STATUS_FILE" | jq .
            else
                echo "No status file found"
            fi
            exit 0
            ;;
        --reset-circuit)
            source "$SCRIPT_DIR/lib/circuit_breaker.sh"
            reset_circuit_breaker "Manual reset"
            exit 0
            ;;
        --show-checkpoints)
            if [[ -d "$CHECKPOINT_DIR" ]]; then
                echo "Checkpoints in $CHECKPOINT_DIR:"
                ls -la "$CHECKPOINT_DIR"
                echo ""
                echo "Session info:"
                cat "$CHECKPOINT_DIR/session.json" 2>/dev/null | jq .
            else
                echo "No checkpoints directory found"
            fi
            exit 0
            ;;
        --no-verify)
            VERIFY_ENABLED=false
            shift
            ;;
        --no-build-check)
            VERIFY_BUILD=false
            shift
            ;;
        --no-screenshot)
            VERIFY_SCREENSHOT=false
            shift
            ;;
        --no-console-check)
            VERIFY_CONSOLE=false
            shift
            ;;
        --with-logs)
            VERIFY_LOGS=true
            shift
            ;;
        --verify-retries)
            VERIFY_MAX_RETRIES="$2"
            shift 2
            ;;
        --dev-url)
            DEV_SERVER_URL="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Start
main
