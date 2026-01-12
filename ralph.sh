#!/bin/bash

# Claude Code Ralph Loop - Unlimited Edition
# Based on frankbria/ralph-claude-code with modifications:
# - No rate limiting (unlimited calls)
# - Auto-resume on 5-hour API limit (no user interaction)
# - Simplified for reliability

set -e  # Exit on any error

# Source library components (resolve symlinks to find real script location)
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_PATH" ]]; do
    SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    [[ $SCRIPT_PATH != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
source "$SCRIPT_DIR/lib/date_utils.sh"
source "$SCRIPT_DIR/lib/response_analyzer.sh"
source "$SCRIPT_DIR/lib/circuit_breaker.sh"
source "$SCRIPT_DIR/lib/playwright_verify.sh" 2>/dev/null || true

# Configuration
PROMPT_FILE="PROMPT.md"
LOG_DIR="logs"
DOCS_DIR="docs/generated"
STATUS_FILE="status.json"
PROGRESS_FILE="progress.json"
CLAUDE_CODE_CMD="claude"
CLAUDE_TIMEOUT_MINUTES=15
VERBOSE_PROGRESS=false
USE_TMUX=false

# UNLIMITED MODE - No rate limiting
RATE_LIMIT_ENABLED=false
MAX_CALLS_PER_HOUR=999999999

# AUTO-RESUME ON 5H LIMIT - No user interaction
AUTO_RESUME_ON_5H_LIMIT=true
API_LIMIT_WAIT_MINUTES=65  # Wait 65 minutes when 5h limit hit

# Exit detection configuration
EXIT_SIGNALS_FILE=".exit_signals"
MAX_CONSECUTIVE_TEST_LOOPS=3
MAX_CONSECUTIVE_DONE_SIGNALS=2
TEST_PERCENTAGE_THRESHOLD=30

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Playwright verification settings
PLAYWRIGHT_ENABLED=true
PLAYWRIGHT_DEV_PORTS="3000 3001 5173 8080 22001 22002 33001"  # Common dev server ports

# Initialize directories
mkdir -p "$LOG_DIR" "$DOCS_DIR" "logs/screenshots"

# Run Playwright verification after successful loop
run_playwright_verification() {
    local loop_count=$1

    # Skip if Playwright is disabled or not available
    if [[ "$PLAYWRIGHT_ENABLED" != "true" ]]; then
        return 0
    fi

    if ! type check_playwright &>/dev/null || ! check_playwright; then
        log_status "INFO" "Playwright not available, skipping verification"
        return 0
    fi

    # Detect running dev server
    local dev_url=""
    for port in $PLAYWRIGHT_DEV_PORTS; do
        if curl -s --connect-timeout 2 "http://localhost:$port" > /dev/null 2>&1; then
            dev_url="http://localhost:$port"
            break
        fi
        # Also check VPS IP
        if curl -s --connect-timeout 2 "http://72.61.197.216:$port" > /dev/null 2>&1; then
            dev_url="http://72.61.197.216:$port"
            break
        fi
    done

    if [[ -z "$dev_url" ]]; then
        log_status "INFO" "No dev server detected, skipping Playwright verification"
        return 0
    fi

    log_status "INFO" "🔍 Running Playwright verification on $dev_url"

    local screenshot_name="loop_${loop_count}_$(date +%Y%m%d_%H%M%S)"

    # Take screenshot
    if take_screenshot "$dev_url" "$screenshot_name"; then
        log_status "SUCCESS" "📸 Screenshot saved: logs/screenshots/${screenshot_name}_*.png"
    else
        log_status "WARN" "Screenshot failed (non-critical)"
    fi

    # Check console errors
    if check_console_errors "$dev_url"; then
        log_status "SUCCESS" "✅ No console errors detected"
    else
        log_status "WARN" "⚠️ Console errors detected - see logs above"
        # Record in exit signals for potential circuit breaker consideration
        if [[ -f "$EXIT_SIGNALS_FILE" ]]; then
            local signals=$(cat "$EXIT_SIGNALS_FILE")
            echo "$signals" | jq --arg ts "$(date -Iseconds)" \
                '.completion_indicators += [{"type": "console_errors", "timestamp": $ts}]' > "$EXIT_SIGNALS_FILE.tmp" \
                && mv "$EXIT_SIGNALS_FILE.tmp" "$EXIT_SIGNALS_FILE"
        fi
    fi

    return 0
}

# Check if tmux is available
check_tmux_available() {
    if ! command -v tmux &> /dev/null; then
        log_status "ERROR" "tmux is not installed. Please install tmux or run without --monitor flag."
        exit 1
    fi
}

# Setup tmux session with monitor
setup_tmux_session() {
    local session_name="ralph-$(date +%s)"
    local ralph_home="${RALPH_HOME:-$HOME/.ralph}"

    log_status "INFO" "Setting up tmux session: $session_name"

    tmux new-session -d -s "$session_name" -c "$(pwd)"
    tmux split-window -h -t "$session_name" -c "$(pwd)"

    if command -v ralph-monitor &> /dev/null; then
        tmux send-keys -t "$session_name:0.1" "ralph-monitor" Enter
    else
        tmux send-keys -t "$session_name:0.1" "'$ralph_home/ralph_monitor.sh'" Enter
    fi

    local ralph_cmd
    if command -v ralph &> /dev/null; then
        ralph_cmd="ralph"
    else
        ralph_cmd="'$ralph_home/ralph_loop.sh'"
    fi

    if [[ "$PROMPT_FILE" != "PROMPT.md" ]]; then
        ralph_cmd="$ralph_cmd --prompt '$PROMPT_FILE'"
    fi

    tmux send-keys -t "$session_name:0.0" "$ralph_cmd" Enter
    tmux select-pane -t "$session_name:0.0"
    tmux rename-window -t "$session_name:0" "Ralph: Loop | Monitor"

    log_status "SUCCESS" "Tmux session created. Attaching..."
    log_status "INFO" "Use Ctrl+B then D to detach"
    log_status "INFO" "Use 'tmux attach -t $session_name' to reattach"

    tmux attach-session -t "$session_name"
    exit 0
}

# Initialize tracking (simplified - no rate limit tracking)
init_tracking() {
    # Initialize exit signals tracking if it doesn't exist
    if [[ ! -f "$EXIT_SIGNALS_FILE" ]]; then
        echo '{"test_only_loops": [], "done_signals": [], "completion_indicators": []}' > "$EXIT_SIGNALS_FILE"
    fi

    # Initialize circuit breaker
    init_circuit_breaker
}

# Log function with timestamps and colors
log_status() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local color=""

    case $level in
        "INFO")  color=$BLUE ;;
        "WARN")  color=$YELLOW ;;
        "ERROR") color=$RED ;;
        "SUCCESS") color=$GREEN ;;
        "LOOP") color=$PURPLE ;;
    esac

    echo -e "${color}[$timestamp] [$level] $message${NC}"
    echo "[$timestamp] [$level] $message" >> "$LOG_DIR/ralph.log"
}

# Update status JSON for external monitoring
update_status() {
    local loop_count=$1
    local last_action=$2
    local status=$3
    local exit_reason=${4:-""}

    cat > "$STATUS_FILE" << STATUSEOF
{
    "timestamp": "$(get_iso_timestamp)",
    "loop_count": $loop_count,
    "mode": "unlimited",
    "auto_resume": $AUTO_RESUME_ON_5H_LIMIT,
    "last_action": "$last_action",
    "status": "$status",
    "exit_reason": "$exit_reason"
}
STATUSEOF
}

# Check if we should gracefully exit
should_exit_gracefully() {
    if [[ ! -f "$EXIT_SIGNALS_FILE" ]]; then
        return 1
    fi

    local signals=$(cat "$EXIT_SIGNALS_FILE")

    local recent_test_loops
    local recent_done_signals
    local recent_completion_indicators

    recent_test_loops=$(echo "$signals" | jq '.test_only_loops | length' 2>/dev/null || echo "0")
    recent_done_signals=$(echo "$signals" | jq '.done_signals | length' 2>/dev/null || echo "0")
    recent_completion_indicators=$(echo "$signals" | jq '.completion_indicators | length' 2>/dev/null || echo "0")

    # Check for exit conditions

    # 1. Too many consecutive test-only loops
    if [[ $recent_test_loops -ge $MAX_CONSECUTIVE_TEST_LOOPS ]]; then
        log_status "WARN" "Exit condition: Too many test-focused loops ($recent_test_loops >= $MAX_CONSECUTIVE_TEST_LOOPS)"
        echo "test_saturation"
        return 0
    fi

    # 2. Multiple "done" signals
    if [[ $recent_done_signals -ge $MAX_CONSECUTIVE_DONE_SIGNALS ]]; then
        log_status "WARN" "Exit condition: Multiple completion signals ($recent_done_signals >= $MAX_CONSECUTIVE_DONE_SIGNALS)"
        echo "completion_signals"
        return 0
    fi

    # 3. Strong completion indicators
    if [[ $recent_completion_indicators -ge 2 ]]; then
        log_status "WARN" "Exit condition: Strong completion indicators ($recent_completion_indicators)"
        echo "project_complete"
        return 0
    fi

    # 4. Check fix_plan.md for completion
    if [[ -f "@fix_plan.md" ]]; then
        local total_items=$(grep -c "^- \[" "@fix_plan.md" 2>/dev/null || echo "0")
        local completed_items=$(grep -c "^- \[x\]" "@fix_plan.md" 2>/dev/null || echo "0")

        [[ -z "$total_items" ]] && total_items=0
        [[ -z "$completed_items" ]] && completed_items=0

        if [[ $total_items -gt 0 ]] && [[ $completed_items -eq $total_items ]]; then
            log_status "WARN" "Exit condition: All fix_plan.md items completed ($completed_items/$total_items)"
            echo "plan_complete"
            return 0
        fi
    fi

    echo ""
}

# Main execution function
execute_claude_code() {
    local timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
    local output_file="$LOG_DIR/claude_output_${timestamp}.log"
    local loop_count=$1

    log_status "LOOP" "Executing Claude Code (Loop #$loop_count)"
    local timeout_seconds=$((CLAUDE_TIMEOUT_MINUTES * 60))
    log_status "INFO" "Starting Claude Code execution... (timeout: ${CLAUDE_TIMEOUT_MINUTES}m)"

    if timeout ${timeout_seconds}s $CLAUDE_CODE_CMD < "$PROMPT_FILE" > "$output_file" 2>&1 &
    then
        local claude_pid=$!
        local progress_counter=0

        while kill -0 $claude_pid 2>/dev/null; do
            progress_counter=$((progress_counter + 1))
            case $((progress_counter % 4)) in
                1) progress_indicator="⠋" ;;
                2) progress_indicator="⠙" ;;
                3) progress_indicator="⠹" ;;
                0) progress_indicator="⠸" ;;
            esac

            local last_line=""
            if [[ -f "$output_file" && -s "$output_file" ]]; then
                last_line=$(tail -1 "$output_file" 2>/dev/null | head -c 80)
            fi

            cat > "$PROGRESS_FILE" << EOF
{
    "status": "executing",
    "indicator": "$progress_indicator",
    "elapsed_seconds": $((progress_counter * 10)),
    "last_output": "$last_line",
    "timestamp": "$(date '+%Y-%m-%d %H:%M:%S')"
}
EOF

            if [[ "$VERBOSE_PROGRESS" == "true" ]]; then
                if [[ -n "$last_line" ]]; then
                    log_status "INFO" "$progress_indicator Claude Code: $last_line... (${progress_counter}0s)"
                else
                    log_status "INFO" "$progress_indicator Claude Code working... (${progress_counter}0s elapsed)"
                fi
            fi

            sleep 10
        done

        wait $claude_pid
        local exit_code=$?

        if [ $exit_code -eq 0 ]; then
            echo '{"status": "completed", "timestamp": "'$(date '+%Y-%m-%d %H:%M:%S')'"}' > "$PROGRESS_FILE"

            log_status "SUCCESS" "Claude Code execution completed successfully"

            log_status "INFO" "Analyzing Claude Code response..."
            analyze_response "$output_file" "$loop_count"

            update_exit_signals
            log_analysis_summary

            local files_changed=$(git diff --name-only 2>/dev/null | wc -l || echo 0)
            local has_errors="false"

            if grep -v '"[^"]*error[^"]*":' "$output_file" 2>/dev/null | \
               grep -qE '(^Error:|^ERROR:|^error:|\]: error|Link: error|Error occurred|failed with error|[Ee]xception|Fatal|FATAL)'; then
                has_errors="true"
                log_status "WARN" "Errors detected in output, check: $output_file"
            fi
            local output_length=$(wc -c < "$output_file" 2>/dev/null || echo 0)

            record_loop_result "$loop_count" "$files_changed" "$has_errors" "$output_length"
            local circuit_result=$?

            if [[ $circuit_result -ne 0 ]]; then
                log_status "WARN" "Circuit breaker opened - halting execution"
                return 3
            fi

            # Playwright verification (if enabled and dev server detected)
            run_playwright_verification "$loop_count"

            return 0
        else
            echo '{"status": "failed", "timestamp": "'$(date '+%Y-%m-%d %H:%M:%S')'"}' > "$PROGRESS_FILE"

            # Check if the failure is due to API 5-hour limit
            if grep -qi "5.*hour.*limit\|limit.*reached.*try.*back\|usage.*limit.*reached" "$output_file"; then
                log_status "ERROR" "Claude API 5-hour usage limit reached"
                return 2  # Special return code for API limit
            else
                log_status "ERROR" "Claude Code execution failed, check: $output_file"
                return 1
            fi
        fi
    else
        log_status "ERROR" "Failed to start Claude Code process"
        return 1
    fi
}

# Wait for API limit reset (automatic, no user input)
wait_for_api_limit_reset() {
    local wait_minutes=$API_LIMIT_WAIT_MINUTES
    log_status "INFO" "AUTO-RESUME: Waiting $wait_minutes minutes for API limit reset..."

    local wait_seconds=$((wait_minutes * 60))
    local start_time=$(date +%s)

    while [[ $wait_seconds -gt 0 ]]; do
        local minutes=$((wait_seconds / 60))
        local seconds=$((wait_seconds % 60))
        printf "\r${YELLOW}Auto-resuming in: %02d:%02d${NC}" $minutes $seconds
        sleep 1
        ((wait_seconds--))
    done
    printf "\n"

    log_status "SUCCESS" "Wait complete. Resuming Ralph loop..."
}

# Cleanup function
cleanup() {
    log_status "INFO" "Ralph loop interrupted. Cleaning up..."
    update_status "$loop_count" "interrupted" "stopped"
    exit 0
}

trap cleanup SIGINT SIGTERM

loop_count=0

# Main loop
main() {
    log_status "SUCCESS" "Ralph loop starting - UNLIMITED MODE"
    log_status "INFO" "Rate limiting: DISABLED"
    log_status "INFO" "Auto-resume on 5h limit: ENABLED ($API_LIMIT_WAIT_MINUTES minutes)"
    log_status "INFO" "Logs: $LOG_DIR/ | Status: $STATUS_FILE"

    if [[ ! -f "$PROMPT_FILE" ]]; then
        log_status "ERROR" "Prompt file '$PROMPT_FILE' not found!"
        echo ""
        echo "This directory is not a Ralph project or PROMPT.md is missing."
        echo ""
        echo "To fix this:"
        echo "  1. Create a new project: ralph-setup my-project"
        echo "  2. Import requirements: ralph-import requirements.md"
        echo "  3. Navigate to an existing Ralph project"
        echo "  4. Or create PROMPT.md manually"
        exit 1
    fi

    log_status "INFO" "Starting main loop..."

    while true; do
        loop_count=$((loop_count + 1))
        init_tracking

        log_status "LOOP" "=== Starting Loop #$loop_count ==="

        # Check circuit breaker
        if should_halt_execution; then
            update_status "$loop_count" "circuit_breaker_open" "halted" "stagnation_detected"
            log_status "ERROR" "Circuit breaker has opened - execution halted"
            log_status "INFO" "Run 'ralph --reset-circuit' to reset"
            break
        fi

        # Check for graceful exit conditions
        local exit_reason=$(should_exit_gracefully)
        if [[ "$exit_reason" != "" ]]; then
            log_status "SUCCESS" "Graceful exit triggered: $exit_reason"
            update_status "$loop_count" "graceful_exit" "completed" "$exit_reason"

            log_status "SUCCESS" "Ralph has completed! Final stats:"
            log_status "INFO" "  - Total loops: $loop_count"
            log_status "INFO" "  - Exit reason: $exit_reason"

            break
        fi

        update_status "$loop_count" "executing" "running"

        execute_claude_code "$loop_count"
        local exec_result=$?

        if [ $exec_result -eq 0 ]; then
            update_status "$loop_count" "completed" "success"
            sleep 5
        elif [ $exec_result -eq 3 ]; then
            # Circuit breaker opened
            update_status "$loop_count" "circuit_breaker_open" "halted" "stagnation_detected"
            log_status "ERROR" "Circuit breaker has opened - halting loop"
            break
        elif [ $exec_result -eq 2 ]; then
            # API 5-hour limit reached - AUTO RESUME
            update_status "$loop_count" "api_limit" "waiting"
            log_status "WARN" "Claude API 5-hour limit reached!"

            if [[ "$AUTO_RESUME_ON_5H_LIMIT" == "true" ]]; then
                wait_for_api_limit_reset
                # Continue loop - don't break
            else
                log_status "INFO" "Auto-resume disabled. Exiting..."
                update_status "$loop_count" "api_limit_exit" "stopped" "api_5hour_limit"
                break
            fi
        else
            update_status "$loop_count" "failed" "error"
            log_status "WARN" "Execution failed, waiting 30 seconds before retry..."
            sleep 30
        fi

        log_status "LOOP" "=== Completed Loop #$loop_count ==="
    done
}

# Help function
show_help() {
    cat << HELPEOF
Ralph Loop - Unlimited Edition (based on frankbria/ralph-claude-code)

Usage: ralph [OPTIONS]

Must be run from a Ralph project directory (contains PROMPT.md).

Options:
    -h, --help              Show this help message
    -p, --prompt FILE       Set prompt file (default: PROMPT.md)
    -s, --status            Show current status and exit
    -m, --monitor           Start with tmux monitoring
    -v, --verbose           Show detailed progress
    -t, --timeout MIN       Claude execution timeout (default: $CLAUDE_TIMEOUT_MINUTES)
    --reset-circuit         Reset circuit breaker
    --circuit-status        Show circuit breaker status
    --no-playwright         Disable Playwright verification
    --playwright-port PORT  Override dev server port for Playwright

Features:
    - UNLIMITED mode (no rate limiting)
    - AUTO-RESUME on 5-hour API limit (waits $API_LIMIT_WAIT_MINUTES min then continues)
    - Circuit breaker for stagnation detection
    - Intelligent exit detection

Example:
    ralph-setup my-project
    cd my-project
    ralph --monitor

HELPEOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -p|--prompt)
            PROMPT_FILE="$2"
            shift 2
            ;;
        -s|--status)
            if [[ -f "$STATUS_FILE" ]]; then
                echo "Current Status:"
                cat "$STATUS_FILE" | jq . 2>/dev/null || cat "$STATUS_FILE"
            else
                echo "No status file found. Ralph may not be running."
            fi
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
        -t|--timeout)
            if [[ "$2" =~ ^[1-9][0-9]*$ ]] && [[ "$2" -le 120 ]]; then
                CLAUDE_TIMEOUT_MINUTES="$2"
            else
                echo "Error: Timeout must be between 1 and 120 minutes"
                exit 1
            fi
            shift 2
            ;;
        --reset-circuit)
            SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
            source "$SCRIPT_DIR/lib/circuit_breaker.sh"
            reset_circuit_breaker "Manual reset via command line"
            exit 0
            ;;
        --circuit-status)
            SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
            source "$SCRIPT_DIR/lib/circuit_breaker.sh"
            show_circuit_status
            exit 0
            ;;
        --no-playwright)
            PLAYWRIGHT_ENABLED=false
            shift
            ;;
        --playwright-port)
            PLAYWRIGHT_DEV_PORTS="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

if [[ "$USE_TMUX" == "true" ]]; then
    check_tmux_available
    setup_tmux_session
fi

main
