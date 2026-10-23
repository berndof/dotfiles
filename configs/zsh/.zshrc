# =============================================================================
# ~/.zshrc — Configuração do ZSH (Bernardo)
# Otimizado com Zinit Turbo, Powerlevel10k, Tema Solarized Dark, FZF-Tab Preview
# e Kit Modern Unix (eza, bat, fd, rg, delta, zoxide, atuin, sbx)
# =============================================================================

# -----------------------------------------------------------------------------
# 1. Powerlevel10k Instant Prompt (DEVE ficar no topo do arquivo)
# -----------------------------------------------------------------------------
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# -----------------------------------------------------------------------------
# 2. Otimização de PATH e Variáveis Globais (Zero Subshell Forks)
# -----------------------------------------------------------------------------
export PNPM_HOME="$HOME/.local/share/pnpm"
export NVM_DIR="$HOME/.nvm"
export EDITOR="micro"
export VISUAL="micro"

typeset -U path fpath

[[ -d "$HOME/.local/bin" ]] && path=("$HOME/.local/bin" $path)
[[ -d "$HOME/.opencode/bin" ]] && path=("$HOME/.opencode/bin" $path)
[[ -d "$PNPM_HOME" ]] && path=("$PNPM_HOME" $path)
[[ -d "$PNPM_HOME/bin" ]] && path=("$PNPM_HOME/bin" $path)

# Resolve versão mais recente do Node via glob nativo do Zsh (0ms, sem ls/tail)
if [[ -d "$NVM_DIR/versions/node" ]]; then
  local -a _nvm_nodes=("$NVM_DIR"/versions/node/v*(NOn))
  (( ${#_nvm_nodes} )) && [[ -d "${_nvm_nodes[1]}/bin" ]] && path=("${_nvm_nodes[1]}/bin" $path)
  unset _nvm_nodes
fi

# -----------------------------------------------------------------------------
# 3. Tema Solarized Dark — FZF, Bat e Manpages Coloridas
# -----------------------------------------------------------------------------
export BAT_THEME="Solarized (dark)"

if (( $+commands[bat] )); then
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
  export MANROFFOPT="-c"
fi

if (( $+commands[fd] )); then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git --exclude node_modules'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git --exclude node_modules'
fi

# Paleta oficial Solarized Dark (#002b36 / #073642 / #839496 / #268bd2 / #2aa198 / #859900 / #b58900)
export FZF_DEFAULT_OPTS="\
  --height=45% --layout=reverse --border=rounded --info=inline-right \
  --pointer='▶' --marker='✓' \
  --color=fg:#839496,bg:#002b36,hl:#b58900 \
  --color=fg+:#eee8d5,bg+:#073642,hl+:#cb4b16 \
  --color=info:#268bd2,prompt:#859900,pointer:#2aa198 \
  --color=marker:#859900,spinner:#2aa198,header:#586e75,border:#073642"

# -----------------------------------------------------------------------------
# 4. ZINIT (Gerenciador de Plugins Ultra-Rápido) & Prompt Imediato
# -----------------------------------------------------------------------------
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ ! -d "$ZINIT_HOME" ]]; then
  mkdir -p "$(dirname "$ZINIT_HOME")"
  git clone --depth 1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "${ZINIT_HOME}/zinit.zsh"

# Carrega o Powerlevel10k imediatamente para liberar o Instant Prompt
zinit ice depth=1; zinit light romkatv/powerlevel10k
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# -----------------------------------------------------------------------------
# 5. Autocompletion (compinit com cache de 24h ANTES do fzf-tab)
# -----------------------------------------------------------------------------
setopt localoptions extendedglob
autoload -Uz compinit
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.m-1) ]]; then
  compinit -C
else
  compinit
fi

# Configurações do eza e fzf-tab (live preview com eza --tree e bat)
zstyle ':omz:plugins:eza' 'dirs-first' yes
zstyle ':omz:plugins:eza' 'git-status' yes
zstyle ':omz:plugins:eza' 'header' yes
zstyle ':omz:plugins:eza' 'icons' yes

zstyle ':completion:*:git-checkout:*' sort false
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' menu no
zstyle ':fzf-tab:*' switch-group '<' '>'
zstyle ':fzf-tab:*' fzf-flags '--color=fg:#839496,bg:#002b36,hl:#b58900,fg+:#eee8d5,bg+:#073642,hl+:#cb4b16,info:#268bd2,prompt:#859900,pointer:#2aa198,marker:#859900,spinner:#2aa198,header:#586e75' '--bind=tab:accept'
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always --icons --git $realpath 2>/dev/null'
zstyle ':fzf-tab:complete:*:*' fzf-preview 'if [[ -d $realpath ]]; then eza --tree --level=2 --color=always --icons $realpath 2>/dev/null; elif [[ -f $realpath ]]; then bat --color=always --style=numbers --line-range=:200 $realpath 2>/dev/null || cat $realpath; fi'

# -----------------------------------------------------------------------------
# 6. Plugins e Ferramentas em Zinit Turbo Mode (0ms no boot do terminal)
# -----------------------------------------------------------------------------
# Snippets Oh-My-Zsh e fzf-tab (carregados em background logo após o prompt)
zinit wait lucid light-mode for \
    OMZL::git.zsh \
    OMZL::directories.zsh \
    OMZP::git \
    OMZP::direnv \
    OMZP::eza \
    Aloxaf/fzf-tab \
    zsh-users/zsh-autosuggestions \
    atinit"ZINIT[COMPINIT_OPTS]=-C; zicdreplay" \
        zsh-users/zsh-syntax-highlighting

# Zoxide, Atuin e completion do Agent Sandbox em background
zinit wait lucid light-mode for \
    atinit'(( $+commands[zoxide] )) && { unalias zi 2>/dev/null; eval "$(zoxide init zsh)"; }' zdharma-continuum/null \
    atinit'[[ -f "$HOME/.atuin/bin/env" ]] && . "$HOME/.atuin/bin/env"; (( $+commands[atuin] )) && eval "$(atuin init zsh)"' zdharma-continuum/null \
    atinit'[[ -f "$HOME/Workspace/agent-sandbox/local/bin/sbx-completion.zsh" ]] && source "$HOME/Workspace/agent-sandbox/local/bin/sbx-completion.zsh"' zdharma-continuum/null

# -----------------------------------------------------------------------------
# 7. Teclado, Histórico e Comportamento
# -----------------------------------------------------------------------------
bindkey -e

HISTFILE="$HOME/.zhistory"
SAVEHIST=10000
HISTSIZE=10000
setopt share_history
setopt hist_expire_dups_first
setopt hist_ignore_dups
setopt hist_verify

# -----------------------------------------------------------------------------
# 8. Lazy Loading de Ferramentas (NVM)
# -----------------------------------------------------------------------------
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  nvm() {
    unset -f nvm
    source "$NVM_DIR/nvm.sh"
    nvm "$@"
  }
fi

# -----------------------------------------------------------------------------
# 9. Aliases do Desenvolvedor & Kit Modern Unix
# -----------------------------------------------------------------------------
# Sistema & Configuração
alias zshconfig="micro $HOME/.zshrc"
alias zshreload="source $HOME/.zshrc"
alias ff="fastfetch"

# Kit Modern Unix (Fallbacks seguros)
(( $+commands[bat] ))  && alias cat="bat --paging=never" && alias ccat="/bin/cat"
(( $+commands[rg] ))   && alias rg="rg --smart-case"
(( $+commands[duf] ))  && alias df="duf"
(( $+commands[ncdu] )) && alias du="ncdu"

# Dotfiles & Ambiente de Terminal (~/Workspace/dotfiles)
alias dots="$HOME/Workspace/dotfiles/bin/dots"
alias dstatus="dots status"
alias ddiff="dots diff"
alias dcollect="dots collect"
alias dapply="dots apply"
alias dtheme="dots theme"
alias ddoctor="dots doctor"
alias dbench="dots bench"

# OpenCode & Remoto
alias oc-remote="oc-remote"
alias ocd="oc-remote"

# Agent Sandbox (sbx) — Produtividade Diária
alias sbxm="sbx make"
alias sbxw="sbx wp"
alias sbxe="sbx exec"
alias sbxt="sbx self-test"
alias sbxd="sbx doctor"
alias dash="sbx-dash"
