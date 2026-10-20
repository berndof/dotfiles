# =============================================================================
# ~/.zshrc — Configuração do ZSH (Bernardo)
# Otimizado com Zinit, Powerlevel10k, Atuin, Zoxide, FZF e Agent Sandbox
# =============================================================================

# -----------------------------------------------------------------------------
# 1. Powerlevel10k Instant Prompt (DEVE ficar no topo do arquivo)
# -----------------------------------------------------------------------------
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# -----------------------------------------------------------------------------
# 2. Otimização de PATH e Variáveis Globais
# -----------------------------------------------------------------------------
export PNPM_HOME="$HOME/.local/share/pnpm"
export NVM_DIR="$HOME/.nvm"
export EDITOR="micro"

typeset -U path fpath

[[ -d "$HOME/.local/bin" ]] && path=("$HOME/.local/bin" $path)
[[ -d "$HOME/.opencode/bin" ]] && path=("$HOME/.opencode/bin" $path)
[[ -d "$PNPM_HOME" ]] && path=("$PNPM_HOME" $path)
[[ -d "$PNPM_HOME/bin" ]] && path=("$PNPM_HOME/bin" $path)

# Adiciona versão padrão do Node ao PATH de forma instantânea (sem carregar nvm.sh)
if [[ -d "$NVM_DIR/versions/node" ]]; then
  NODE_DEFAULT="$(ls -d "$NVM_DIR/versions/node"/v* 2>/dev/null | tail -n 1)/bin"
  [[ -d "$NODE_DEFAULT" ]] && path=("$NODE_DEFAULT" $path)
fi

# -----------------------------------------------------------------------------
# 3. ZINIT (Gerenciador de Plugins Ultra-Rápido)
# -----------------------------------------------------------------------------
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ ! -d "$ZINIT_HOME" ]]; then
  mkdir -p "$(dirname "$ZINIT_HOME")"
  git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "${ZINIT_HOME}/zinit.zsh"

# Prompt Powerlevel10k
zinit ice depth=1; zinit light romkatv/powerlevel10k

# Bibliotecas essenciais do Oh-My-Zsh
zinit snippet OMZL::git.zsh
zinit snippet OMZL::directories.zsh

# Configurações do eza (antes do plugin)
zstyle ':omz:plugins:eza' 'dirs-first' yes
zstyle ':omz:plugins:eza' 'git-status' yes
zstyle ':omz:plugins:eza' 'header' yes
zstyle ':omz:plugins:eza' 'icons' yes

# Plugins Oh-My-Zsh leves
zinit snippet OMZP::git
zinit snippet OMZP::direnv
zinit snippet OMZP::eza

# FZF Tab Completion
zinit light Aloxaf/fzf-tab

# Plugins com carregamento em background (0s no boot do terminal)
zinit wait lucid light-mode for \
    zsh-users/zsh-autosuggestions \
    zsh-users/zsh-syntax-highlighting

# Zoxide (cd inteligente) e Atuin (histórico sincronizado) em background
zinit wait lucid light-mode for \
    atinit'eval "$(zoxide init zsh)"' zdharma-continuum/null \
    atinit'. "$HOME/.atuin/bin/env"; eval "$(atuin init zsh)"' zdharma-continuum/null

# -----------------------------------------------------------------------------
# 4. Sistema Moderno de Autocompletion (compinit otimizado com cache 24h)
# -----------------------------------------------------------------------------
setopt localoptions extendedglob
autoload -Uz compinit
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.m-1) ]]; then
  compinit -C
else
  compinit
fi
zcompile "${ZDOTDIR:-$HOME}/.zcompdump" 2>/dev/null

# Carrega autocompletion do Agent Sandbox (sbx)
if [[ -f "$HOME/Workspace/agent-sandbox/local/bin/sbx-completion.zsh" ]]; then
  source "$HOME/Workspace/agent-sandbox/local/bin/sbx-completion.zsh"
fi

# -----------------------------------------------------------------------------
# 5. Teclado, Histórico e Comportamento
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
# 6. Lazy Loading de Ferramentas
# -----------------------------------------------------------------------------
# NVM (carrega nvm.sh apenas se você chamar o comando 'nvm')
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  nvm() {
    unset -f nvm
    source "$NVM_DIR/nvm.sh"
    nvm "$@"
  }
fi

# -----------------------------------------------------------------------------
# 7. Aliases do Desenvolvedor
# -----------------------------------------------------------------------------
# Sistema & Configuração
alias zshconfig="micro $HOME/.zshrc"
alias zshreload="source $HOME/.zshrc"

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

# -----------------------------------------------------------------------------
# 8. Tema Powerlevel10k
# -----------------------------------------------------------------------------
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
