#!/bin/bash

# Ralph Project Setup Script - Interactive Edition
# Creates a Ralph-managed project with guided setup

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Resolve script location (handle symlinks)
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_PATH" ]]; do
    SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    [[ $SCRIPT_PATH != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
RALPH_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
TEMPLATES_DIR="$RALPH_DIR/templates"

# Default stack (Gareth's preferences)
DEFAULT_WEB_STACK="Next.js 16, Convex, Clerk, Stripe, shadcn/ui, Tailwind CSS, Vercel"
DEFAULT_MOBILE_STACK="Expo, React Native, Convex, Clerk"

# Help
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo -e "${CYAN}Ralph Project Setup - Interactive Edition${NC}"
    echo ""
    echo "Usage: ralph-setup [project-name]"
    echo ""
    echo "Creates a new Ralph-managed project with interactive setup."
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help"
    echo "  --quick        Skip interactive mode, use defaults"
    echo ""
    echo "Examples:"
    echo "  ralph-setup                    # Interactive mode"
    echo "  ralph-setup my-feature         # With name, still asks type"
    echo "  ralph-setup my-feature --quick # Quick setup with defaults"
    exit 0
fi

# Quick mode flag
QUICK_MODE=false
if [[ "$2" == "--quick" || "$1" == "--quick" ]]; then
    QUICK_MODE=true
fi

PROJECT_NAME="$1"
[[ "$PROJECT_NAME" == "--quick" ]] && PROJECT_NAME=""

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              🤖 RALPH PROJECT SETUP                          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Get project name if not provided
if [[ -z "$PROJECT_NAME" ]]; then
    echo -e "${YELLOW}Nom du projet:${NC}"
    read -p "> " PROJECT_NAME
    if [[ -z "$PROJECT_NAME" ]]; then
        echo -e "${RED}❌ Nom de projet requis${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}📁 Projet: ${NC}$PROJECT_NAME"
echo ""

# Project type selection
if [[ "$QUICK_MODE" == "false" ]]; then
    echo -e "${YELLOW}Quel type de projet ?${NC}"
    echo ""
    echo "  1) 🌐 Site Web / SaaS (Next.js)"
    echo "  2) 📱 Application Mobile (Expo)"
    echo "  3) 🔌 Extension Chrome/Browser"
    echo "  4) 🖥️  CLI / Script"
    echo "  5) 📦 Autre"
    echo ""
    read -p "Choix [1-5]: " PROJECT_TYPE_CHOICE
else
    PROJECT_TYPE_CHOICE="1"
fi

case "$PROJECT_TYPE_CHOICE" in
    1)
        PROJECT_TYPE="web"
        PROJECT_TYPE_NAME="Site Web / SaaS"
        DEFAULT_STACK="$DEFAULT_WEB_STACK"
        ;;
    2)
        PROJECT_TYPE="mobile"
        PROJECT_TYPE_NAME="Application Mobile"
        DEFAULT_STACK="$DEFAULT_MOBILE_STACK"
        ;;
    3)
        PROJECT_TYPE="extension"
        PROJECT_TYPE_NAME="Extension Browser"
        DEFAULT_STACK="TypeScript, Chrome Extension API"
        ;;
    4)
        PROJECT_TYPE="cli"
        PROJECT_TYPE_NAME="CLI / Script"
        DEFAULT_STACK="Node.js ou Bash"
        ;;
    5)
        PROJECT_TYPE="other"
        PROJECT_TYPE_NAME="Autre"
        DEFAULT_STACK=""
        ;;
    *)
        PROJECT_TYPE="web"
        PROJECT_TYPE_NAME="Site Web / SaaS"
        DEFAULT_STACK="$DEFAULT_WEB_STACK"
        ;;
esac

echo ""
echo -e "${GREEN}📦 Type: ${NC}$PROJECT_TYPE_NAME"

# Stack customization
if [[ "$QUICK_MODE" == "false" && -n "$DEFAULT_STACK" ]]; then
    echo ""
    echo -e "${YELLOW}Stack technique ?${NC}"
    echo -e "  Par défaut: ${CYAN}$DEFAULT_STACK${NC}"
    echo ""
    read -p "Appuyer sur Entrée pour garder le défaut, ou entrer une stack custom: " CUSTOM_STACK
    if [[ -n "$CUSTOM_STACK" ]]; then
        STACK="$CUSTOM_STACK"
    else
        STACK="$DEFAULT_STACK"
    fi
else
    STACK="$DEFAULT_STACK"
fi

echo -e "${GREEN}🛠️  Stack: ${NC}$STACK"

# Build commands based on project type
case "$PROJECT_TYPE" in
    web)
        BUILD_CMD="npm run build"
        DEV_CMD="npm run dev"
        TEST_CMD="npm run test"
        ;;
    mobile)
        BUILD_CMD="npx expo export"
        DEV_CMD="npx expo start --tunnel --dev-client"
        TEST_CMD="npm run test"
        ;;
    extension)
        BUILD_CMD="npm run build"
        DEV_CMD="npm run dev"
        TEST_CMD="npm run test"
        ;;
    cli)
        BUILD_CMD="# No build needed"
        DEV_CMD="node index.js"
        TEST_CMD="npm run test"
        ;;
    *)
        BUILD_CMD="npm run build"
        DEV_CMD="npm run dev"
        TEST_CMD="npm run test"
        ;;
esac

# Create project directory
echo ""
echo -e "${BLUE}📁 Création du projet...${NC}"
mkdir -p "$PROJECT_NAME"
cd "$PROJECT_NAME"

# Create structure
mkdir -p {src,logs,docs/generated}

# Create PROMPT.md
cat > PROMPT.md << EOF
# $PROJECT_NAME

## Type de projet
$PROJECT_TYPE_NAME

## Stack technique
$STACK

## Objectif
[Décrire l'objectif principal du projet]

## Contexte
[Décrire le contexte et les contraintes]

## Instructions pour Ralph
1. Lis @fix_plan.md pour la liste des tâches
2. Travaille tâche par tâche, une à la fois
3. Après chaque modification: \`$BUILD_CMD\`
4. Marque les tâches [x] quand terminées
5. Commit après chaque tâche complétée

## Commandes
- Build: \`$BUILD_CMD\`
- Dev: \`$DEV_CMD\`
- Test: \`$TEST_CMD\`

## Quality Gates
- Build doit passer sans erreur
- Pas d'erreurs TypeScript
- Code propre et documenté
- Tests si applicable
EOF

# Create @fix_plan.md
cat > @fix_plan.md << 'EOF'
# Fix Plan - Task List

## 🎯 Objectif
[Décrire l'objectif de cette session]

## 📋 Tâches prioritaires
- [ ] Tâche 1: Description détaillée
- [ ] Tâche 2: Description détaillée
- [ ] Tâche 3: Description détaillée

## ✅ Complétées
(Les tâches terminées seront déplacées ici)

## 📝 Notes
(Notes additionnelles si nécessaire)
EOF

# Create @AGENT.md
cat > @AGENT.md << EOF
# Build & Run Instructions

## Build
\`\`\`bash
$BUILD_CMD
\`\`\`

## Development
\`\`\`bash
$DEV_CMD
\`\`\`

## Test
\`\`\`bash
$TEST_CMD
\`\`\`

## Vérification
Après chaque modification:
1. Build: \`$BUILD_CMD\`
2. Vérifier pas d'erreurs dans la console
3. Si UI: vérifier visuellement (screenshot si possible)
EOF

# Initialize git if not already
if [[ ! -d .git ]]; then
    git init -q 2>/dev/null || true
    echo "# $PROJECT_NAME" > README.md
    git add . 2>/dev/null || true
    git commit -q -m "Initial Ralph project setup" 2>/dev/null || true
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              ✅ PROJET CRÉÉ AVEC SUCCÈS                      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Projet:${NC} $PROJECT_NAME"
echo -e "${CYAN}Type:${NC}   $PROJECT_TYPE_NAME"
echo -e "${CYAN}Stack:${NC}  $STACK"
echo ""
echo -e "${YELLOW}Fichiers créés:${NC}"
echo "  📄 PROMPT.md     - Instructions pour Ralph"
echo "  📄 @fix_plan.md  - Liste des tâches"
echo "  📄 @AGENT.md     - Commandes build/run"
echo ""
echo -e "${YELLOW}Prochaines étapes:${NC}"
echo "  1. cd $PROJECT_NAME"
echo "  2. Édite PROMPT.md avec ton objectif"
echo "  3. Édite @fix_plan.md avec tes tâches"
echo "  4. Lance: ralph --monitor"
echo ""
echo -e "${CYAN}💡 Tip: Ralph peut aussi gérer les bugs et le code sensible!${NC}"
echo -e "${CYAN}   Il utilisera Playwright pour vérifier visuellement si disponible.${NC}"
