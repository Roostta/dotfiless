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
TIMESTAMP = $(shell date +%s)
VARS = ~/etc/local/$(HOST)/variables.mk
CONF = $(shell ls conf 2>/dev/null || true)
LOCAL = $(shell ls local/$(HOST)/conf 2>/dev/null || true)

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
	xargs sudo apt-get install -y < min_packages.txt

min-links:
	stow -R -t ~ -d conf zsh git tmux vim bash nvim

cleanup:
	@echo "Cleaning up..."
	-rm -rf ~/etc/build

install-yay: ~/etc/build
	@echo "Installing yay..."
	@if ! command -v yay >/dev/null 2>&1; then \
		cd ~/etc/build && git clone https://aur.archlinux.org/yay.git; \
		cd ~/etc/build/yay && makepkg -si --noconfirm --needed; \
	else echo "yay already installed."; fi

install-paru: ~/etc/build rustup
	@echo "Installing paru..."
	@if ! command -v paru >/dev/null 2>&1; then \
		cd ~/etc/build && git clone https://aur.archlinux.org/paru.git; \
		cd ~/etc/build/paru && makepkg -si --noconfirm --needed; \
	else echo "paru already installed."; fi

add-pacman-repositories:
	@echo "Adding pacman repositories..."
	@if [ -f pacman_repositories.txt ]; then \
		cat pacman_repositories.txt | sudo tee -a /etc/pacman.conf; \
	else echo "No pacman_repositories.txt found, skipping..."; fi

install-aur-packages: install-yay
	@echo "Installing AUR packages..."
	@if [ -f aur_packages.txt ]; then yay -S --needed --noconfirm - < aur_packages.txt; \
	else echo "No aur_packages.txt found, skipping..."; fi

install-packages:
	@echo "Installing packages..."
	@if [ -f pacman_packages.txt ]; then sudo pacman --needed -S - < pacman_packages.txt; \
	else echo "No pacman_packages.txt found, skipping..."; fi

# Scaffold user fs structure.
user-fs: $(DIRS)
	@echo "Creating user fs..."

$(DIRS):
	mkdir -p $@

~/.cache/zsh/dirs:
	-touch ~/.cache/zsh/dirs

update-zsh-plugins: ~/.zplug
	@echo "Updating zsh plugins..."
	chmod +x ./scripts/zsh-update.sh || true
	./scripts/zsh-update.sh || true

update-libs:
	@echo "Updating libs..."
	if [ -f ~/etc/lib_repositories.txt ]; then \
		chmod +x ./scripts/git_update.sh || true; \
		./scripts/git_update.sh ~/lib ~/etc/lib_repositories.txt; \
	else echo "Warning: Missing ~/etc/lib_repositories.txt"; fi

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
	@echo "Updating src..."
	if [ -f ~/etc/src_repositories.txt ]; then \
		chmod +x ./scripts/git_update.sh || true; \
		./scripts/git_update.sh ~/src ~/etc/src_repositories.txt; \
	else echo "Warning: Missing ~/etc/src_repositories.txt"; fi

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

~/bin/tmusic: user-fs
	-ln -sf $(HOME)/scripts/tmux-music.sh $@

~/bin/tupd: user-fs
	-ln -sf $(HOME)/scripts/tmux-update-window.sh $@

~/bin/tssh: user-fs
	-ln -sf $(HOME)/scripts/tmux-ssh.sh $@

link-conf: user-fs
	@echo "Symlinking conf..."
	@if [ -n "$(CONF)" ]; then \
		stow -R -t ~ -d conf --ignore="md|org|firefox" $(CONF) 2>&1 | grep -v "BUG in find_stowed_path" || true; \
	else echo "No conf found, skipping..."; fi

link-local:
	@echo "Symlinking local..."
	@if [ -n "$(LOCAL)" ]; then \
		stow -R -t ~ -d local/$(HOST)/conf $(LOCAL) 2>&1 | grep -v "BUG in find_stowed_path" || true; \
	else echo "No local config found for host $(HOST), skipping..."; fi

set-shell:
	@echo "Setting shell to zsh..."
	-chsh -s `which zsh` || true

~/.dircolors: update-libs
	-ln -s $(HOME)/lib/LS_COLORS/LS_COLORS $@

~/.config/i3/config: link-conf
	@echo "Creating i3 config..."
	@if [ -d ~/etc/templates/i3 ]; then \
		cd ~/etc/templates/i3 && cat *.i3 > $@; \
	fi

i3: ~/.config/i3/config
	@echo "Reloading i3 config..."
	-i3-msg reload || true

~/.config/sway/config: link-conf
	@echo "Creating sway config..."
	@if [ -d ~/etc/templates/sway ]; then \
		cd ~/etc/templates/sway && cat *.sway > $@; \
	fi

sway: ~/.config/sway/config
	@echo "Reloading sway config..."
	-swaymsg reload || true

dunst: ~/.config/dunst/dunstrc
	@echo "Creating dunst config..."

~/.config/dunst/dunstrc: ~/etc/templates/dunst/config.dunst
	@mkdir -p $(@D)
	@if [ -f ~/etc/templates/dunst/config.dunst ]; then \
		cat ~/etc/templates/dunst/config.dunst > ~/.config/dunst/dunstrc; \
	fi

~/.config/rofi/config.rasi: ~/etc/templates/rofi/config.rofi
	@if [ -d ~/etc/templates/rofi ]; then \
		cat ~/etc/templates/rofi/*.rofi > $@; \
	fi

rofi: ~/.config/rofi/config.rasi
	@echo "Creating rofi config..."

update-tmux: ~/.tmux/plugins/tpm
	@echo "Updating tmux plugins..."
	@if [ -f ~/.tmux/plugins/tpm/bin/update_plugins ]; then \
		~/.tmux/plugins/tpm/bin/update_plugins all || true; \
	else echo "Tmux Plugin Manager not installed properly"; fi

~/.tmux/plugins/tpm:
	@echo "Installing tmux plugin manager..."
	@mkdir -p $(@D)
	@if [ ! -d ~/.tmux/plugins/tpm ]; then \
		git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm; \
		~/.tmux/plugins/tpm/bin/install_plugins || true; \
	fi

save-originals:
	mkdir -p ~/backup/original-system-files
	-@mv ~/.bash* ~/backup/original-system-files 2>/dev/null || true

rustup:
	@echo "Installing Rust..."
	@if ! command -v rustup >/dev/null 2>&1; then \
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; \
		export PATH="$$HOME/.cargo/bin:$$PATH"; \
	fi
	-rustup install stable || true
	-rustup default stable || true

update-rust:
	rustup update || true

~/.zplug:
	curl -sL --proto-redir -all,https https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh
