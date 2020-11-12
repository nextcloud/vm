#!/bin/bash

# T&M Hansson IT AB © - 2020, https://www.hanssonit.se/
# Copyright © 2020 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="Remotedesktop"
SCRIPT_EXPLAINER="This script simplifies the installation of XRDP which allows you to connect via RDP from other devices \
and offers some additional applications that you can choose to install."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh || source <(curl -sL https://raw.githubusercontent.com/nextcloud/vm/master/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Check if xrdp is installed
if ! is_this_installed xrdp
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
    XRDP_INSTALL=1
    
    # Don't run this script as root user, because we will need the account
    if [ -z "$UNIXUSER" ]
    then
        msg_box "Please don't run this script as pure root user!"
        exit 1
    fi

    # Check if gnome-session is installed
    if ! is_this_installed gnome-session 
    then
        msg_box "To make xrdp work, you will need to install a desktop environment.
We've chosen the Gnome desktop in a minimal install.
If you have already installed a desktop environment, you will not need to install it."
        if yesno_box_yes "Do you want to install the Gnome desktop?"
        then
            # Install gnome-session
            print_text_in_color "$ICyan" "Installing gnome-session..."
            install_if_not gnome-session
            install_if_not gnome-shell-extension-dash-to-panel
            check_command sudo -u "$UNIXUSER" dbus-launch gnome-extensions enable dash-to-panel@jderose9.github.com
        fi
    fi
    
    # Install xrdp
    print_text_in_color "$ICyan" "Installing xrdp..."
    install_if_not xrdp
    adduser xrdp ssl-cert

    # Make sure that you don't get prompted with a password request after login
    cat << DESKTOP_CONF > /etc/polkit-1/localauthority/50-local.d/allow-update-repo.pkla
[Allow Package Management all Users]
Identity=unix-user:*
Action=org.freedesktop.packagekit.system-sources-refresh
ResultAny=yes
ResultInactive=yes
ResultActive=yes
DESKTOP_CONF
    cat << DESKTOP_CONF > /etc/polkit-1/localauthority/50-local.d/color.pkla
[Allow colord for all users]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
ResultAny=yes
ResultInactive=yes
ResultActive=yes
DESKTOP_CONF

    print_text_in_color "$ICyan" "Waiting for xrdp to restart..."
    sleep 5
    check_command systemctl restart xrdp

    # Allow to poweroff by pressing the powerbutton
    install_if_not acpid
    mkdir -p /etc/acpi/events
    cat << POWER > /etc/acpi/events/power
event=button/power
action=/sbin/poweroff
POWER
    print_text_in_color "$ICyan" "Waiting for acpid to restart..."
    sleep 5
    check_command systemctl restart acpid

    # Add the user to the www-data group to be able to write to all disks
    usermod -a -G www-data "$UNIXUSER"

    # Inform the user
    msg_box "XRDP was successfuly installed. 
You should be able to connect via an RDP client with your server \
using the credentials of $UNIXUSER and the server ip-address $ADDRESS"
fi

# Evince
if is_this_installed evince
then
    EVINCE_SWTICH=OFF
else
    EVINCE_SWTICH=ON
fi

# Eye of Gnome
if is_this_installed eog
then
    EOG_SWITCH=OFF
else
    EOG_SWITCH=ON
fi

# Firefox
if is_this_installed firefox
then
    FIREFOX_SWITCH=OFF
else
    FIREFOX_SWITCH=ON
fi

# Gedit
if is_this_installed gedit
then
    GEDIT_SWITCH=OFF
else
    GEDIT_SWITCH=ON
fi

# MakeMKV
if is_this_installed makemkv-oss || is_this_installed makemkv-bin
then
    MAKEMKV_SWITCH=OFF
else
    MAKEMKV_SWITCH=ON
fi

# File manager nautilus
if is_this_installed nautilus
then
    NAUTILUS_SWITCH=OFF
else
    NAUTILUS_SWITCH=ON
fi

# Sound Juicer
if is_this_installed sound-juicer
then
    SJ_SWITCH=OFF
else
    SJ_SWITCH=ON
fi

# VLC
if is_this_installed vlc
then
    VLC_SWITCH=OFF
else
    VLC_SWITCH=ON
fi

# Create a menu with desktop apps
choice=$(whiptail --title "$TITLE" --checklist \
"This menu lets you install pre-chosen desktop apps.
It is smart and has selected only options that are not yet installed.
Choose which ones you want to install.
If you select apps that are already installed you will have the choice to uninstall them.
$CHECKLIST_GUIDE" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Evince" "(PDF Viewer)" "$EVINCE_SWTICH" \
"Eye of Gnome" "(Image Viewer)" "$EOG_SWITCH" \
"Firefox" "(Internet Browser)" "$FIREFOX_SWITCH" \
"Gedit" "(Text Editor)" "$GEDIT_SWITCH" \
"MakeMKV" "(Rip DVDs and Blu-rays)" "$MAKEMKV_SWITCH" \
"Nautilus" "(File Manager)" "$NAUTILUS_SWITCH" \
"Sound Juicer" "(Rip CDs)" "$SJ_SWITCH" \
"VLC" "(Play Videos and Audio)" "$VLC_SWITCH" \
"XRDP" "(Uninstall XRDP and all listed desktop apps)" OFF 3>&1 1>&2 2>&3)

# Function for installing or removing packets
install_remove_packet() {
    local SUBTITLE="$2"
    if is_this_installed "$1"
    then
        if yesno_box_yes "It seems like $2 is already installed.\nDo you want to uninstall it?" "$SUBTITLE"
        then
            apt purge "$1" -y
            apt autoremove -y
            msg_box "$2 was successfully uninstalled." "$SUBTITLE"
        fi
    else
        if yesno_box_yes "Do you want to install $2?" "$SUBTITLE"
        then
            install_if_not "$1"
            msg_box "$2 was successfully installed." "$SUBTITLE"
        fi
    fi
}

case "$choice" in
    *"XRDP"*)
        SUBTITLE="XRDP"
        msg_box "This option will uninstall XRDP and all other desktop applications from this list \
as well as the gnome desktop." "$SUBTITLE"
        if yesno_box_no "Do you want to do this?" "$SUBTITLE"
        then
            APPS=(evince eog firefox gedit makemkv-oss makemkv-bin nautilus sound-juicer vlc \
gnome-shell-extension-dash-to-panel gnome-session xrdp)
            for app in "${APPS[@]}"
            do
                if is_this_installed "$app"
                then
                    apt purge "$app" -y
                fi
            done
            apt autoremove -y
            systemctl set-default multi-user
            add-apt-repository --remove ppa:heyarje/makemkv-beta -y
            apt update -q4 & spinner_loading
            rm -f /etc/polkit-1/localauthority/50-local.d/46-allow-update-repo.pkla
            rm -f /etc/polkit-1/localauthority/50-local.d/allow-update-repo.pkla
            rm -f /etc/polkit-1/localauthority/50-local.d/color.pkla
            msg_box "XRDP and all desktop applications were successfully uninstalled." "$SUBTITLE"
            exit
        fi
    ;;&
    *"Evince"*)
        install_remove_packet evince Evince
    ;;&
    *"Eye of Gnome"*)
        install_remove_packet eog "Eye of Gnome"
    ;;&
    *"Firefox"*)
        install_remove_packet firefox Firefox
    ;;&
    *"Gedit"*)
        install_remove_packet gedit Gedit
    ;;&
    *"MakeMKV"*)
        SUBTITLE="MakeMKV"
        if is_this_installed makemkv-oss || is_this_installed makemkv-bin
        then
            if yesno_box_yes "It seems like MakeMKV is already installed.\nDo you want to uninstall it?" "$SUBTITLE"
            then
                apt purge makemkv-oss -y
                apt purge makemkv-bin -y
                apt autoremove -y
                add-apt-repository --remove ppa:heyarje/makemkv-beta -y
                apt update -q4 & spinner_loading
                msg_box "MakeMKV was successfully uninstalled." "$SUBTITLE"
            fi
        else
            msg_box "MakeMKV is not open source. This is their official website: makemkv.com
We will need to add a 3rd party repository to install it which can set your server under risk." "$SUBTITLE"
            if yesno_box_yes "Do you want to install MakeMKV nonetheless?" "$SUBTITLE"
            then
                if add-apt-repository ppa:heyarje/makemkv-beta
                then
                    apt update -q4 & spinner_loading
                    apt install makemkv-oss makemkv-bin -y
                    msg_box "MakeMKV was successfully installed." "$SUBTITLE"
                fi
            fi
        fi
        unset SUBTITLE
    ;;&
    *"Nautilus"*)
        install_remove_packet nautilus Nautilus
    ;;&
    *"Sound Juicer"*)
        install_remove_packet sound-juicer "Sound Juicer"
    ;;&
    *"VLC"*)
        install_remove_packet vlc VLC
    ;;&
    *)
    ;;
esac

# Allow to reboot if xrdp was just installed because otherwise the usermod won't apply
if [ -n "$XRDP_INSTALL" ]
then
    if yesno_box_yes "Do you want to reboot your server now?
After the initial installation of XRDP it is recommended to reboot the server to apply all settings."
    then
        reboot
    fi
fi

exit
