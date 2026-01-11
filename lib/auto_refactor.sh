#!/bin/bash
# Auto-Refactoring Component for Ralph Ultimate
# Automatically detects and queues refactoring for large files
# Handles "max tokens" errors by splitting files intelligently

source "$(dirname "${BASH_SOURCE[0]}")/date_utils.sh"

# Configuration
MAX_FILE_LINES=${MAX_FILE_LINES:-300}
MAX_FUNCTION_LINES=${MAX_FUNCTION_LINES:-50}
MAX_TOKENS_THRESHOLD=${MAX_TOKENS_THRESHOLD:-25000}
REFACTOR_LOG=${REFACTOR_LOG:-".refactor_history"}
REFACTOR_QUEUE=${REFACTOR_QUEUE:-".refactor_queue"}
TOKEN_ERROR_LOG=${TOKEN_ERROR_LOG:-".token_errors"}

# Colors
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# File extensions to check
CODE_EXTENSIONS=("ts" "tsx" "js" "jsx" "py" "go" "rs" "java" "cpp" "c" "rb")

# Approximate tokens per line (conservative estimate)
TOKENS_PER_LINE=15

# Initialize refactor tracking
init_refactor_tracking() {
    if [[ ! -f "$REFACTOR_LOG" ]]; then
        echo '{"refactored_files": [], "queued_files": [], "token_errors": [], "last_check": ""}' > "$REFACTOR_LOG"
    fi
    if [[ ! -f "$TOKEN_ERROR_LOG" ]]; then
        echo '[]' > "$TOKEN_ERROR_LOG"
    fi
}

# =============================================================================
# TOKEN ERROR DETECTION
# =============================================================================

# Detect "max tokens" error in Claude output
detect_token_error() {
    local output_file=$1

    if [[ ! -f "$output_file" ]]; then
        return 1
    fi

    # Check for various token limit error patterns
    if grep -qiE "(maximum allowed tokens|max.?tokens|token limit|context.?limit|25000|too large to process)" "$output_file" 2>/dev/null; then
        return 0  # Token error detected
    fi

    return 1  # No token error
}

# Extract file causing token error from Claude output
extract_problematic_file() {
    local output_file=$1

    if [[ ! -f "$output_file" ]]; then
        return 1
    fi

    # Try to find the file mentioned in the error context
    # Pattern: Reading file, editing file, or file path mentioned near error
    local file=$(grep -oE "(/[a-zA-Z0-9_/-]+\.(ts|tsx|js|jsx|py|go|rs|java|cpp|c|rb))" "$output_file" 2>/dev/null | tail -1)

    # Also check for relative paths
    if [[ -z "$file" ]]; then
        file=$(grep -oE "(src/[a-zA-Z0-9_/-]+\.(ts|tsx|js|jsx|py|go|rs|java|cpp|c|rb))" "$output_file" 2>/dev/null | tail -1)
    fi

    if [[ -n "$file" ]] && [[ -f "$file" ]]; then
        echo "$file"
        return 0
    fi

    return 1
}

# Handle token error - main function
handle_token_error() {
    local output_file=$1
    local current_task=$2

    echo -e "${RED}[TOKEN ERROR DETECTED]${NC} Maximum tokens exceeded"

    # Try to identify the problematic file
    local problem_file=$(extract_problematic_file "$output_file")

    if [[ -n "$problem_file" ]]; then
        local lines=$(wc -l < "$problem_file" 2>/dev/null | tr -d ' ')
        echo -e "${YELLOW}Problematic file identified:${NC} $problem_file ($lines lines)"

        # Log the error
        log_token_error "$problem_file" "$lines" "$current_task"

        # Queue for mandatory refactoring
        queue_mandatory_refactor "$problem_file" "Token limit exceeded ($lines lines)"

        return 0
    else
        echo -e "${YELLOW}Could not identify specific file. Scanning for large files...${NC}"

        # Scan all files and queue the largest ones
        scan_and_queue_largest_files
        return 0
    fi
}

# Log token error for tracking
log_token_error() {
    local file=$1
    local lines=$2
    local task=$3
    local timestamp=$(get_iso_timestamp)

    init_refactor_tracking

    local error_entry="{\"file\": \"$file\", \"lines\": $lines, \"task\": \"$task\", \"timestamp\": \"$timestamp\"}"

    if [[ -f "$TOKEN_ERROR_LOG" ]]; then
        local current=$(cat "$TOKEN_ERROR_LOG")
        echo "$current" | jq ". += [$error_entry]" > "$TOKEN_ERROR_LOG"
    else
        echo "[$error_entry]" > "$TOKEN_ERROR_LOG"
    fi

    # Also update main refactor log
    local log_data=$(cat "$REFACTOR_LOG")
    log_data=$(echo "$log_data" | jq ".token_errors += [\"$file\"]")
    echo "$log_data" > "$REFACTOR_LOG"
}

# Scan and queue largest files for refactoring
scan_and_queue_largest_files() {
    local threshold=${1:-200}  # More aggressive threshold after token error

    echo -e "${CYAN}Scanning for files over $threshold lines...${NC}"

    local large_files=""

    for ext in "${CODE_EXTENSIONS[@]}"; do
        while IFS= read -r file; do
            if [[ -n "$file" ]] && [[ -f "$file" ]]; then
                local lines=$(wc -l < "$file" 2>/dev/null | tr -d ' ')
                if [[ $lines -gt $threshold ]]; then
                    large_files="$large_files$file:$lines\n"
                fi
            fi
        done < <(find . -name "*.$ext" -type f 2>/dev/null | \
                 grep -v node_modules | \
                 grep -v ".next" | \
                 grep -v "dist" | \
                 grep -v ".git" | \
                 grep -v "coverage")
    done

    if [[ -n "$large_files" ]]; then
        echo -e "${YELLOW}Large files found:${NC}"
        echo -e "$large_files" | while read -r line; do
            [[ -n "$line" ]] && echo "  - $line"
        done
        queue_mandatory_refactor "$(echo -e "$large_files")" "Token error prevention"
    fi
}

# =============================================================================
# MANDATORY REFACTORING (for token errors)
# =============================================================================

# Queue mandatory refactoring with detailed instructions
queue_mandatory_refactor() {
    local files=$1
    local reason=$2

    init_refactor_tracking

    local timestamp=$(get_iso_timestamp)

    cat > "$REFACTOR_QUEUE" << 'REFACTOR_EOF'
================================================================================
MANDATORY REFACTORING TASK
================================================================================

REASON: TOKEN LIMIT EXCEEDED
This file is too large for Claude to process in one go.
This MUST be fixed before continuing with other tasks.

PRIORITY: CRITICAL (blocking other tasks)

--------------------------------------------------------------------------------
FILES TO REFACTOR:
--------------------------------------------------------------------------------

REFACTOR_EOF

    echo "$files" >> "$REFACTOR_QUEUE"

    cat >> "$REFACTOR_QUEUE" << 'REFACTOR_EOF'

--------------------------------------------------------------------------------
REFACTORING INSTRUCTIONS:
--------------------------------------------------------------------------------

1. ANALYZE THE FILE STRUCTURE
   - Identify logical sections (types, utils, components, hooks, etc.)
   - Find functions that can be extracted
   - Look for repeated patterns

2. SPLIT INTO MULTIPLE FILES
   Target structure (example for a large component):

   Original: src/components/Dashboard.tsx (500 lines)

   Split into:
   ├── src/components/Dashboard/
   │   ├── index.tsx           (main component, <150 lines)
   │   ├── DashboardHeader.tsx (extracted component)
   │   ├── DashboardContent.tsx (extracted component)
   │   ├── DashboardFooter.tsx (extracted component)
   │   ├── hooks/
   │   │   └── useDashboard.ts (extracted hooks)
   │   ├── types.ts            (extracted types)
   │   └── utils.ts            (extracted utilities)

3. UPDATE ALL IMPORTS
   - Update imports in the refactored files
   - Update imports in ALL files that reference the original
   - Use barrel exports (index.ts) for clean imports

4. MAINTAIN FUNCTIONALITY
   - ALL existing features MUST work after refactoring
   - Run build after each split to catch errors early
   - Run tests if available

5. VERIFICATION CHECKLIST
   - [ ] Each new file is under 300 lines
   - [ ] All imports are updated
   - [ ] Build passes (npm run build)
   - [ ] No TypeScript errors
   - [ ] Original functionality preserved
   - [ ] Tests pass (if applicable)

--------------------------------------------------------------------------------
COMMON PATTERNS TO EXTRACT:
--------------------------------------------------------------------------------

TypeScript/React:
- Types/Interfaces → types.ts
- Hooks → hooks/useXxx.ts
- Utilities → utils.ts
- Constants → constants.ts
- Sub-components → Separate files
- Context → context.tsx

Python:
- Classes → Separate modules
- Utilities → utils.py
- Constants → constants.py
- Types → types.py (if using typing)

--------------------------------------------------------------------------------
AFTER REFACTORING:
--------------------------------------------------------------------------------

Run these commands to verify:

```bash
# TypeScript/JavaScript
npm run build
npm run lint
npm run test  # if available

# Python
python -m py_compile <file>
pytest  # if available
```

================================================================================
REFACTOR_EOF

    echo -e "${RED}[MANDATORY]${NC} Refactoring task queued: $reason"
    echo -e "${YELLOW}This must be completed before continuing with other tasks${NC}"
}

# =============================================================================
# STANDARD REFACTORING (proactive)
# =============================================================================

# Find files exceeding line limit
find_large_files() {
    local max_lines=${1:-$MAX_FILE_LINES}
    local result=""

    for ext in "${CODE_EXTENSIONS[@]}"; do
        local files=$(find . -name "*.$ext" -type f 2>/dev/null | \
                     grep -v node_modules | \
                     grep -v ".next" | \
                     grep -v "dist" | \
                     grep -v ".git" | \
                     grep -v "coverage")

        while IFS= read -r file; do
            if [[ -n "$file" ]] && [[ -f "$file" ]]; then
                local lines=$(wc -l < "$file" 2>/dev/null | tr -d ' ')
                if [[ $lines -gt $max_lines ]]; then
                    result="$result$file:$lines\n"
                fi
            fi
        done <<< "$files"
    done

    echo -e "$result"
}

# Analyze file for refactoring opportunities
analyze_file_complexity() {
    local file=$1

    if [[ ! -f "$file" ]]; then
        return 1
    fi

    local lines=$(wc -l < "$file" | tr -d ' ')
    local functions=0
    local large_functions=0
    local estimated_tokens=$((lines * TOKENS_PER_LINE))

    # Count functions (basic pattern matching)
    case "${file##*.}" in
        ts|tsx|js|jsx)
            functions=$(grep -cE '(function\s+\w+|const\s+\w+\s*=\s*(async\s+)?\(|^\s*(export\s+)?(async\s+)?function)' "$file" 2>/dev/null || echo 0)
            ;;
        py)
            functions=$(grep -cE '^\s*def\s+\w+' "$file" 2>/dev/null || echo 0)
            ;;
        go)
            functions=$(grep -cE '^func\s+' "$file" 2>/dev/null || echo 0)
            ;;
    esac

    # Check if file is at risk for token errors
    local token_risk="low"
    if [[ $estimated_tokens -gt 20000 ]]; then
        token_risk="critical"
    elif [[ $estimated_tokens -gt 15000 ]]; then
        token_risk="high"
    elif [[ $estimated_tokens -gt 10000 ]]; then
        token_risk="medium"
    fi

    echo "{\"file\": \"$file\", \"lines\": $lines, \"functions\": $functions, \"estimated_tokens\": $estimated_tokens, \"token_risk\": \"$token_risk\"}"
}

# Queue files for refactoring (standard, non-blocking)
queue_refactor() {
    local files=$1
    local reason=${2:-"File exceeds $MAX_FILE_LINES lines"}

    if [[ -z "$files" ]]; then
        return 0
    fi

    init_refactor_tracking

    # Add to queue
    local queue_content=""
    if [[ -f "$REFACTOR_QUEUE" ]]; then
        queue_content=$(cat "$REFACTOR_QUEUE")
    fi

    cat >> "$REFACTOR_QUEUE" << EOF

--------------------------------------------------------------------------------
REFACTORING SUGGESTION (non-blocking):
--------------------------------------------------------------------------------
Reason: $reason
Files:
$files

Instructions:
1. Split large files into smaller, focused modules
2. Extract reusable functions into utility files
3. Move types/interfaces to dedicated type files
4. Keep each file under $MAX_FILE_LINES lines
5. Ensure all imports are updated after splitting
6. Run build to verify no breaking changes

EOF

    # Update refactor log
    local timestamp=$(get_iso_timestamp)
    local log_data=$(cat "$REFACTOR_LOG")
    echo "$files" | while read -r file_info; do
        if [[ -n "$file_info" ]]; then
            local filename=$(echo "$file_info" | cut -d: -f1)
            log_data=$(echo "$log_data" | jq ".queued_files += [\"$filename\"]" 2>/dev/null || echo "$log_data")
        fi
    done
    log_data=$(echo "$log_data" | jq ".last_check = \"$timestamp\"" 2>/dev/null || echo "$log_data")
    echo "$log_data" > "$REFACTOR_LOG"

    echo -e "${CYAN}Refactoring suggestion queued${NC}"
}

# Main refactor check function
run_refactor_check() {
    init_refactor_tracking

    echo -e "${CYAN}Checking code quality...${NC}"

    local large_files=$(find_large_files)
    local critical_files=""

    # Check for files at critical token risk
    for ext in "${CODE_EXTENSIONS[@]}"; do
        while IFS= read -r file; do
            if [[ -n "$file" ]] && [[ -f "$file" ]]; then
                local lines=$(wc -l < "$file" 2>/dev/null | tr -d ' ')
                local estimated_tokens=$((lines * TOKENS_PER_LINE))

                if [[ $estimated_tokens -gt 20000 ]]; then
                    critical_files="$critical_files$file:$lines (CRITICAL: ~$estimated_tokens tokens)\n"
                fi
            fi
        done < <(find . -name "*.$ext" -type f 2>/dev/null | \
                 grep -v node_modules | \
                 grep -v ".next" | \
                 grep -v "dist" | \
                 grep -v ".git")
    done

    # Handle critical files first (blocking)
    if [[ -n "$critical_files" ]]; then
        echo -e "${RED}CRITICAL: Files at risk for token limit errors:${NC}"
        echo -e "$critical_files" | while read -r file_info; do
            [[ -n "$file_info" ]] && echo -e "  ${RED}•${NC} $file_info"
        done
        queue_mandatory_refactor "$critical_files" "Token limit risk (>20k estimated tokens)"
        return 2  # Critical refactoring needed
    fi

    # Handle regular large files (non-blocking)
    if [[ -n "$large_files" ]]; then
        echo -e "${YELLOW}Found files exceeding $MAX_FILE_LINES lines:${NC}"
        echo "$large_files" | while read -r file_info; do
            if [[ -n "$file_info" ]]; then
                local file=$(echo "$file_info" | cut -d: -f1)
                local lines=$(echo "$file_info" | cut -d: -f2)
                echo -e "  ${YELLOW}•${NC} $file ($lines lines)"
            fi
        done

        queue_refactor "$large_files"
        return 1  # Standard refactoring needed
    else
        echo -e "${GREEN}All files within limits${NC}"
        return 0  # No refactoring needed
    fi
}

# =============================================================================
# REFACTOR PROMPT GENERATION
# =============================================================================

# Generate refactoring prompt for Claude
generate_refactor_prompt() {
    local file=$1

    if [[ ! -f "$file" ]]; then
        echo "File not found: $file"
        return 1
    fi

    local analysis=$(analyze_file_complexity "$file")
    local lines=$(echo "$analysis" | jq -r '.lines')
    local token_risk=$(echo "$analysis" | jq -r '.token_risk')

    cat << EOF
## Refactoring Task: $file

**Current state:**
- Lines: $lines
- Token risk: $token_risk

**Task:**
Split this file into smaller modules while preserving ALL functionality.

**Requirements:**
1. Each resulting file must be under 300 lines
2. All imports must be updated (in this file AND all files that import from it)
3. Build must pass after refactoring
4. All features must work exactly as before

**Suggested structure:**
- Main file: index.tsx (exports, main logic)
- Types: types.ts (interfaces, types)
- Utils: utils.ts (helper functions)
- Hooks: hooks/ (custom hooks if React)
- Components: Separate files for sub-components

**After refactoring, verify:**
\`\`\`bash
npm run build
npm run lint
\`\`\`
EOF
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Get refactor suggestions for a specific file
get_refactor_suggestions() {
    local file=$1

    if [[ ! -f "$file" ]]; then
        echo "File not found: $file"
        return 1
    fi

    local analysis=$(analyze_file_complexity "$file")
    local lines=$(echo "$analysis" | jq -r '.lines')
    local functions=$(echo "$analysis" | jq -r '.functions')
    local estimated_tokens=$(echo "$analysis" | jq -r '.estimated_tokens')
    local token_risk=$(echo "$analysis" | jq -r '.token_risk')

    echo "Analysis for: $file"
    echo "  Lines: $lines"
    echo "  Functions: $functions"
    echo "  Estimated tokens: $estimated_tokens"
    echo "  Token risk: $token_risk"
    echo ""
    echo "Suggestions:"

    if [[ "$token_risk" == "critical" ]]; then
        echo -e "  ${RED}[CRITICAL]${NC} File will cause token errors - MUST split immediately"
    elif [[ "$token_risk" == "high" ]]; then
        echo -e "  ${YELLOW}[HIGH RISK]${NC} File likely to cause token errors - split recommended"
    fi

    if [[ $lines -gt $MAX_FILE_LINES ]]; then
        echo "  - Split file into smaller modules"
        echo "  - Target: <$MAX_FILE_LINES lines per file"
    fi

    if [[ $functions -gt 10 ]]; then
        echo "  - Consider grouping related functions"
        echo "  - Create separate files for different concerns"
    fi
}

# Check if there's a pending mandatory refactor
has_mandatory_refactor() {
    if [[ -f "$REFACTOR_QUEUE" ]]; then
        if grep -q "MANDATORY REFACTORING TASK" "$REFACTOR_QUEUE" 2>/dev/null; then
            return 0  # Has mandatory refactor
        fi
    fi
    return 1  # No mandatory refactor
}

# Get the mandatory refactor content
get_mandatory_refactor() {
    if [[ -f "$REFACTOR_QUEUE" ]]; then
        cat "$REFACTOR_QUEUE"
    fi
}

# Clear refactor queue (after successful refactoring)
clear_refactor_queue() {
    rm -f "$REFACTOR_QUEUE"
    echo -e "${GREEN}Refactor queue cleared${NC}"
}

# Show refactor history
show_refactor_history() {
    if [[ -f "$REFACTOR_LOG" ]]; then
        cat "$REFACTOR_LOG" | jq .
    else
        echo "No refactor history found"
    fi
}

# Show token error history
show_token_errors() {
    if [[ -f "$TOKEN_ERROR_LOG" ]]; then
        cat "$TOKEN_ERROR_LOG" | jq .
    else
        echo "No token errors logged"
    fi
}

# Export functions
export -f init_refactor_tracking
export -f detect_token_error
export -f extract_problematic_file
export -f handle_token_error
export -f log_token_error
export -f scan_and_queue_largest_files
export -f queue_mandatory_refactor
export -f find_large_files
export -f analyze_file_complexity
export -f queue_refactor
export -f run_refactor_check
export -f generate_refactor_prompt
export -f get_refactor_suggestions
export -f has_mandatory_refactor
export -f get_mandatory_refactor
export -f clear_refactor_queue
export -f show_refactor_history
export -f show_token_errors
