#!/bin/bash

# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║                           RALPH-INIT                                           ║
# ║         Initialize a project for Ralph Ultimate autonomous coding              ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

PROJECT_DIR="${1:-.}"

if [[ ! -d "$PROJECT_DIR" ]]; then
    echo -e "${RED}Error: Directory $PROJECT_DIR does not exist${NC}"
    exit 1
fi

cd "$PROJECT_DIR"
PROJECT_NAME=$(basename "$(pwd)")

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║              RALPH-INIT - Project Setup                    ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Project: $PROJECT_NAME${NC}"
echo -e "${BLUE}Path: $(pwd)${NC}"
echo ""

# Check what already exists
EXISTING=""
[[ -f "prd.json" ]] && EXISTING="$EXISTING prd.json"
[[ -f "@fix_plan.md" ]] && EXISTING="$EXISTING @fix_plan.md"
[[ -f ".claude/step.json" ]] && EXISTING="$EXISTING .claude/step.json"
[[ -f "PROMPT.md" ]] && EXISTING="$EXISTING PROMPT.md"

if [[ -n "$EXISTING" ]]; then
    echo -e "${YELLOW}Found existing files:$EXISTING${NC}"
    echo -e "${YELLOW}Project may already be initialized.${NC}"
    echo ""
    read -p "Continue anyway? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy] ]]; then
        echo "Aborted."
        exit 0
    fi
fi

# Ask for format preference
echo ""
echo "Choose task file format:"
echo "  1) @fix_plan.md  - Simple markdown checklist (recommended)"
echo "  2) prd.json      - Structured user stories"
echo "  3) step.json     - Claude Code project format"
echo ""
read -p "Format [1]: " format_choice
format_choice=${format_choice:-1}

case $format_choice in
    1)
        # Create @fix_plan.md
        cat > @fix_plan.md << 'TASKFILE'
## Project Tasks

- [ ] Task 1: Description here
- [ ] Task 2: Description here
- [ ] Task 3: Description here

## Validation
- [ ] Build passes
- [ ] No TypeScript errors
TASKFILE

        # Create PROMPT.md
        cat > PROMPT.md << 'PROMPTFILE'
Complete the tasks in @fix_plan.md one at a time.

For each task:
1. Implement the change
2. Verify it works (build, test if applicable)
3. Mark the task as done: change `- [ ]` to `- [x]`
4. Move to the next task

When all tasks are complete, say "ALL TASKS COMPLETE".
PROMPTFILE

        echo -e "${GREEN}✓ Created @fix_plan.md${NC}"
        echo -e "${GREEN}✓ Created PROMPT.md${NC}"
        ;;

    2)
        # Create prd.json
        cat > prd.json << 'PRDFILE'
{
  "project": "PROJECT_NAME",
  "description": "Project description here",
  "userStories": [
    {
      "id": "US-001",
      "title": "First Task",
      "description": "As a user, I want X so that Y",
      "acceptanceCriteria": [
        "Criterion 1",
        "Criterion 2",
        "Build passes"
      ],
      "priority": 1,
      "passes": false
    },
    {
      "id": "US-002",
      "title": "Second Task",
      "description": "As a user, I want X so that Y",
      "acceptanceCriteria": [
        "Criterion 1",
        "Build passes"
      ],
      "priority": 2,
      "passes": false
    }
  ]
}
PRDFILE
        sed -i "s/PROJECT_NAME/$PROJECT_NAME/g" prd.json

        echo -e "${GREEN}✓ Created prd.json${NC}"
        ;;

    3)
        # Create .claude/step.json
        mkdir -p .claude
        cat > .claude/step.json << 'STEPFILE'
{
  "project": "PROJECT_NAME",
  "currentPhase": "development",
  "lastUpdated": "DATE",
  "steps": [
    {
      "id": 1,
      "name": "Step 1",
      "status": "pending",
      "progress": 0,
      "tasks": [
        {"name": "Task 1", "done": false},
        {"name": "Task 2", "done": false}
      ]
    },
    {
      "id": 2,
      "name": "Step 2",
      "status": "pending",
      "progress": 0,
      "tasks": [
        {"name": "Task 1", "done": false}
      ]
    }
  ]
}
STEPFILE
        sed -i "s/PROJECT_NAME/$PROJECT_NAME/g" .claude/step.json
        sed -i "s/DATE/$(date +%Y-%m-%d)/g" .claude/step.json

        echo -e "${GREEN}✓ Created .claude/step.json${NC}"
        ;;
esac

# Create .claude directory structure if not exists
mkdir -p .claude/checkpoints
mkdir -p .claude/rules

echo -e "${GREEN}✓ Created .claude/ directory structure${NC}"

# Create progress.txt for logging
cat > progress.txt << 'PROGRESSFILE'
# Ralph Progress Log

## Session Started
Date: DATE

## Progress
(Ralph will log progress here)
PROGRESSFILE
sed -i "s/DATE/$(date)/g" progress.txt

echo -e "${GREEN}✓ Created progress.txt${NC}"

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              PROJECT INITIALIZED!                          ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Edit your task file with actual tasks"
echo "  2. Run: ralph-ultimate"
echo ""
echo -e "${YELLOW}Tip: Keep tasks atomic (completable in 1 iteration)${NC}"
