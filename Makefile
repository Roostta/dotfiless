.PHONY: \
	default update links install min min-update min-install min-links \
	install-yay install-paru install-aur-packages install-packages \
	user-fs update-zsh-plugins update-libs init-vim update-vim update-src \
	link-misc link-conf link-local set-shell i3 sway rofi dunst \
	update-tmux save-originals rustup update-rust

HOST ?= $(shell hostname)
NOW = $(shell date +"%Y-%m-%dT%T")
TIMESTAMP = $(shell date +%s)
VARS = ~/etc/local/$(HOST)/variables.mk
CONF = $(shell ls conf)
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

### Minimal install
min: min-install save-originals user-fs update-libs set-shell min-links \
	~/src/srcery-vim ~/src/srcery-terminal update-zsh-plugins init-vim \
	~/.tmux/plugins/tpm update-tmux cleanup

min-update: update-libs update-zsh-plugins update-tmux update-vim

min-install:
	xargs sudo pacman -S --needed --noconfirm < min_packages.txt

min-links:
	stow -R -t ~ -d conf zsh git tmux vim bash nvim

cleanup:
	@echo -e "\033[0;33mCleaning up...\033[0m"
	-rm -rf ~/etc/build

### AUR helpers
install-yay: ~/etc/build rustup
	@echo "Installing yay..."
	sudo pacman -S --needed --noconfirm base-devel git clang cmake make gcc pkgconf
	@if ! command -v yay >/dev/null 2>&1; then \
		cd ~/etc/build && git clone https://aur.archlinux.org/yay.git; \
		cd ~/etc/build/yay && env PATH="$$HOME/.cargo/bin:$$PATH" makepkg -si --noconfirm --needed; \
	else echo "yay already installed."; fi

install-paru: ~/etc/build rustup
	@echo "Installing paru..."
	sudo pacman -S --needed --noconfirm base-devel git clang cmake make gcc pkgconf
	@if ! command -v paru >/dev/null 2>&1; then \
		export PATH="$$HOME/.cargo/bin:$$PATH"; \
		rustup install stable --quiet --profile minimal --component rustfmt clippy; \
		rustup default stable; \
		cd ~/etc/build && git clone https://aur.archlinux.org/paru.git; \
		cd ~/etc/build/paru && env PATH="$$HOME/.cargo/bin:$$PATH" makepkg -si --noconfirm --needed; \
	else echo "paru already installed."; fi

add-pacman-repositories:
	@echo "Adding pacman repositories..."
	cat pacman_repositories.txt | sudo tee -a /etc/pacman.conf

install-aur-packages: install-yay
	@echo "Installing AUR packages..."
	yay -S --needed --noconfirm - < aur_packages.txt

install-packages:
	@echo "Installing packages..."
	sudo pacman --needed -S - < pacman_packages.txt

### File system scaffold
user-fs: $(DIRS)
	@echo "Create user fs..."

$(DIRS):
	mkdir -p $@

### Updates
update-src:
	@echo "Update src..."
	@if [ -f ./scripts/git_update.sh ] && [ -f ~/etc/src_repositories.txt ]; then \
		chmod +x ./scripts/git_update.sh; \
		./scripts/git_update.sh ~/src ~/etc/src_repositories.txt || true; \
	else echo "Warning: src update skipped (missing script or repo list)."; fi

update-libs:
	@echo "Update libs..."
	@if [ -f ./scripts/git_update.sh ] && [ -f ~/etc/lib_repositories.txt ]; then \
		chmod +x ./scripts/git_update.sh; \
		./scripts/git_update.sh ~/lib ~/etc/lib_repositories.txt || true; \
	else echo "Warning: libs update skipped (missing script or repo list)."; fi

update-zsh-plugins: ~/.zplug
	@echo "Updating zsh plugins..."
	@if [ -f ./scripts/zsh-update.sh ]; then \
		chmod +x ./scripts/zsh-update.sh; \
		./scripts/zsh-update.sh || true; \
	else echo "Warning: Missing ./scripts/zsh-update.sh"; fi

### Editors
init-vim: ~/.vim/autoload/plug.vim
	@echo "Initialize Vim..."
	vim -c "exec InstallAndExit()"

update-vim: ~/.vim/autoload/plug.vim
	@echo "Updating Vim packages..."
	vim -c "exec UpdateAndExit()"

~/.vim/autoload/plug.vim:
	curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

### Linking
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
	@if [ -n "$(LOCAL)" ]; then \
		stow -R -t ~ -d local/$(HOST)/conf $(LOCAL) 2>&1 | grep -v "BUG in find_stowed_path" || true; \
	else echo "No local config found for host $(HOST), skipping..."; fi

### Shell
set-shell:
	@echo "Setting shell to zsh..."
	-chsh -s `which zsh`

### Tmux
update-tmux: ~/.tmux/plugins/tpm
	@echo "Updating tmux plugins..."
	@if [ -x ~/.tmux/plugins/tpm/bin/update_plugins ]; then \
		~/.tmux/plugins/tpm/bin/update_plugins all || true; \
	else echo "Warning: TPM not initialized, skipping tmux update."; fi

~/.tmux/plugins/tpm:
	@echo "Initialize tmux..."
	@mkdir -p $(@D)
	-@git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm && ~/.tmux/plugins/tpm/bin/install_plugins

### Backup originals
save-originals:
	mkdir -p ~/backup/original-system-files
	-@mv -f ~/.bash* ~/backup/original-system-files 2>/dev/null || true

### Rust
rustup:
	@echo "Installing Rust toolchain..."
	@if ! command -v rustup >/dev/null 2>&1; then \
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; \
		export PATH="$$HOME/.cargo/bin:$$PATH"; \
	fi
	rustup install stable || true
	rustup default stable || true

update-rust:
	rustup update
