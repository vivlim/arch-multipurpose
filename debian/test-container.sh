#!/bin/bash
# test script to verify the debian container starts correctly with all expected tools
# usage: ./test-container.sh [image-name] [--full]
#
# example:
#   ./test-container.sh debian-dev
#   ./test-container.sh debian-full --full

set -e

IMAGE="${1:-debian-dev}"
FULL_TEST=false
if [[ "$2" == "--full" ]] || [[ "$IMAGE" == *"full"* ]]; then
    FULL_TEST=true
fi

# colors
GREEN='\033[1;32m'
RED='\033[1;31m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}testing container image: $IMAGE${NC}"
if [ "$FULL_TEST" = true ]; then
    echo -e "${BOLD}running full variant tests${NC}"
fi

echo ""
echo -e "${BOLD}starting container with --init-only${NC}"
ERRLOG=$(mktemp)
if ! podman run --rm "$IMAGE" /launch.sh --init-only 2>"$ERRLOG"; then
    echo -e "${RED}init failed:${NC}"
    cat "$ERRLOG"
    rm -f "$ERRLOG"
    exit 1
fi
rm -f "$ERRLOG"

echo ""
echo -e "${BOLD}verifying installed tools${NC}"

# run tool checks non-interactively
podman run --rm "$IMAGE" bash -c '
set -e

GREEN="\033[1;32m"
RED="\033[1;31m"
NC="\033[0m"

check_tool() {
    local errlog=$(mktemp)
    if command -v "$1" >"$errlog" 2>&1; then
        echo -e "${GREEN}ok${NC} $1"
        rm -f "$errlog"
    else
        echo -e "${RED}missing${NC} $1"
        if [ -s "$errlog" ]; then
            echo "  error output:"
            cat "$errlog" | sed "s/^/  /"
        fi
        rm -f "$errlog"
        exit 1
    fi
}

check_tool zellij
check_tool hx
check_tool yazi
check_tool starship
check_tool rg
check_tool fd
check_tool uv
check_tool node
check_tool npm
check_tool npx
check_tool tailscale
check_tool direnv
check_tool just

# check nix
echo ""
echo "checking nix..."
errlog=$(mktemp)
if source ~/.nix-profile/etc/profile.d/nix.sh 2>"$errlog" && command -v nix &>/dev/null; then
    echo -e "${GREEN}ok${NC} nix"
else
    echo -e "${RED}missing${NC} nix"
    if [ -s "$errlog" ]; then
        echo "  error output:"
        cat "$errlog" | sed "s/^/  /"
    fi
fi
rm -f "$errlog"

# check dotfiles
echo ""
echo "checking dotfiles..."
[ -f ~/.config/starship.toml ] && echo -e "${GREEN}ok${NC} starship.toml" || echo -e "${RED}missing${NC} starship.toml"
[ -f ~/.config/zellij/config.kdl ] && echo -e "${GREEN}ok${NC} zellij/config.kdl" || echo -e "${RED}missing${NC} zellij/config.kdl"
[ -f ~/.config/helix/config.toml ] && echo -e "${GREEN}ok${NC} helix/config.toml" || echo -e "${RED}missing${NC} helix/config.toml"
[ -f ~/.config/yazi/yazi.toml ] && echo -e "${GREEN}ok${NC} yazi/yazi.toml" || echo -e "${RED}missing${NC} yazi/yazi.toml"
[ -f ~/.bashrc ] && echo -e "${GREEN}ok${NC} .bashrc" || echo -e "${RED}missing${NC} .bashrc"

echo ""
echo "base checks passed"
'

# full variant tests
if [ "$FULL_TEST" = true ]; then
    echo ""
    echo -e "${BOLD}testing full variant (k8s tools + language servers)${NC}"
    podman run --rm "$IMAGE" bash -c '
set -e

GREEN="\033[1;32m"
RED="\033[1;31m"
NC="\033[0m"

check_tool() {
    local errlog=$(mktemp)
    if command -v "$1" >"$errlog" 2>&1; then
        echo -e "${GREEN}ok${NC} $1"
        rm -f "$errlog"
    else
        echo -e "${RED}missing${NC} $1"
        if [ -s "$errlog" ]; then
            echo "  error output:"
            cat "$errlog" | sed "s/^/  /"
        fi
        rm -f "$errlog"
        exit 1
    fi
}

echo "checking kubernetes tools..."
check_tool kubectl
check_tool talosctl
check_tool cilium
check_tool kubectl-cnpg

echo ""
echo "checking python lsps..."
export PATH="$HOME/.local/bin:$PATH"
errlog=$(mktemp)
if command -v pyright-langserver >"$errlog" 2>&1; then
    echo -e "${GREEN}ok${NC} pyright-langserver"
else
    echo -e "${RED}missing${NC} pyright-langserver"
    [ -s "$errlog" ] && cat "$errlog" | sed "s/^/  /"
fi
rm -f "$errlog"

errlog=$(mktemp)
if command -v ruff >"$errlog" 2>&1; then
    echo -e "${GREEN}ok${NC} ruff"
else
    echo -e "${RED}missing${NC} ruff"
    [ -s "$errlog" ] && cat "$errlog" | sed "s/^/  /"
fi
rm -f "$errlog"

echo ""
echo "checking typescript lsp..."
check_tool typescript-language-server

# check helix languages.toml exists
[ -f ~/.config/helix/languages.toml ] && echo -e "${GREEN}ok${NC} helix/languages.toml" || echo -e "${RED}missing${NC} helix/languages.toml"

echo ""
echo "full variant checks passed"
'
fi

echo ""
echo -e "${GREEN}container test successful${NC}"
