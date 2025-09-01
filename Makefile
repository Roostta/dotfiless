.PHONY: \
	default \
	update \
	links \
	install \
	min \
	min-update \
	min-install \
	min-links \
	install-yay \
	install-paru \
	install-aur-packages \
	install-packages \
	user-fs \
	update-zsh-plugins \
	update-libs \
	init-vim \
	update-vim \
	update-src \
	link-misc \
	link-conf \
	link-local \
	set-shell \
	i3 \
	rofi \
	dunst \
	update-tmux \
	save-originals \
	rustup \
	update-rust

HOST ?= $(shell hostname)
NOW = $(shell date +"%Y-%m-%dT%T")
TIMESTAMP = $(shell date +%s)
VARS = ~/etc/local/$(HOST)/variables.mk
CONF = $(shell ls conf)
LOCAL = $(shell [ -d local/$(HOST)/conf ] && ls local/$(HOST)/conf || echo "")
DIRS = \
	~/src \
	~/lib \
	~/mnt \
	~/tmp \
	~/bin \
	~/opt \
	~/sbin \
	~/var/log \
	~/var/vim/undo \
	~/.cache/vim/backup \
	~/.cache/zsh \
	~/backup \
	~/.local/share \
	~/.config/dunst \
	~/.local/share/applications \
	~/etc/build

ifneq ("$(wildcard $(VARS))","")
include $(VARS)
endif

default: links update i3 rofi dunst

update: update-zsh-plugins update-libs update-tmux update-vim update-rust

links: link-conf link-misc link-local

install: user-fs \
	rustup \
	install-paru \
	install-packages \
	install-aur-packages \
	save-originals \
	set-shell \
	update-src \
	update-libs \
	update-zsh-plugins \
	~/.tmux/plugins/tpm \
	links \
	~/.zplug cleanup

min: min-install \
	save-originals \
	user-fs \
	update-libs \
	set-shell \
	min-links \
	~/src/srcery-vim \
	~/src/srcery-terminal \
	update-zsh-plugins \
	init-vim \
	~/.tmux/plugins/tpm \
	update-tmux \
	cleanup

min-update: update-libs update-zsh-plugins update-tmux update-vim

min-install:
	xargs sudo apt-get install -y < min_packages.txt

min-links:
	stow -R -t ~ -d conf zsh git tmux vim bash nvim

cleanup:
	@echo "Cleaning up..."
	-rm -rf ~/etc/build

install-yay: ~/etc/build rustup
	@echo "Installing yay..."
	sudo pacman -S --needed --noconfirm base-devel git clang cmake make gcc pkgconf
	@if ! command -v yay >/dev/null 2>&1; then \
		cd ~/etc/build && git clone https://aur.archlinux.org/yay.git; \
		cd ~/etc/build/yay && makepkg -si --noconfirm --needed; \
	else echo "yay already installed."; fi

install-paru: ~/etc/build rustup
	@echo "Installing paru..."
	sudo pacman -S --needed --noconfirm base-devel git clang cmake make gcc pkgconf
	@if ! command -v paru >/dev/null 2>&1; then \
		cd ~/etc/build && git clone https://aur.archlinux.org/paru.git; \
		cd ~/etc/build/paru && makepkg -si --noconfirm --needed; \
	else echo "paru already installed."; fi

install-aur-packages: install-paru
	@echo "Installing AUR packages..."
	paru -S --needed --noconfirm - < aur_packages.txt

install-packages:
	@echo "Installing packages..."
	sudo pacman --needed -S - < pacman_packages.txt

user-fs: $(DIRS)
	@echo "Creating user fs..."

$(DIRS):
	mkdir -p $@

update-zsh-plugins: ~/.zplug
	@echo "Updating zsh plugins..."
	chmod +x ./scripts/zsh-update.sh
	./scripts/zsh-update.sh || true

update-libs:
	@echo "Updating libs..."
	@if [ -f ~/etc/lib_repositories.txt ]; then \
		chmod +x ./scripts/git_update.sh; \
		./scripts/git_update.sh ~/lib ~/etc/lib_repositories.txt; \
	else echo "Warning: ~/etc/lib_repositories.txt missing, skipping libs update"; fi

init-vim: ~/.vim/autoload/plug.vim
	@echo "Initialize Vim..."
	vim -c "exec InstallAndExit()"

update-vim: ~/.vim/autoload/plug.vim
	@echo "Updating Vim packages..."
	vim -c "exec UpdateAndExit()"

~/.vim/autoload/plug.vim:
	@echo "Installing vim-plug..."
	curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

update-src:
	@echo "Update src..."
	@if [ -f ~/etc/src_repositories.txt ]; then \
		chmod +x ./scripts/git_update.sh; \
		./scripts/git_update.sh ~/src ~/etc/src_repositories.txt; \
	else echo "Warning: ~/etc/src_repositories.txt missing, skipping src update"; fi

link-misc: ~/scripts ~/colors ~/bin/ftl ~/bin/touchpad-toggle ~/bin/tmain ~/bin/tupd
	@echo "Symlinking misc files..."

~/scripts: user-fs
	-ln -sf $(HOME)/src/scripts $(HOME)

~/colors: user-fs
	-ln -sf $(HOME)/src/colors $(HOME)

~/bin/ftl: user-fs
	-ln -sf $(HOME)/etc/scripts/ftl.sh $@

~/bin/touchpad-toggle: user-fs update-src
	-ln -sf $(HOME)/src/scripts/touchpad-toggle.sh $@

~/bin/tmain: user-fs
	-ln -sf $(HOME)/scripts/tmux-main.sh $@

~/bin/tupd: user-fs
	-ln -sf $(HOME)/scripts/tmux-update-window.sh $@

link-conf: user-fs
	@echo "Symlinking conf..."
	-stow -R -t ~ -d conf --ignore="md|org|firefox" $(CONF) 2>&1 | grep -v "BUG in find_stowed_path" || true

link-local:
	@echo "Symlinking local..."
	@if [ -d local/$(HOST)/conf ]; then \
		stow -R -t ~ -d local/$(HOST)/conf $(LOCAL) 2>&1 | grep -v "BUG in find_stowed_path" || true; \
	else \
		echo "No local config found for host $(HOST), skipping..."; \
	fi

set-shell:
	@echo "Setting shell to zsh..."
	-chsh -s `which zsh`

save-originals:
	@echo "Saving originals..."
	mkdir -p ~/backup/original-system-files
	-@mv -f ~/.bash* ~/backup/original-system-files 2>/dev/null || true

update-tmux: ~/.tmux/plugins/tpm
	@echo "Updating tmux plugins..."
	~/.tmux/plugins/tpm/bin/update_plugins all || true

~/.tmux/plugins/tpm:
	@echo "Installing tmux plugin manager..."
	@mkdir -p $(@D)
	-@git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm && ~/.tmux/plugins/tpm/bin/install_plugins

rustup:
	@echo "Installing Rust toolchain..."
	@if ! command -v rustup >/dev/null 2>&1; then \
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; \
		export PATH="$$HOME/.cargo/bin:$$PATH"; \
	fi
	rustup install stable || true
	rustup default stable || true

update-rust:
	@echo "Updating Rust..."
	rustup update || true
