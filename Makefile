SHELL := /usr/bin/env bash
DOTS  := ./bin/dots

.PHONY: help status diff collect apply theme doctor bench backup bootstrap fonts packages cli

help: ## Show available make targets
	@awk 'BEGIN {FS = ":.*##"; printf "\n\033[1;35mdotfiles Makefile\033[0m\n\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2 } END {printf "\n"}' $(MAKEFILE_LIST)

status: ## Compare live system (~/) vs repository configs
	@$(DOTS) status

diff: ## Show unified diff between repository and live configs
	@$(DOTS) diff

collect: ## Capture live configs from ~/ into repository
	@$(DOTS) collect

apply: ## Apply repository configs to ~/ (with auto-backup)
	@$(DOTS) apply

theme: ## List available Konsole colorschemes and Zsh prompts
	@$(DOTS) theme list

doctor: ## Audit installed CLI tools, fonts, Zinit & secret hygiene
	@$(DOTS) doctor

bench: ## Benchmark interactive Zsh startup time (5 runs)
	@$(DOTS) bench 5

backup: ## List automatic backups created before apply
	@$(DOTS) backup list

bootstrap: ## Run full environment bootstrap (packages + CLI + fonts + apply)
	@./install.sh --all

packages: ## Install OS packages (zsh, eza, fzf, direnv, micro, btop)
	@./install.sh --packages

cli: ## Install modern CLI tools (zinit, zoxide, atuin, starship)
	@./install.sh --cli

fonts: ## Install JetBrainsMono Nerd Font
	@./install.sh --fonts
