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
	update-tmux \
	save-originals \
	rustup \
	update-rust

HOST ?= $(shell hostname)
NOW = $(shell date +"%Y-%m-%dT%T")
TIMESTAMP=$(shell date +%s)
VARS = ~/etc/local/$(HOST)/variables.mk
CONF = $(shell ls conf 2>/dev/null || echo "")
LOCAL = $(shell ls local/$(HOST)/conf 2>/dev/null || echo "")
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
	@echo "Installing minimal packages..."
	@if [ -f min_packages.txt ]; then xargs sudo apt-get install -y < min_packages.txt; else echo "No min_packages.txt found, skipping."; fi

min-links:
	stow -R -t ~ -d conf zsh git tmux vim bash nvim || true

cleanup:
	@echo -e "\033[0;33mCleaning up...\033[0m"
	-rm -rf ~/etc/build

install-yay: ~/etc/build
	@echo "Installing yay..."
	@if ! command -v yay >/dev/null 2>&1; then \
		cd ~/etc/build && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm --needed; \
	else echo "yay already installed."; fi

install-paru: ~/etc/build
	@echo "Installing paru..."
	@if ! command -v paru >/dev/null 2>&1; then \
		cd ~/etc/build && git clone https://aur.archlinux.org/paru.git && cd paru && makepkg -si --noconfirm --needed; \
	else echo "paru already installed."; fi

add-pacman-repositories:
	@echo "Adding pacman repositories..."
	@if [ -f pacman_repositories.txt ]; then \
		cat pacman_repositories.txt | sudo tee -a /etc/pacman.conf; \
	else echo "No pacman_repositories.txt found, skipping."; fi

install-aur-packages: install-yay
	@echo "Installing AUR packages..."
	@if [ -f aur_packages.txt ]; then yay -S --needed --noconfirm - < aur_packages.txt; else echo "No aur_packages.txt found, skipping."; fi

install-packages:
	@echo "Installing system packages..."
	@if [ -f pacman_packages.txt ]; then sudo pacman --needed -S - < pacman_packages.txt; else echo "No pacman_packages.txt found, skipping."; fi

# Scaffold user fs structure.
user-fs: $(DIRS)
	@echo "Creating user fs..."

$(DIRS):
	mkdir -p $@

~/.cache/zsh/dirs:
	-touch ~/.cache/zsh/dirs

update-zsh-plugins:
	@echo "Updating zsh plugins..."
	@if [ -f ./scripts/zsh-update.sh ]; then chmod +x ./scripts/zsh-update.sh && ./scripts/zsh-update.sh; else echo "zsh-update.sh missing, skipping."; fi

update-libs:
	@echo "Updating libs..."
	@if [ -f ./scripts/git_update.sh ]; then chmod +x ./scripts/git_update.sh; else echo "git_update.sh missing, skipping libs update."; exit 0; fi
	@if [ -f ~/etc/lib_repositories.txt ]; then ./scripts/git_update.sh ~/lib ~/etc/lib_repositories.txt; else echo "Missing ~/etc/lib_repositories.txt, skipping."; fi

init-vim: ~/.vim/autoload/plug.vim
	@echo "Initialize Vim..."
	vim -c "silent! exec InstallAndExit()" || true

update-vim: ~/.vim/autoload/plug.vim
	@echo "Updating Vim packages..."
	vim -c "silent! exec UpdateAndExit()" || true

~/.vim/autoload/plug.vim:
	@echo "Getting vim-plug..."
	curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

update-src:
	@echo "Updating src..."
	@if [ -f ./scripts/git_update.sh ]; then chmod +x ./scripts/git_update.sh; else echo "git_update.sh missing, skipping src update."; exit 0; fi
	@if [ -f ~/etc/src_repositories.txt ]; then ./scripts/git_update.sh ~/src ~/etc/src_repositories.txt; else echo "Missing ~/etc/src_repositories.txt, skipping."; fi

link-misc:
	@echo "Symlinking misc files..."
	-ln -sf $(HOME)/src/scripts $(HOME) || true
	-ln -sf $(HOME)/src/colors $(HOME) || true
	-ln -sf $(HOME)/etc/scripts/ftl.sh ~/bin/ftl || true
	-ln -sf $(HOME)/src/scripts/touchpad-toggle.sh ~/bin/touchpad-toggle || true
	-ln -sf $(HOME)/scripts/tmux-main.sh ~/bin/tmain || true
	-ln -sf $(HOME)/scripts/tmux-music.sh ~/bin/tmusic || true
	-ln -sf $(HOME)/scripts/tmux-update-window.sh ~/bin/tupd || true
	-ln -sf $(HOME)/scripts/tmux-ssh.sh ~/bin/tssh || true

link-conf: user-fs
	@echo "Symlinking conf..."
	@if [ -d conf ]; then stow -R -t ~ -d conf --ignore="md|org|firefox" $(CONF) 2>&1 | grep -v "BUG in find_stowed_path" || true; else echo "No conf dir found."; fi

link-local:
	@echo "Symlinking local..."
	@if [ -d local/$(HOST)/conf ]; then \
		stow -R -t ~ -d local/$(HOST)/conf $(LOCAL) 2>&1 | grep -v "BUG in find_stowed_path" || true; \
	else echo "No local config found for host $(HOST), skipping..."; fi

set-shell:
	@echo "Setting shell to zsh..."
	-chsh -s `which zsh` || true

save-originals:
	@echo "Saving original system files..."
	mkdir -p ~/backup/original-system-files
	-@mv -f ~/.bash* ~/backup/original-system-files 2>/dev/null || true

update-tmux:
	@echo "Updating tmux plugins..."
	@if [ -d ~/.tmux/plugins/tpm ]; then \
		~/.tmux/plugins/tpm/bin/update_plugins all || true; \
	else \
		echo "TPM not installed, installing..."; \
		git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm && ~/.tmux/plugins/tpm/bin/install_plugins; \
	fi

rustup:
	rustup install stable || true
	rustup install nightly || true
	rustup default stable || true

update-rust:
	rustup update || true

~/.zplug:
	curl -sL --proto-redir -all,https https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh

~/src/srcery-vim:
	@mkdir -p $(@D)
	git clone https://github.com/srcery-colors/srcery-vim ~/src/srcery-vim

~/src/srcery-terminal:
	@mkdir -p $(@D)
	git clone https://github.com/srcery-colors/srcery-terminal ~/src/srcery-terminal
