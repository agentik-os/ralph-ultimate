#!/bin/bash

# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║                     RALPH ULTIMATE - AUTOMATIC INSTALLER                       ║
# ║              One-command installation for any system                           ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

# Banner
echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                                               ║${NC}"
echo -e "${CYAN}║   ${BOLD}${PURPLE}██████╗  █████╗ ██╗     ██████╗ ██╗  ██╗${NC}${CYAN}                                    ║${NC}"
echo -e "${CYAN}║   ${PURPLE}██╔══██╗██╔══██╗██║     ██╔══██╗██║  ██║${NC}${CYAN}                                    ║${NC}"
echo -e "${CYAN}║   ${PURPLE}██████╔╝███████║██║     ██████╔╝███████║${NC}${CYAN}                                    ║${NC}"
echo -e "${CYAN}║   ${PURPLE}██╔══██╗██╔══██║██║     ██╔═══╝ ██╔══██║${NC}${CYAN}                                    ║${NC}"
echo -e "${CYAN}║   ${PURPLE}██║  ██║██║  ██║███████╗██║     ██║  ██║${NC}${CYAN}                                    ║${NC}"
echo -e "${CYAN}║   ${PURPLE}╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝  ╚═╝${NC}${CYAN}  ${BOLD}ULTIMATE${NC}${CYAN}                      ║${NC}"
echo -e "${CYAN}║                                                                               ║${NC}"
echo -e "${CYAN}║   ${YELLOW}Autonomous AI Coding Loop for Claude Code${NC}${CYAN}                                  ║${NC}"
echo -e "${CYAN}║   ${BLUE}by AgentikOS${NC}${CYAN}                                                                 ║${NC}"
echo -e "${CYAN}║                                                                               ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Installation directory
RALPH_HOME="${RALPH_HOME:-$HOME/.ralph}"
INSTALL_FROM="${INSTALL_FROM:-github}"  # github or local

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Linux*)     OS="Linux";;
        Darwin*)    OS="macOS";;
        CYGWIN*|MINGW*|MSYS*) OS="Windows";;
        *)          OS="Unknown";;
    esac
    echo -e "${BLUE}Detected OS:${NC} $OS"
}

# Check prerequisites
check_prerequisites() {
    echo -e "\n${BLUE}Checking prerequisites...${NC}"

    local missing=()

    # Check for bash 4+
    if [[ ${BASH_VERSION:0:1} -lt 4 ]]; then
        echo -e "${YELLOW}Warning: Bash 4+ recommended (you have $BASH_VERSION)${NC}"
    fi

    # Check for Claude Code CLI
    if ! command -v claude &> /dev/null; then
        missing+=("claude (Claude Code CLI)")
        echo -e "  ${RED}✗${NC} Claude Code CLI not found"
        echo -e "    ${YELLOW}Install: https://claude.ai/code${NC}"
    else
        echo -e "  ${GREEN}✓${NC} Claude Code CLI found"
    fi

    # Check for Node.js
    if ! command -v node &> /dev/null; then
        missing+=("node")
        echo -e "  ${RED}✗${NC} Node.js not found"
    else
        local node_version=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        if [[ $node_version -lt 18 ]]; then
            echo -e "  ${YELLOW}⚠${NC} Node.js 18+ recommended (you have $(node -v))"
        else
            echo -e "  ${GREEN}✓${NC} Node.js $(node -v) found"
        fi
    fi

    # Check for git
    if ! command -v git &> /dev/null; then
        missing+=("git")
        echo -e "  ${RED}✗${NC} Git not found"
    else
        echo -e "  ${GREEN}✓${NC} Git found"
    fi

    # Check for jq
    if ! command -v jq &> /dev/null; then
        echo -e "  ${YELLOW}⚠${NC} jq not found (optional, will install)"
        INSTALL_JQ=true
    else
        echo -e "  ${GREEN}✓${NC} jq found"
    fi

    # Check for tmux (optional)
    if ! command -v tmux &> /dev/null; then
        echo -e "  ${YELLOW}⚠${NC} tmux not found (optional, for --monitor mode)"
    else
        echo -e "  ${GREEN}✓${NC} tmux found"
    fi

    # Check for curl
    if ! command -v curl &> /dev/null; then
        missing+=("curl")
        echo -e "  ${RED}✗${NC} curl not found"
    else
        echo -e "  ${GREEN}✓${NC} curl found"
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo ""
        echo -e "${RED}Missing required dependencies:${NC}"
        for dep in "${missing[@]}"; do
            echo -e "  - $dep"
        done
        echo ""
        echo -e "${YELLOW}Please install missing dependencies and run installer again.${NC}"

        if [[ " ${missing[*]} " =~ " claude " ]]; then
            echo ""
            echo -e "${BLUE}To install Claude Code CLI:${NC}"
            echo "  Visit: https://claude.ai/code"
            echo "  Or run: npm install -g @anthropic-ai/claude-code"
        fi

        exit 1
    fi
}

# Install jq if needed
install_jq() {
    if [[ "$INSTALL_JQ" == "true" ]]; then
        echo -e "\n${BLUE}Installing jq...${NC}"
        case "$OS" in
            Linux)
                if command -v apt-get &> /dev/null; then
                    sudo apt-get update && sudo apt-get install -y jq
                elif command -v yum &> /dev/null; then
                    sudo yum install -y jq
                elif command -v pacman &> /dev/null; then
                    sudo pacman -S jq
                else
                    echo -e "${YELLOW}Please install jq manually${NC}"
                fi
                ;;
            macOS)
                if command -v brew &> /dev/null; then
                    brew install jq
                else
                    echo -e "${YELLOW}Install Homebrew first: https://brew.sh${NC}"
                fi
                ;;
        esac
    fi
}

# Download or copy Ralph Ultimate
install_ralph() {
    echo -e "\n${BLUE}Installing Ralph Ultimate...${NC}"

    # Remove existing installation
    if [[ -d "$RALPH_HOME" ]]; then
        echo -e "  ${YELLOW}Removing existing installation...${NC}"
        rm -rf "$RALPH_HOME"
    fi

    # Clone from GitHub or copy from local
    if [[ "$INSTALL_FROM" == "github" ]]; then
        echo -e "  ${BLUE}Cloning from GitHub...${NC}"
        git clone --depth 1 https://github.com/agentik-os/ralph-ultimate.git "$RALPH_HOME"
    else
        echo -e "  ${BLUE}Copying from local source...${NC}"
        cp -r "$(dirname "${BASH_SOURCE[0]}")" "$RALPH_HOME"
    fi

    # Make scripts executable
    echo -e "  ${BLUE}Setting permissions...${NC}"
    chmod +x "$RALPH_HOME"/*.sh
    chmod +x "$RALPH_HOME"/lib/*.sh 2>/dev/null || true

    echo -e "  ${GREEN}✓${NC} Ralph Ultimate installed to $RALPH_HOME"
}

# Create symlinks
create_symlinks() {
    echo -e "\n${BLUE}Creating command symlinks...${NC}"

    local bin_dir="/usr/local/bin"
    local use_sudo=false

    # Check if we need sudo
    if [[ ! -w "$bin_dir" ]]; then
        use_sudo=true
        echo -e "  ${YELLOW}Need sudo to create symlinks in $bin_dir${NC}"
    fi

    local commands=(
        "ralph.sh:ralph"
        "ralph-setup.sh:ralph-setup"
        "ralph-monitor.sh:ralph-monitor"
        "ralph-init.sh:ralph-init"
        "ralph-import.sh:ralph-import"
    )

    for cmd in "${commands[@]}"; do
        local src="${cmd%%:*}"
        local dst="${cmd##*:}"

        if [[ "$use_sudo" == "true" ]]; then
            sudo ln -sf "$RALPH_HOME/$src" "$bin_dir/$dst"
        else
            ln -sf "$RALPH_HOME/$src" "$bin_dir/$dst"
        fi
        echo -e "  ${GREEN}✓${NC} Created: $dst"
    done
}

# Setup shell configuration
setup_shell() {
    echo -e "\n${BLUE}Configuring shell...${NC}"

    local shell_rc=""
    local shell_name=""

    # Detect shell
    if [[ -n "$ZSH_VERSION" ]] || [[ "$SHELL" == *"zsh"* ]]; then
        shell_rc="$HOME/.zshrc"
        shell_name="zsh"
    elif [[ -n "$BASH_VERSION" ]]; then
        shell_rc="$HOME/.bashrc"
        shell_name="bash"
    fi

    if [[ -n "$shell_rc" ]]; then
        # Add PATH if not already there
        local path_line="export PATH=\"\$HOME/.ralph:\$PATH\""
        local ralph_home_line="export RALPH_HOME=\"\$HOME/.ralph\""

        if ! grep -q "RALPH_HOME" "$shell_rc" 2>/dev/null; then
            echo "" >> "$shell_rc"
            echo "# Ralph Ultimate - Autonomous AI Coding" >> "$shell_rc"
            echo "$ralph_home_line" >> "$shell_rc"
            echo "$path_line" >> "$shell_rc"
            echo -e "  ${GREEN}✓${NC} Added to $shell_rc"
        else
            echo -e "  ${YELLOW}⚠${NC} Already configured in $shell_rc"
        fi

        echo -e "  ${BLUE}Run:${NC} source $shell_rc"
    fi
}

# Install Playwright (optional)
install_playwright() {
    echo -e "\n${BLUE}Playwright (optional - for visual verification)${NC}"

    if command -v npx &> /dev/null; then
        read -p "Install Playwright for screenshot verification? [y/N]: " install_pw
        if [[ "$install_pw" =~ ^[Yy] ]]; then
            echo -e "  ${BLUE}Installing Playwright...${NC}"
            npx playwright install chromium
            echo -e "  ${GREEN}✓${NC} Playwright installed"
        else
            echo -e "  ${YELLOW}Skipped${NC} (can install later: npx playwright install chromium)"
        fi
    else
        echo -e "  ${YELLOW}Skipped${NC} (npx not available)"
    fi
}

# Show completion message
show_completion() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                     INSTALLATION COMPLETE!                                    ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BOLD}Quick Start:${NC}"
    echo ""
    echo -e "  ${CYAN}1. Initialize a project:${NC}"
    echo "     cd /your/project"
    echo "     ralph-setup"
    echo ""
    echo -e "  ${CYAN}2. Edit your tasks:${NC}"
    echo "     Edit @fix_plan.md with your actual tasks"
    echo ""
    echo -e "  ${CYAN}3. Start Ralph:${NC}"
    echo "     ralph --monitor"
    echo ""
    echo -e "${BOLD}Commands:${NC}"
    echo ""
    echo "  ralph              Start autonomous loop"
    echo "  ralph --monitor    Start with tmux dashboard"
    echo "  ralph --status     Show current status"
    echo "  ralph-setup        Initialize project"
    echo "  ralph-init         Quick project init"
    echo ""
    echo -e "${BOLD}Documentation:${NC}"
    echo ""
    echo "  GitHub: https://github.com/agentik-os/ralph-ultimate"
    echo "  Help:   ralph --help"
    echo ""
    echo -e "${YELLOW}NOTE: Open a new terminal or run 'source ~/.bashrc' to use ralph commands${NC}"
    echo ""
}

# Main installation flow
main() {
    detect_os
    check_prerequisites
    install_jq
    install_ralph
    create_symlinks
    setup_shell
    install_playwright
    show_completion
}

# Run main
main
