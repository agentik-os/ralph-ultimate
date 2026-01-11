#!/bin/bash

# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║                    RALPH VERIFY - Vérification Playwright                      ║
# ║          Build + Screenshot + Console Errors + Server Logs                     ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Config
PLAYWRIGHT_PATH="/home/hacker/.x-navigate"
SCREENSHOT_DIR=".claude/screenshots"
LOG_DIR=".claude/logs"

# Defaults
URL=""
STEP_NAME="verify"
CHECK_BUILD=true
CHECK_SCREENSHOT=true
CHECK_CONSOLE=true
CHECK_LOGS=false

# ==============================================================================
# USAGE
# ==============================================================================

show_help() {
    cat << EOF
╔═══════════════════════════════════════════════════════════════════════════════╗
║                         RALPH VERIFY                                           ║
║              Vérification complète après chaque step                           ║
╚═══════════════════════════════════════════════════════════════════════════════╝

Usage: ralph-verify.sh [OPTIONS] --url <URL>

OPTIONS:
    -u, --url URL           URL à vérifier (obligatoire pour screenshot)
    -n, --name NAME         Nom du step (default: verify)
    -b, --build             Vérifier le build (npm run build)
    -s, --screenshot        Prendre screenshot Playwright
    -c, --console           Vérifier les erreurs console
    -l, --logs              Vérifier les logs serveur
    -a, --all               Toutes les vérifications
    --no-build              Skip build check
    --no-screenshot         Skip screenshot
    -h, --help              Afficher cette aide

EXAMPLES:
    # Vérification complète
    ralph-verify.sh --all --url "http://localhost:3000/dashboard" --name "step-3"

    # Build seulement
    ralph-verify.sh --build

    # Screenshot + Console
    ralph-verify.sh --screenshot --console --url "http://localhost:3000"

EOF
}

# ==============================================================================
# PARSE ARGUMENTS
# ==============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--url)
            URL="$2"
            shift 2
            ;;
        -n|--name)
            STEP_NAME="$2"
            shift 2
            ;;
        -b|--build)
            CHECK_BUILD=true
            shift
            ;;
        -s|--screenshot)
            CHECK_SCREENSHOT=true
            shift
            ;;
        -c|--console)
            CHECK_CONSOLE=true
            shift
            ;;
        -l|--logs)
            CHECK_LOGS=true
            shift
            ;;
        -a|--all)
            CHECK_BUILD=true
            CHECK_SCREENSHOT=true
            CHECK_CONSOLE=true
            CHECK_LOGS=true
            shift
            ;;
        --no-build)
            CHECK_BUILD=false
            shift
            ;;
        --no-screenshot)
            CHECK_SCREENSHOT=false
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# ==============================================================================
# SETUP
# ==============================================================================

mkdir -p "$SCREENSHOT_DIR"
mkdir -p "$LOG_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULT_FILE="$LOG_DIR/verify-${STEP_NAME}-${TIMESTAMP}.json"

# Initialize results
RESULTS='{
    "step": "'$STEP_NAME'",
    "timestamp": "'$(date -Iseconds)'",
    "checks": {},
    "passed": true,
    "errors": []
}'

log_check() {
    local check=$1
    local status=$2
    local message=$3

    if [[ "$status" == "pass" ]]; then
        echo -e "${GREEN}✓${NC} $check: $message"
        RESULTS=$(echo "$RESULTS" | jq ".checks[\"$check\"] = {\"status\": \"pass\", \"message\": \"$message\"}")
    else
        echo -e "${RED}✗${NC} $check: $message"
        RESULTS=$(echo "$RESULTS" | jq ".checks[\"$check\"] = {\"status\": \"fail\", \"message\": \"$message\"}")
        RESULTS=$(echo "$RESULTS" | jq ".passed = false")
        RESULTS=$(echo "$RESULTS" | jq ".errors += [\"$check: $message\"]")
    fi
}

# ==============================================================================
# BUILD CHECK
# ==============================================================================

check_build() {
    echo -e "\n${CYAN}[1/4] Build Check${NC}"

    local build_log="$LOG_DIR/build-${TIMESTAMP}.log"

    if npm run build > "$build_log" 2>&1; then
        local warnings=$(grep -c "warning" "$build_log" 2>/dev/null || echo "0")
        log_check "build" "pass" "Build succeeded ($warnings warnings)"
        return 0
    else
        local error_count=$(grep -c "error" "$build_log" 2>/dev/null || echo "?")
        log_check "build" "fail" "Build failed ($error_count errors) - see $build_log"
        return 1
    fi
}

# ==============================================================================
# SCREENSHOT CHECK (Playwright)
# ==============================================================================

check_screenshot() {
    echo -e "\n${CYAN}[2/4] Screenshot Check${NC}"

    if [[ -z "$URL" ]]; then
        log_check "screenshot" "fail" "No URL provided"
        return 1
    fi

    local screenshot_path="$SCREENSHOT_DIR/${STEP_NAME}-${TIMESTAMP}.png"

    # Use existing Playwright script
    cd "$PLAYWRIGHT_PATH"

    if node -e "
const { chromium } = require('playwright');
(async () => {
    const browser = await chromium.launch({ headless: true });
    const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });

    try {
        await page.goto('$URL', { waitUntil: 'networkidle', timeout: 30000 });
        await page.waitForTimeout(2000);
        await page.screenshot({ path: '$(pwd)/$screenshot_path', fullPage: false });
        console.log('Screenshot saved');
    } catch (err) {
        console.error('Error:', err.message);
        process.exit(1);
    }

    await browser.close();
})();
" 2>/dev/null; then
        log_check "screenshot" "pass" "Screenshot saved: $screenshot_path"
        # Return to original directory
        cd - > /dev/null

        # Store screenshot path for Claude to read
        echo "$screenshot_path" > "$LOG_DIR/last-screenshot.txt"
        return 0
    else
        cd - > /dev/null
        log_check "screenshot" "fail" "Screenshot failed for $URL"
        return 1
    fi
}

# ==============================================================================
# CONSOLE ERRORS CHECK
# ==============================================================================

check_console() {
    echo -e "\n${CYAN}[3/4] Console Errors Check${NC}"

    if [[ -z "$URL" ]]; then
        log_check "console" "fail" "No URL provided"
        return 1
    fi

    local console_log="$LOG_DIR/console-${STEP_NAME}-${TIMESTAMP}.json"

    cd "$PLAYWRIGHT_PATH"

    local errors=$(node -e "
const { chromium } = require('playwright');
(async () => {
    const browser = await chromium.launch({ headless: true });
    const page = await browser.newPage();
    const errors = [];

    page.on('console', msg => {
        if (msg.type() === 'error') errors.push(msg.text());
    });
    page.on('pageerror', err => errors.push(err.message));

    try {
        await page.goto('$URL', { waitUntil: 'networkidle', timeout: 30000 });
        await page.waitForTimeout(3000);
    } catch (err) {
        errors.push('Navigation error: ' + err.message);
    }

    await browser.close();
    console.log(JSON.stringify(errors));
})();
" 2>/dev/null)

    cd - > /dev/null

    echo "$errors" > "$console_log"

    local error_count=$(echo "$errors" | jq 'length')

    if [[ "$error_count" == "0" ]]; then
        log_check "console" "pass" "No console errors"
        return 0
    else
        log_check "console" "fail" "$error_count console errors - see $console_log"
        return 1
    fi
}

# ==============================================================================
# SERVER LOGS CHECK
# ==============================================================================

check_logs() {
    echo -e "\n${CYAN}[4/4] Server Logs Check${NC}"

    local server_errors=0

    # Check Next.js logs
    if [[ -f ".next/server.log" ]]; then
        server_errors=$(tail -100 .next/server.log 2>/dev/null | grep -ci "error\|exception\|fatal" || echo "0")
    fi

    # Check npm logs
    if [[ -f "npm-debug.log" ]]; then
        server_errors=$((server_errors + $(tail -50 npm-debug.log 2>/dev/null | grep -ci "error" || echo "0")))
    fi

    if [[ $server_errors -eq 0 ]]; then
        log_check "server_logs" "pass" "No server errors detected"
        return 0
    else
        log_check "server_logs" "fail" "$server_errors server errors detected"
        return 1
    fi
}

# ==============================================================================
# MAIN
# ==============================================================================

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                    RALPH VERIFY                                ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo -e "Step: ${BLUE}$STEP_NAME${NC}"
echo -e "URL:  ${BLUE}${URL:-'(none)'}${NC}"
echo ""

FAILED=0

# Run checks
if [[ "$CHECK_BUILD" == "true" ]]; then
    check_build || FAILED=$((FAILED + 1))
fi

if [[ "$CHECK_SCREENSHOT" == "true" ]]; then
    check_screenshot || FAILED=$((FAILED + 1))
fi

if [[ "$CHECK_CONSOLE" == "true" ]]; then
    check_console || FAILED=$((FAILED + 1))
fi

if [[ "$CHECK_LOGS" == "true" ]]; then
    check_logs || FAILED=$((FAILED + 1))
fi

# Save results
echo "$RESULTS" | jq . > "$RESULT_FILE"

# Summary
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"

if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}✅ ALL CHECKS PASSED${NC}"
    echo -e "Results: $RESULT_FILE"
    exit 0
else
    echo -e "${RED}❌ $FAILED CHECK(S) FAILED${NC}"
    echo -e "Results: $RESULT_FILE"
    echo ""
    echo "Errors:"
    echo "$RESULTS" | jq -r '.errors[]' 2>/dev/null
    exit 1
fi
