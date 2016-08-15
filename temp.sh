brand="My Software"

# Check that the script is running as root. If not, then prompt for the sudo
# password and re-execute this script with sudo.
if [ "$(id -nu)" != "root" ]; then
    sudo -k
    pass=$(whiptail --backtitle "$brand Installer" --title "Authentication required" --passwordbox "Installing $brand requires administrative privilege. Please authenticate to begin the installation.\n\n[sudo] Password for user $USER:" 12 50 3>&2 2>&1 1>&3-)
    exec sudo -S -p '' "$0" "$@" <<< "$pass"
    exit 1
fi
