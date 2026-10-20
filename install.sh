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
  --packages   Install OS packages (zsh, git, curl, unzip, fzf, direnv, micro, btop, eza, rg, fd, bat, delta, duf, ncdu)
  --cli        Install modern CLI tools in ~/.local/bin (zinit, zoxide, atuin, starship, rg, fd, bat, delta, duf, ncdu)
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
      fzf direnv micro btop ripgrep fd-find bat duf ncdu fonts-noto-color-emoji

    # git-delta on Ubuntu 24.04+ / Debian 13+
    sudo apt-get install -y git-delta 2>/dev/null || true

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

    # Normalize Debian/Ubuntu binary names (fdfind -> fd, batcat -> bat)
    mkdir -p "$HOME/.local/bin"
    command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1 && ln -sfn "$(command -v fdfind)" "$HOME/.local/bin/fd"
    command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1 && ln -sfn "$(command -v batcat)" "$HOME/.local/bin/bat"
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -Sy --needed --noconfirm \
      zsh git curl wget unzip fontconfig \
      fzf direnv micro btop eza ripgrep fd bat git-delta duf ncdu noto-fonts-emoji
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y \
      zsh git curl wget unzip fontconfig \
      fzf direnv micro btop eza ripgrep fd-find bat git-delta duf ncdu google-noto-emoji-color-fonts
  else
    warn "Unsupported package manager. Falling back to user-space binary installation (--cli)."
  fi

  # fastfetch: nem todo distro o empacota na versao atual, entao e best-effort
  # e nunca deve derrubar o bootstrap (o alias 'ff' simplesmente fica inerte).
  if ! command -v fastfetch >/dev/null 2>&1; then
    info "Installing fastfetch..."
    if command -v apt-get >/dev/null 2>&1; then
      sudo apt-get install -y fastfetch 2>/dev/null || true
    elif command -v pacman >/dev/null 2>&1; then
      sudo pacman -S --needed --noconfirm fastfetch 2>/dev/null || true
    elif command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y fastfetch 2>/dev/null || true
    fi
  fi
  command -v fastfetch >/dev/null 2>&1 && ok "fastfetch ready." || warn "fastfetch unavailable (alias 'ff' will be inert)."

  ok "OS packages ready."
}

# Helper to install a prebuilt GitHub release tarball into ~/.local/bin (zero sudo required)
install_github_binary() {
  local bin_name="$1"
  local repo="$2"
  local asset_regex="$3"
  local inner_bin="${4:-$bin_name}"

  if command -v "$bin_name" >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/$bin_name" ]]; then
    ok "$bin_name already installed."
    return 0
  fi

  info "Installing $bin_name from github.com/$repo..."
  local tmp_dir
  tmp_dir="$(mktemp -d /tmp/dots-bin.XXXXXX)"
  local download_url=""

  download_url="$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
    | grep -oE "https://github.com/${repo}/releases/download/[^\"]*${asset_regex}" \
    | head -n1 || true)"

  if [[ -z "$download_url" ]]; then
    warn "Could not resolve release URL for $bin_name ($repo)."
    rm -rf "$tmp_dir"
    return 1
  fi

  local archive="$tmp_dir/archive"
  curl -fsSL "$download_url" -o "$archive"

  if [[ "$download_url" == *.tar.gz || "$download_url" == *.tgz ]]; then
    tar -xzf "$archive" -C "$tmp_dir"
  elif [[ "$download_url" == *.zip ]]; then
    unzip -qo "$archive" -d "$tmp_dir"
  fi

  local found_bin
  found_bin="$(find "$tmp_dir" -type f -name "$inner_bin" | head -n1 || true)"
  if [[ -n "$found_bin" ]]; then
    install -m 0755 "$found_bin" "$HOME/.local/bin/$bin_name"
    ok "$bin_name installed to ~/.local/bin/$bin_name"
  else
    warn "Binary '$inner_bin' not found inside archive for $bin_name"
  fi
  rm -rf "$tmp_dir"
}

install_cli_tools() {
  info "Checking modern CLI tools (Zinit, Zoxide, Atuin, Starship & Modern Unix Kit)..."
  mkdir -p "$HOME/.local/bin"
  export PATH="$HOME/.local/bin:$PATH"

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

  # 4. Starship (alternative prompt)
  if ! command -v starship >/dev/null 2>&1; then
    info "Installing starship prompt into ~/.local/bin..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"
    ok "starship installed."
  else
    ok "starship already installed."
  fi

  # 5. Modern Unix Kit (x86_64 Linux static binaries into ~/.local/bin if not installed via OS)
  if [[ "$(uname -s)" == "Linux" && "$(uname -m)" == "x86_64" ]]; then
    # Normalize Debian/Ubuntu names first if present
    command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1 && ln -sfn "$(command -v fdfind)" "$HOME/.local/bin/fd"
    command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1 && ln -sfn "$(command -v batcat)" "$HOME/.local/bin/bat"

    install_github_binary "rg"    "BurntSushi/ripgrep"   "x86_64-unknown-linux-musl\.tar\.gz" "rg"
    install_github_binary "fd"    "sharkdp/fd"           "x86_64-unknown-linux-musl\.tar\.gz" "fd"
    install_github_binary "bat"   "sharkdp/bat"          "x86_64-unknown-linux-musl\.tar\.gz" "bat"
    install_github_binary "delta" "dandavison/delta"     "x86_64-unknown-linux-musl\.tar\.gz" "delta"
    install_github_binary "duf"   "muesli/duf"           "linux_x86_64\.tar\.gz"              "duf"
    install_github_binary "ncdu"  "rofl0r/ncdu"          "linux-x86_64-musl\.tar\.gz"         "ncdu" || true
  fi
}

# Pré-instala os plugins do Zinit que o ~/.zshrc carrega.
#
# Sem isso, o primeiro login (tipicamente via SSH, em uma máquina nova)
# dispara 'zinit light romkatv/powerlevel10k' durante a inicialização do
# shell: o zinit baixa o plugin, imprime "Downloading ..." no console e o
# Powerlevel10k aborta com o bloco de warning 'Console output during zsh
# initialization detected'. Resultado: o prompt aparece "fora do estilo"
# justamente na primeira sessão. Pré-instalar elimina esse ruído.
install_zinit_plugins() {
  info "Pre-installing Zinit plugins (Powerlevel10k & helpers)..."
  local zinit_dir="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
  local plugins_dir="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/plugins"

  if [[ ! -d "$zinit_dir" ]]; then
    warn "Zinit not found at $zinit_dir -- run './install.sh --cli' first."
    return 0
  fi
  mkdir -p "$plugins_dir"

  # repo -> diretorio no formato do zinit (owner---repo)
  local entry
  for entry in "romkatv/powerlevel10k:romkatv---powerlevel10k" \
               "zdharma-continuum/null:zdharma-continuum---null"; do
    local repo="${entry%%:*}"
    local dest="${entry##*:}"
    local target="$plugins_dir/$dest"

    if [[ -d "$target" ]]; then
      ok "$dest already installed."
      continue
    fi

    info "Cloning $repo..."
    if git clone --depth 1 "https://github.com/$repo.git" "$target" >/dev/null 2>&1; then
      ok "$dest installed."
    else
      # best-effort: sem rede o zinit tenta de novo no proximo shell
      warn "Could not clone $repo (no network?) -- zinit will retry on first shell."
      rm -rf "$target" 2>/dev/null || true
    fi
  done
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

  # Sempre por ultimo: precisa do Zinit instalado (--cli) e do ~/.zshrc
  # aplicado (--apply) para ter efeito. Rodar mesmo sem esses flags e
  # inofensivo -- a funcao apenas avisa e nao aborta.
  install_zinit_plugins

  printf "\n%s✨ Terminal environment bootstrap complete!%s\n" "$C_GREEN" "$C_RESET"
  printf "Run %sdots status%s or %sdots doctor%s to inspect your setup.\n\n" "$C_BOLD" "$C_RESET" "$C_BOLD" "$C_RESET"
}

main "$@"
