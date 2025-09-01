# ============================================================================
# Dotfiles Makefile (safe, distro-agnostic)
# Author: ethanj78900-glitch (generated)
# Purpose: Install and update dotfiles without hanging or breaking.
# ----------------------------------------------------------------------------
# Requirements (optional but recommended):
#   - GNU Stow (for clean symlink management)
#   - Git
# ============================================================================

SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c

# --- Config -----------------------------------------------------------------

# Your repo identity
GITHUB_USER      ?= ethanj78900-glitch
DOTFILES_REPO    ?= https://github.com/$(ethanj78900-glitch)/dotfiless.git

# Root of this repo (assume Makefile lives at the repo root)
DOTFILES_DIR     ?= $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

# Where to link files (the user's home)
HOME_DIR         ?= $(HOME)

# Directories under repo to stow (edit to your layout)
# By default, we will auto-detect stowable dirs containing typical config roots.
# You can also override STOW_DIRS from the command line: `make STOW_DIRS="zsh nvim"`
STOW_DIRS        ?= $(shell find . -maxdepth 1 -type d \( -name ".git" -o -name ".github" -o -name ".gitmodules" -o -name ".gitlab" \) -prune -o -type d -maxdepth 1 -printf "%f\n" | grep -Ev '^(\.|\.git|\.github|\.gitmodules|src)$$' || true)

# Optional src directory containing git repos to update
SRC_DIR          ?= $(DOTFILES_DIR)/src

# Stow program (if missing, we fallback to manual symlinks)
STOW             ?= stow

# Timeouts and retries (to avoid hangs)
GIT_FETCH_TIMEOUT ?= 30
GIT_PULL_TIMEOUT  ?= 60
RETRY_COUNT       ?= 2
RETRY_SLEEP       ?= 2

# Colors
C_RESET  := \033[0m
C_INFO   := \033[1;34m
C_WARN   := \033[1;33m
C_ERR    := \033[1;31m
C_OK     := \033[1;32m

# --- Helper Macros ----------------------------------------------------------

define log_info
	@printf "$(C_INFO)-- %s$(C_RESET)\n" "$(1)"
endef

define log_warn
	@printf "$(C_WARN)!! %s$(C_RESET)\n" "$(1)"
endef

define log_ok
	@printf "$(C_OK)OK:%s$(C_RESET)\n" " $(1)"
endef

define log_err
	@printf "$(C_ERR)ERR:%s$(C_RESET)\n" " $(1)"
endef

# Executes a command with retries.
# Usage: $(call with_retries, <cmd>)
define with_retries
i=0; rc=1; \
while [ $$i -le $(RETRY_COUNT) ]; do \
  if eval "$(1)"; then rc=0; break; fi; \
  i=$$((i+1)); \
  echo "Retry $$i/$(RETRY_COUNT) in $(RETRY_SLEEP)s ..."; \
  sleep $(RETRY_SLEEP); \
done; \
exit $$rc
endef

# Safe git fetch/pull with timeouts and no prompts (won't hang)
# $(1) = repo path
define safe_git_update
if [ -d "$(1)/.git" ]; then \
  GIT_TERMINAL_PROMPT=0 git -C "$(1)" config --local pull.rebase false || true; \
  GIT_TERMINAL_PROMPT=0 git -C "$(1)" config --local fetch.prune true || true; \
  if command -v timeout >/dev/null 2>&1; then \
    $(call with_retries,timeout $(GIT_FETCH_TIMEOUT)s GIT_TERMINAL_PROMPT=0 git -C "$(1)" fetch --all --prune --tags --force); \
    $(call with_retries,timeout $(GIT_PULL_TIMEOUT)s  GIT_TERMINAL_PROMPT=0 git -C "$(1)" pull --ff-only || true); \
  else \
    $(call with_retries,GIT_TERMINAL_PROMPT=0 git -C "$(1)" fetch --all --prune --tags --force); \
    $(call with_retries,GIT_TERMINAL_PROMPT=0 git -C "$(1)" pull --ff-only || true); \
  fi; \
else \
  echo "Skipping git update: $(1) is not a git repo"; \
fi
endef

# Manual symlink if stow is not available
# $(1) = source dir within repo, $(2) = destination (HOME)
define link_dir_manually
src="$(DOTFILES_DIR)/$(1)"; \
dest="$(2)"; \
if [ ! -d "$$src" ]; then echo "Skip: $$src missing"; exit 0; fi; \
cd "$$src"; \
find . -type f -o -type l -o -type d | while read -r p; do \
  [ "$$p" = "." ] && continue; \
  target="$$dest/$$p"; \
  mkdir -p "$$(dirname "$$target")"; \
  if [ -e "$$target" ] || [ -L "$$target" ]; then \
    if [ -L "$$target" ] && [ "$$(readlink -f "$$target")" = "$$(readlink -f "$$src/$$p")" ]; then \
      continue; \
    else \
      echo "Backup existing: $$target"; \
      mv -f "$$target" "$$target.bak.$$(date +%s)"; \
    fi; \
  fi; \
  ln -s "$$src/$$p" "$$target"; \
done
endef

# Unlink manually (remove symlinks that point into repo)
# $(1) = source dir within repo, $(2) = destination (HOME)
define unlink_dir_manually
src="$(DOTFILES_DIR)/$(1)"; \
dest="$(2)"; \
if [ ! -d "$$src" ]; then echo "Skip: $$src missing"; exit 0; fi; \
cd "$$src"; \
find . -type f -o -type l -o -type d | while read -r p; do \
  [ "$$p" = "." ] && continue; \
  target="$$dest/$$p"; \
  if [ -L "$$target" ] && [ "$$(readlink -f "$$target")" = "$$(readlink -f "$$src/$$p")" ]; then \
    rm -f "$$target"; \
  fi; \
done
endef

# --- Top-level Targets ------------------------------------------------------

.PHONY: default install update links unlink relink update-src status doctor cleanup self-update \
        link-conf link-local link-misc update-zsh update-vim update-tmux update-plugins

default: install

install: links
	$(call log_ok,Install complete)

update: self-update update-src update-plugins
	$(call log_ok,Update complete)

# Link all stowable directories
links: link-conf link-local link-misc
	@true

# Unlink all stowable directories
unlink:
	$(call log_info,Unlinking dotfiles from $(HOME_DIR))
	@if command -v $(STOW) >/dev/null 2>&1; then \
	  for dir in $(STOW_DIRS); do \
	    [ -d "$(DOTFILES_DIR)/$$dir" ] || continue; \
	    echo "stow -D $$dir -> $(HOME_DIR)"; \
	    $(STOW) -D "$$dir" -t "$(HOME_DIR)" || true; \
	  done; \
	else \
	  for dir in $(STOW_DIRS); do \
	    [ -d "$(DOTFILES_DIR)/$$dir" ] || continue; \
	    echo "unlink (manual) $$dir -> $(HOME_DIR)"; \
	    $(call unlink_dir_manually,$$dir,$(HOME_DIR)); \
	  done; \
	fi
	$(call log_ok,Unlink complete)

# Remove and re-link in one go
relink: unlink links
	$(call log_ok,Relink complete)

# --- Specific Link Groups (adjust patterns as needed) -----------------------

# "conf": directories likely containing ~/.config and similar layouts
link-conf:
	$(call log_info,Linking configuration directories to $(HOME_DIR))
	@if command -v $(STOW) >/dev/null 2>&1; then \
	  for dir in $(STOW_DIRS); do \
	    [ -d "$(DOTFILES_DIR)/$$dir/.config" ] || [ -d "$(DOTFILES_DIR)/$$dir/.local" ] || [ -d "$(DOTFILES_DIR)/$$dir/.cache" ] || continue; \
	    echo "stow -S $$dir -> $(HOME_DIR)"; \
	    $(STOW) -S "$$dir" -t "$(HOME_DIR)" || true; \
	  done; \
	else \
	  for dir in $(STOW_DIRS); do \
	    [ -d "$(DOTFILES_DIR)/$$dir/.config" ] || [ -d "$(DOTFILES_DIR)/$$dir/.local" ] || [ -d "$(DOTFILES_DIR)/$$dir/.cache" ] || continue; \
	    echo "link (manual) $$dir -> $(HOME_DIR)"; \
	    $(call link_dir_manually,$$dir,$(HOME_DIR)); \
	  done; \
	fi
	@echo

# "local": optional, for files targeting ~ directly (like .zshrc)
link-local:
	$(call log_info,Linking dotfiles into $(HOME_DIR))
	@if command -v $(STOW) >/dev/null 2>&1; then \
	  for dir in $(STOW_DIRS); do \
	    shopt -s nullglob dotglob; \
	    files=($(DOTFILES_DIR)/$$dir/.*); \
	    [ $${#files[@]} -eq 0 ] && continue; \
	    echo "stow -S $$dir -> $(HOME_DIR)"; \
	    $(STOW) -S "$$dir" -t "$(HOME_DIR)" || true; \
	  done; \
	else \
	  for dir in $(STOW_DIRS); do \
	    echo "link (manual) $$dir -> $(HOME_DIR)"; \
	    $(call link_dir_manually,$$dir,$(HOME_DIR)); \
	  done; \
	fi
	@echo

# "misc": everything else that's safe to link
link-misc:
	$(call log_info,Linking remaining directories)
	@if command -v $(STOW) >/dev/null 2>&1; then \
	  for dir in $(STOW_DIRS); do \
	    [ -d "$(DOTFILES_DIR)/$$dir" ] || continue; \
	    echo "stow -S $$dir -> $(HOME_DIR)"; \
	    $(STOW) -S "$$dir" -t "$(HOME_DIR)" || true; \
	  done; \
	else \
	  for dir in $(STOW_DIRS); do \
	    echo "link (manual) $$dir -> $(HOME_DIR)"; \
	    $(call link_dir_manually,$$dir,$(HOME_DIR)); \
	  done; \
	fi
	@echo

# --- Updates ---------------------------------------------------------------

# Update this dotfiles repo (non-blocking, safe)
self-update:
	$(call log_info,Updating dotfiles repo at $(DOTFILES_DIR))
	@if [ -d "$(DOTFILES_DIR)/.git" ]; then \
	  $(call safe_git_update,$(DOTFILES_DIR)); \
	else \
	  $(call log_warn,This directory is not a git repo. To clone use: git clone $(DOTFILES_REPO)); \
	fi
	@echo

# Update every repo under src/
update-src:
	$(call log_info,Updating repos under $(SRC_DIR))
	@if [ -d "$(SRC_DIR)" ]; then \
	  find "$(SRC_DIR)" -mindepth 1 -maxdepth 1 -type d | while read -r d; do \
	    echo "Updating $$d"; \
	    $(call safe_git_update,$$d) || $(call log_warn,Failed to update $$d); \
	  done; \
	else \
	  $(call log_warn,$(SRC_DIR) does not exist — skipping); \
	fi
	@echo

# Update common tools (edit or remove as needed)
update-plugins: update-zsh update-vim update-tmux
	@true

update-zsh:
	$(call log_info,Updating zsh plugins if present)
	@if [ -d "$(HOME_DIR)/.oh-my-zsh" ]; then \
	  $(call safe_git_update,$(HOME_DIR)/.oh-my-zsh); \
	fi
	@if [ -d "$(HOME_DIR)/.zplug" ]; then \
	  $(call safe_git_update,$(HOME_DIR)/.zplug); \
	fi
	@echo

update-vim:
	$(call log_info,Updating Vim/Neovim plugins if configured)
	@if command -v nvim >/dev/null 2>&1; then \
	  nvim --headless "+Lazy! sync" +qa || nvim --headless "+PackerSync" +qa || true; \
	fi
	@if command -v vim >/dev/null 2>&1; then \
	  vim -Nu NONE -n --not-a-term -c 'quit' >/dev/null 2>&1 || true; \
	fi
	@echo

update-tmux:
	$(call log_info,Updating tmux plugin manager if present)
	@if [ -d "$(HOME_DIR)/.tmux/plugins/tpm/.git" ]; then \
	  $(call safe_git_update,$(HOME_DIR)/.tmux/plugins/tpm); \
	fi
	@echo

# --- Introspection & Maintenance -------------------------------------------

status:
	$(call log_info,Git status)
	@if [ -d "$(DOTFILES_DIR)/.git" ]; then \
	  git -C "$(DOTFILES_DIR)" status -s || true; \
	else \
	  $(call log_warn,Not a git repo); \
	fi
	@echo

doctor:
	$(call log_info,System check)
	@command -v git  >/dev/null 2>&1 && echo "git: OK"  || echo "git: MISSING"
	@command -v $(STOW) >/dev/null 2>&1 && echo "$(STOW): OK" || echo "$(STOW): MISSING (will fallback to manual symlinks)"
	@echo "DOTFILES_DIR: $(DOTFILES_DIR)"
	@echo "HOME_DIR    : $(HOME_DIR)"
	@echo "STOW_DIRS   : $(STOW_DIRS)"
	@echo "SRC_DIR     : $(SRC_DIR)"
	@echo

cleanup:
	$(call log_info,Cleanup backups older than 30 days)
	@find "$(HOME_DIR)" -type f -name "*.bak.*" -mtime +30 -print -delete 2>/dev/null || true
	@echo

# --- Safety ----------------------------------------------------------------

# Prevent make from trying to create files named like our targets
.PHONY: default install update links unlink relink link-conf link-local link-misc \
        update-src self-update update-plugins update-zsh update-vim update-tmux \
        status doctor cleanup
