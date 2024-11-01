#!/bin/bash

FIREFOX_THEME_URL = "https://raw.githubusercontent.com/rafaelmardojai/firefox-gnome-theme/master/scripts/install-by-curl.sh"

FLATPAK_LIST_URL = "https://syssetup.jonasjones.dev/flatpaks"
PACKAGES_LIST_URL = "https://syssetup.jonasjones.dev/packages"
GEXTENSIONS_LIST_URL = "https://syssetup.jonasjones.dev/gextensions"

# Check for --help argument
if [[ "$1" == "--help" || "$2" == "--help" ]]; then
    echo "Usage: ./script_name.sh [user]"
    echo ""
    echo "Optional Arguments:"
    echo "  user            user under which to install everything (default: $USER)"
    echo "  --help          Display this help message"
    exit 0
fi

logger() {
    local message="$1"
    echo -e "\e[32m$message\e[0m"
}

# welcome message
logger "Welcome to the system setup script!"
logger "This script will install a bunch of packages, flatpaks, gnome extensions, and more."

# Keep the sudo session alive
logger "Requesting sudo session..."
while true; do sudo -v; sleep 60; done &


download_file() {
    local url="$1"
    local filename="$2"

    # Download the file
    if curl -s -o "$filename" "$url"; then
        logger "Downloaded successfully: $filename"
    else
        logger "Error: Failed to download from $url" >&2
        exit 1
    fi
}


install_gextension() {
    local i="$1"
    VERSION_TAG=$(curl -Lfs "https://extensions.gnome.org/extension-query/?search=${i}" | jq '.extensions[0] | .shell_version_map | map(.pk) | max')
    wget -O ${i}.zip "https://extensions.gnome.org/download-extension/${i}.shell-extension.zip?version_tag=$VERSION_TAG"
    gnome-extensions install --force ${i}.zip
    if ! gnome-extensions list | grep --quiet ${i}; then
        busctl --user call org.gnome.Shell.Extensions /org/gnome/Shell/Extensions org.gnome.Shell.Extensions InstallRemoteExtension s ${i}
    fi
    gnome-extensions enable ${i}
    rm ${i}.zip
}


install_yay_aur() {
    sudo pacman -Syyu yay --noconfirm
}

change_pacman_config() {
    # Change the pacman config to make it colorful
    sudo sed -i 's/#Color/Color/g' /etc/pacman.conf
    sudo sed -i 's/#TotalDownload/TotalDownload/g' /etc/pacman.conf
    sudo sed -i 's/#VerbosePkgLists/VerbosePkgLists/g' /etc/pacman.conf
    sudo sed -i 's/#ParallelDownloads/ParallelDownloads/g' /etc/pacman.conf
    sudo sed -i '/ParallelDownloads/a ILoveCandy' /etc/pacman.conf
}

install_chaoticaur() {
    sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    sudo pacman-key --lsign-key 3056513887B78AEB
    sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' --noconfirm
    sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' --noconfirm
    logger "Appending to /etc/pacman.conf..."

    if ! grep -q '\[chaotic-aur\]' /etc/pacman.conf; then
        echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf > /dev/null
        logger "Successfully appended to /etc/pacman.conf."
    else
        logger "[chaotic-aur] section already exists in /etc/pacman.conf."
    fi
}

remove_packages() {
    # remove some unwanted gnome apps
    sudo pacman -Rns \
    gnome-contacts \
    gnome-weather \
    gnome-clocks \
    gnome-maps \
    gnome-tour \
    gnome-connections \
    gnome-music \
    gnome-console \
    gnome-calendar \
    gnome-text-editor \
    --noconfirm
}

install_firefox_theme() {
    # Command from the firefrox theme github page
    curl -s -o- $FIREFOX_THEME_URL | bash
}

install_sdkman() {
    # Command from the sdkman website
    curl -s "https://get.sdkman.io" | bash
    source "$HOME/.sdkman/bin/sdkman-init.sh"
    sdk install java 21.0.3-oracle
}

install_ghcup() {
    # Command from the ghcup website
    curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
}

install_flatpaks() {
    # Install flatpak package
    sudo pacman -S flatpak --noconfirm

    # Download flatpak list
    download_file $FLATPAK_LIST_URL "flatpaks.txt"

    # Install the flatpaks
    flatpak install --noninteractive --assumeyes - < flatpaks.txt

    # Remove the flatpaks file
    rm flatpaks.txt
}

install_packages() {
    # Download the packages list
    download_file $PACKAGES_LIST_URL "packages.txt"

    # Install the packages
    yay -S --noconfirm - < packages.txt

    # remove the packages file
    rm packages.txt
}

install_gnome_extensions() {
    # download the gnome extensions list
    download_file $GEXTENSIONS_LIST_URL "gextensions.txt"

    # Install the gnome extensions
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            install_gextension "$line"
        fi
    done < gextensions.txt

    # Remove the gnome extensions file
    rm gextensions.txt
}

# run the commands
logger "Changing pacman config..."
change_pacman_config
logger "Installing Chaotic AUR..."
install_chaoticaur
logger "Installing yay AUR helper..."
install_yay_aur
logger "Installing system packages..."
install_packages
logger "Installing flatpaks..."
install_flatpaks
logger "Installing firefox theme..."
install_firefox_theme
logger "Installing sdkman..."
install_sdkman
logger "Installing ghcup..."
install_ghcup
logger "Removing unwanted gnome apps..."
remove_packages
logger "Installing gnome extensions..."
install_gnome_extensions

