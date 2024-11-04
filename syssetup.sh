#!/bin/bash

FIREFOX_THEME_URL="https://raw.githubusercontent.com/rafaelmardojai/firefox-gnome-theme/master/scripts/install-by-curl.sh"

FLATPAK_LIST_URL="https://syssetup.jonasjones.dev/flatpaks"
PACKAGES_LIST_URL="https://syssetup.jonasjones.dev/packages"
GEXTENSIONS_LIST_URL="https://syssetup.jonasjones.dev/gextensions"

FONT_URL="https://download.jetbrains.com/fonts/JetBrainsMono-2.304.zip"
TEMP_DIR=$(mktemp -d)
FONT_DIR="$HOME/.fonts"
TTF_DIR="$TEMP_DIR/fonts/ttf"
DEFAULT_FONT="JetBrainsMonoNL-Bold.ttf"

ICONPACK_URL="https://github.com/zayronxio/Mkos-Big-Sur/releases/download/0.3/Mkos-Big-Sur.tar.xz"
TEMP_DIR=$(mktemp -d)
ICON_DIR="$HOME/.icons"
ICONPACK_NAME="Mkos-Big-Sur"

WALLPAPER_URL="https://raw.githubusercontent.com/JonasunderscoreJones/ArchSystemSetup/refs/heads/main/wallpaper.jpg"
WALLPAPER_PATH="$HOME/Pictures/wallpaper.jpg"

logger() {
    local message="$1"
    echo -e "\e[32m$message\e[0m"
}


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

    # Get the version tag
    VERSION_TAG=$(curl -Lfs "https://extensions.gnome.org/extension-query/?search=${i}")
    if [ $? -ne 0 ]; then
        logger "ERROR: Failed to fetch version tag for ${i}" >> error.log
        return 1  # Continue to the next steps, but log the error
    fi

    # Extract the version tag using jq
    VERSION_TAG=$(echo """$VERSION_TAG""" | jq '.extensions[0].shell_version_map | to_entries | max_by(.key | tonumber) | .value.version')
    logger $VERSION_TAG

    # Download the extension zip file
    wget -O "${i}.zip" "https://extensions.gnome.org/extension-data/${i}.${VERSION_TAG}.shell-extension.zip"
    if [ $? -ne 0 ]; then
        logger "ERROR: Failed to download ${i}.zip" >> error.log
        return 1  # Continue to the next steps, but log the error
    fi

    # Install the extension
    gnome-extensions install --force "${i}.zip"
    if ! gnome-extensions list | grep --quiet "${i}"; then
        busctl --user call org.gnome.Shell.Extensions /org/gnome/Shell/Extensions org.gnome.Shell.Extensions InstallRemoteExtension s "${i}"
    fi

    # Enable the extension
    gnome-extensions enable "${i}"

    # Clean up
    rm "${i}.zip"
}

add_wifi_network() {
    local SSID="$1"
    local PASSWORD="$2"

    # Check if NetworkManager is running
    if ! systemctl is-active --quiet NetworkManager; then
        echo "NetworkManager is not running. Starting it now..."
        sudo systemctl start NetworkManager
    fi

    # Add Wi-Fi connection
    nmcli dev wifi connect "$SSID" password "$PASSWORD"

    # Check if the connection was successful
    if [ $? -eq 0 ]; then
        echo "Successfully connected to $SSID."
    else
        echo "Failed to connect to $SSID. Wifi may be out of range."
    fi
}


add_wifi_networks() {
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            IFS=',' read -r ssid password <<< "$line"
            add_wifi_network "$ssid" "$password"
        fi
    done < networks.txt

}

install_fonts() {
    # Create the font directory if it doesn't exist
    mkdir -p "$FONT_DIR"

    # Download the font zip file
    logger "Downloading JetBrains Mono font..."
    curl -L -o "$TEMP_DIR/JetBrainsMono.zip" "$FONT_URL"

    # Unzip the downloaded file
    logger "Unzipping the font..."
    unzip -q "$TEMP_DIR/JetBrainsMono.zip" -d "$TEMP_DIR"

    # Move TTF fonts to the user's font directory
    logger "Moving TTF fonts to $FONT_DIR..."
    mv "$TTF_DIR"/*.ttf "$FONT_DIR"

    # Clean up temporary files
    rm -rf "$TEMP_DIR"

    # Update the font cache
    logger "Updating font cache..."
    fc-cache -fv "$FONT_DIR"

    # Set JetBrainsMonoNL-Bold.ttf as the default font for applications (example for GTK)
    # You may need to adjust this part based on your specific environment or applications
    logger "Setting $DEFAULT_FONT as the default font..."
    # This command will vary depending on your desktop environment
    # Here's an example for GTK:
    gsettings set org.gnome.desktop.interface font-name "JetBrains Mono 10"

    logger "Font installation and configuration completed."
}

install_icon_pack() {
    # Create the icons directory if it doesn't exist
    mkdir -p "$ICON_DIR"

    # Download the icon pack
    logger "Downloading Mkos Big Sur icon pack..."
    curl -L -o "$TEMP_DIR/Mkos-Big-Sur.tar.xz" "$ICONPACK_URL"

    # Extract the downloaded icon pack
    logger "Extracting the icon pack..."
    tar -xf "$TEMP_DIR/Mkos-Big-Sur.tar.xz" -C "$TEMP_DIR"

    # Move the extracted icons to the user's icons directory
    logger "Moving icons to $ICON_DIR..."
    mv "$TEMP_DIR/$ICONPACK_NAME" "$ICON_DIR"

    # Clean up temporary files
    rm -rf "$TEMP_DIR"

    # Set the icon theme using gsettings
    logger "Setting $ICONPACK_NAME as the default icon theme..."
    gsettings set org.gnome.desktop.interface icon-theme "$ICONPACK_NAME"

    # Inform the user
    logger "Icon pack installation completed."
}


change_gnome_settings() {
    # Add minimize and maximize buttons to the window title bar
    logger "Adding minimize and maximize buttons to the window title bar..."
    gsettings set org.gnome.desktop.wm.preferences button-layout '":minimize,maximize,close"'

    # Enable resizing with the right mouse button
    logger "Enabling resizing with the right mouse button..."
    gsettings set org.gnome.desktop.wm.preferences resize-with-right-button true

    # Set the clock format to show the date and 24-hour time
    logger "Setting the clock format to show the date and 24-hour time..."
    gsettings set org.gnome.desktop.interface clock-format '24h'

    # Configure window movement shortcuts
    logger "Setting up window movement shortcuts..."
    gsettings set org.gnome.settings-daemon.plugins.media-keys move-to-workspace-left '["<Shift><Super>Page_Down"]'
    gsettings set org.gnome.settings-daemon.plugins.media-keys move-to-workspace-right '["<Shift><Super>Page_Up"]'

    # Disable application switcher shortcut
    logger "Disabling application switcher shortcut..."
    gsettings set org.gnome.settings-daemon.plugins.media-keys app-switch '[]'

    # Set Alt+Tab for window switching
    logger "Setting Alt+Tab for window switching..."
    gsettings set org.gnome.settings-daemon.plugins.media-keys window-switch '["<Alt>Tab"]'

    # Configure media control shortcuts
    logger "Configuring media control shortcuts..."
    gsettings set org.gnome.settings-daemon.plugins.media-keys next '["<Shift>F12"]'
    gsettings set org.gnome.settings-daemon.plugins.media-keys play-pause '["<Shift>F11"]'
    gsettings set org.gnome.settings-daemon.plugins.media-keys previous '["<Shift>F10"]'

    # Set Ctrl+Q to close windows
    logger "Setting Ctrl+Q to close windows..."
    gsettings set org.gnome.settings-daemon.plugins.media-keys close '["<Ctrl>q"]'

    # Show battery percentage
    logger "Showing battery percentage..."
    gsettings set org.gnome.desktop.interface show-battery-percentage true

    # Enable automatic suspend only on battery power
    logger "Setting automatic suspend only on battery..."
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 30 # You can adjust the timeout as needed

    # Enable dark mode
    logger "Enabling dark mode..."
    gsettings set org.gnome.desktop.interface gtk-theme 'Yaru-dark' # Adjust to your preferred dark theme

    # Set touchpad scroll direction to traditional
    logger "Setting touchpad scroll direction to traditional..."
    gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll false

    # Set keyboard layout to English (US, intl with dead keys)
    logger "Setting keyboard layout to English (US, intl with dead keys)..."
    gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us:intl')]"

    # Provide feedback
    echo "All configurations have been applied."
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
    while read -r flatpak_id; do
        [[ -n "$flatpak_id" ]] && flatpak install --noninteractive --assumeyes "$flatpak_id"
    done < flatpaks.txt
    #flatpak install --noninteractive --assumeyes < flatpaks.txt

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

# Check if the script is sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Check for --help argument
    if [[ "$1" == "--help" || "$2" == "--help" ]]; then
        echo "Usage: ./script_name.sh [user]"
        echo ""
        echo "Optional Arguments:"
        echo "  user            user under which to install everything (default: $USER)"
        echo "  --help          Display this help message"
        exit 0
    fi

    # welcome message
    logger "Welcome to the system setup script!"
    logger "This script will install a bunch of packages, flatpaks, gnome extensions, and more."

    # Keep the sudo session alive
    logger "Requesting sudo session..."
    while true; do sudo -v; sleep 60; done &

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
    logger "Adding wifi networks..."
    add_wifi_networks
    logger "Installing fonts..."
    install_fonts
    logger "Installing icon pack..."
    install_icon_pack
    logger "Changing gnome settings..."
    change_gnome_settings
else
    logger "Sourcing the script..."
fi



