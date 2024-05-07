#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/

true
SCRIPT_NAME="BPYTOP"
SCRIPT_EXPLAINER="BPYTOP is an amazing alternative to resource-monitor software like top or htop."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Must be root
root_check

# Needed for snaps to run
install_if_not snapd

# Check if bpytop is already installed
if ! snap list | grep -q bpytop
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
else
    # Ask for removal or reinstallation
    reinstall_remove_menu "$SCRIPT_NAME"
    # Removal
    if [ -f /home/"$UNIXUSER"/.bash_aliases ]
    then
        sed -i "s|.*bpytop'||g" /home/"$UNIXUSER"/.bash_aliases
    fi
    if [ -f /root/.bash_aliases ]
    then
        sed -i "s|.*bpytop'||g" /root/.bash_aliases
    fi
    snap remove bpytop
    # Show successful uninstall if applicable
    removal_popup "$SCRIPT_NAME"
fi

# Install it!
if snap install bpytop
then
    snap connect bpytop:mount-observe
    snap connect bpytop:network-control
    snap connect bpytop:hardware-observe
    snap connect bpytop:system-observe
    snap connect bpytop:process-control
    snap connect bpytop:physical-memory-observe
    hash -r
    msg_box "BPYTOP is now installed! Check out the amazing stats by running 'bpytop' from your CLI.
You can check out their Github repo here: https://github.com/aristocratos/bpytop/blob/master/README.md"
    # Ask for aliases
    if yesno_box_yes "Would you like to add an alias for bpytop to replace both htop and top?"
    then
        echo "alias top='bpytop'" >> /root/.bash_aliases
        echo "alias htop='bpytop'" >> /root/.bash_aliases
        if [ -d /home/"$UNIXUSER" ]
        then
            touch /home/"$UNIXUSER"/.bash_aliases
            chown "$UNIXUSER":"$UNIXUSER" /home/"$UNIXUSER"/.bash_aliases
            echo "alias top='bpytop'" >> /home/"$UNIXUSER"/.bash_aliases
            echo "alias htop='bpytop'" >> /home/"$UNIXUSER"/.bash_aliases
        fi
        msg_box "Alias for bpytop is now set! You can now type both 'htop' and 'top' in your CLI to use bpytop."
    fi
else
    msg_box "It seems like the installation of BPYTOP failed. Please try again."
fi
