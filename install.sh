#!/usr/bin/env bash
# =============================================================================
# install.sh — Multi-Distro Terminal Environment Bootstrap (Linux / WSL)
# Repository: https://github.com/berndof/dotfiles
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_BIN="$REPO_ROOT/bin/dots"

C_RESET=$'\033[0m'
C_BOLD=$'\033[1m'
C_GREEN=$'\033[38;5;114m'
C_YELLOW=$'\033[38;5;215m'
C_BLUE=$'\033[38;5;111m'
C_MAUVE=$'\033[38;5;183m'

info() { printf "%s[BOOTSTRAP]%s %s\n" "$C_BLUE" "$C_RESET" "$*"; }
ok()   { printf "%s[OK]%s        %s\n" "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf "%s[WARN]%s      %s\n" "$C_YELLOW" "$C_RESET" "$*"; }

usage() {
  cat <<EOF
${C_BOLD}${C_MAUVE}dotfiles/install.sh${C_RESET} — Replicate terminal environment on any Linux/WSL machine

${C_BOLD}USAGE:${C_RESET}
  ./install.sh [flags]

${C_BOLD}FLAGS:${C_RESET}
  --all        Run full setup: packages + cli tools + fonts + apply configs (default if no flags)
  --packages   Install OS packages (zsh, git, curl, unzip, fzf, direnv, micro, btop, eza)
  --cli        Install modern CLI tools (zinit, zoxide, atuin, starship)
  --fonts      Install JetBrainsMono Nerd Font & Noto Color Emoji
  --apply      Link 'dots' CLI into ~/.local/bin and apply tracked configs to ~/
  --shell      Set Zsh as the default OS login shell (chsh)
  -h, --help   Show this help message
EOF
}

install_os_packages() {
  info "Checking and installing OS packages..."
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -qq
    sudo apt-get install -y \
      zsh git curl wget unzip fontconfig \
      fzf direnv micro btop fonts-noto-color-emoji

    # Install eza (via apt on newer Ubuntu/Debian or official gpg repo fallback)
    if ! command -v eza >/dev/null 2>&1; then
      if ! sudo apt-get install -y eza 2>/dev/null; then
        info "Installing eza from official gierens repository..."
        sudo mkdir -p /etc/apt/keyrings
        wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg --yes
        echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null
        sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
        sudo apt-get update -qq && sudo apt-get install -y eza
      fi
    fi
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -Sy --needed --noconfirm \
      zsh git curl wget unzip fontconfig \
      fzf direnv micro btop eza noto-fonts-emoji
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y \
      zsh git curl wget unzip fontconfig \
      fzf direnv micro btop eza google-noto-emoji-color-fonts
  else
    warn "Unsupported package manager. Please install zsh, git, curl, fzf, direnv, micro, btop, eza manually."
  fi
  ok "OS packages ready."
}

install_cli_tools() {
  info "Checking modern CLI tools (Zinit, Zoxide, Atuin, Starship)..."
  mkdir -p "$HOME/.local/bin"

  # 1. Zinit
  local zinit_dir="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
  if [[ ! -d "$zinit_dir" ]]; then
    info "Cloning Zinit plugin manager..."
    mkdir -p "$(dirname "$zinit_dir")"
    git clone --depth 1 https://github.com/zdharma-continuum/zinit.git "$zinit_dir"
    ok "Zinit installed."
  else
    ok "Zinit already installed."
  fi

  # 2. Zoxide
  if ! command -v zoxide >/dev/null 2>&1 && [[ ! -x "$HOME/.local/bin/zoxide" ]]; then
    info "Installing zoxide..."
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
    ok "zoxide installed."
  else
    ok "zoxide already installed."
  fi

  # 3. Atuin
  if ! command -v atuin >/dev/null 2>&1 && [[ ! -x "$HOME/.atuin/bin/atuin" ]]; then
    info "Installing atuin..."
    curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh -s -- --non-interactive || true
    ok "atuin installed."
  else
    ok "atuin already installed."
  fi

  # 4. Starship (optional alternative prompt)
  if ! command -v starship >/dev/null 2>&1; then
    info "Installing starship prompt into ~/.local/bin..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"
    ok "starship installed."
  else
    ok "starship already installed."
  fi
}

install_fonts() {
  info "Checking JetBrainsMono Nerd Font..."
  if command -v fc-list >/dev/null 2>&1; then
    local font_families
    font_families="$(fc-list : family 2>/dev/null || true)"
    if grep -qi "JetBrainsMono Nerd Font" <<< "$font_families"; then
      ok "JetBrainsMono Nerd Font already installed."
      return 0
    fi
  fi

  local font_dir="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
  local tmp_zip
  tmp_zip="$(mktemp /tmp/JetBrainsMono.XXXXXX.zip)"

  info "Downloading JetBrainsMono Nerd Font (latest release)..."
  curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" -o "$tmp_zip"
  mkdir -p "$font_dir"
  unzip -qo "$tmp_zip" -d "$font_dir"
  rm -f "$tmp_zip"

  if command -v fc-cache >/dev/null 2>&1; then
    fc-cache -f "$font_dir"
  fi
  ok "JetBrainsMono Nerd Font installed at $font_dir"
}

apply_configs() {
  info "Linking 'dots' CLI to ~/.local/bin/dots..."
  mkdir -p "$HOME/.local/bin"
  chmod +x "$DOTS_BIN"
  ln -sfn "$DOTS_BIN" "$HOME/.local/bin/dots"
  ok "Linked ~/.local/bin/dots -> $DOTS_BIN"

  info "Applying tracked dotfiles to $HOME..."
  "$DOTS_BIN" apply
}

configure_default_shell() {
  if ! command -v zsh >/dev/null 2>&1; then
    warn "zsh not found, skipping chsh."
    return 0
  fi
  local zsh_path login_shell
  zsh_path="$(command -v zsh)"
  login_shell="$(getent passwd "$USER" | cut -d: -f7)"
  if [[ "$login_shell" != "$zsh_path" ]]; then
    info "Setting default login shell to $zsh_path..."
    chsh -s "$zsh_path" || warn "Could not run chsh non-interactively. Run: chsh -s $zsh_path"
  else
    ok "Default login shell is already $zsh_path"
  fi
}

main() {
  local do_pkg=0 do_cli=0 do_fonts=0 do_apply=0 do_shell=0

  if [[ $# -eq 0 ]]; then
    do_pkg=1 do_cli=1 do_fonts=1 do_apply=1
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --all)      do_pkg=1 do_cli=1 do_fonts=1 do_apply=1; shift ;;
      --packages) do_pkg=1; shift ;;
      --cli)      do_cli=1; shift ;;
      --fonts)    do_fonts=1; shift ;;
      --apply)    do_apply=1; shift ;;
      --shell)    do_shell=1; shift ;;
      -h|--help)  usage; exit 0 ;;
      *)          warn "Unknown option: $1"; usage; exit 1 ;;
    esac
  done

  (( do_pkg == 1 ))   && install_os_packages
  (( do_cli == 1 ))   && install_cli_tools
  (( do_fonts == 1 )) && install_fonts
  (( do_apply == 1 )) && apply_configs
  (( do_shell == 1 )) && configure_default_shell

  printf "\n%s✨ Terminal environment bootstrap complete!%s\n" "$C_GREEN" "$C_RESET"
  printf "Run %sdots status%s or %sdots doctor%s to inspect your setup.\n\n" "$C_BOLD" "$C_RESET" "$C_BOLD" "$C_RESET"
}

main "$@"
