#!/bin/bash

# Playwright Verification for Ralph
# Takes screenshots and checks for console errors after each task

PLAYWRIGHT_DIR="/home/hacker/.x-navigate"
SCREENSHOTS_DIR="logs/screenshots"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if Playwright is available
check_playwright() {
    if [[ -d "$PLAYWRIGHT_DIR" ]] && command -v node &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Take a screenshot of a URL
# Usage: take_screenshot <url> <name>
take_screenshot() {
    local url="$1"
    local name="$2"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local output_file="$SCREENSHOTS_DIR/${name}_${timestamp}.png"

    if ! check_playwright; then
        echo -e "${YELLOW}⚠️ Playwright not available, skipping screenshot${NC}"
        return 1
    fi

    mkdir -p "$SCREENSHOTS_DIR"

    cd "$PLAYWRIGHT_DIR" && node -e "
const { chromium } = require('playwright');
(async () => {
    const browser = await chromium.launch({ headless: true });
    const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
    try {
        await page.goto('$url', { waitUntil: 'networkidle', timeout: 30000 });
        await page.screenshot({ path: '$output_file', fullPage: false });
        console.log('Screenshot saved: $output_file');
    } catch (e) {
        console.error('Screenshot failed:', e.message);
        process.exit(1);
    } finally {
        await browser.close();
    }
})();
" 2>&1

    if [[ -f "$output_file" ]]; then
        echo -e "${GREEN}✅ Screenshot: $output_file${NC}"
        return 0
    else
        echo -e "${RED}❌ Screenshot failed${NC}"
        return 1
    fi
}

# Check for console errors on a page
# Usage: check_console_errors <url>
check_console_errors() {
    local url="$1"

    if ! check_playwright; then
        echo -e "${YELLOW}⚠️ Playwright not available, skipping console check${NC}"
        return 0
    fi

    local errors=$(cd "$PLAYWRIGHT_DIR" && node -e "
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
        await page.goto('$url', { waitUntil: 'networkidle', timeout: 30000 });
        await page.waitForTimeout(2000);
    } catch (e) {
        errors.push('Page load error: ' + e.message);
    }

    await browser.close();

    if (errors.length > 0) {
        console.log(JSON.stringify(errors));
        process.exit(1);
    }
})();
" 2>&1)

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✅ No console errors${NC}"
        return 0
    else
        echo -e "${RED}❌ Console errors found:${NC}"
        echo "$errors" | jq -r '.[]' 2>/dev/null || echo "$errors"
        return 1
    fi
}

# Full verification (screenshot + console errors)
# Usage: verify_url <url> <name>
verify_url() {
    local url="$1"
    local name="$2"
    local result=0

    echo -e "${YELLOW}🔍 Verifying: $url${NC}"

    # Take screenshot
    take_screenshot "$url" "$name" || result=1

    # Check console errors
    check_console_errors "$url" || result=1

    return $result
}

# Quick verify script (can be called directly)
# Usage: playwright_verify.sh <url> <name>
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ -z "$1" ]]; then
        echo "Usage: playwright_verify.sh <url> [name]"
        echo ""
        echo "Examples:"
        echo "  playwright_verify.sh http://localhost:3000 homepage"
        echo "  playwright_verify.sh http://localhost:3000/dashboard dashboard"
        exit 1
    fi

    url="$1"
    name="${2:-verify}"

    verify_url "$url" "$name"
fi

# Export functions for sourcing
export -f check_playwright
export -f take_screenshot
export -f check_console_errors
export -f verify_url
