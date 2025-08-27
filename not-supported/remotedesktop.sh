#!/bin/bash

# T&M Hansson IT AB © - 2024, https://www.hanssonit.se/
# Copyright © 2021 Simon Lindner (https://github.com/szaimen)

true
SCRIPT_NAME="Remotedesktop"
SCRIPT_EXPLAINER="This script simplifies the installation of XRDP which allows you to connect via RDP from other devices \
and offers some additional applications that you can choose to install."
# shellcheck source=lib.sh
source /var/scripts/fetch_lib.sh

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

# Check if root
root_check

# Don't run this script as root user, because we will need the account
if [ -z "$UNIXUSER" ]
then
    msg_box "Please don't run this script as pure root user!"
    exit 1
fi

# Check if xrdp is installed
if ! is_this_installed xrdp
then
    # Ask for installing
    install_popup "$SCRIPT_NAME"
    XRDP_INSTALL=1

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
            apt-get update -q4 & spinner_loading
            apt-get install gnome-session --no-install-recommends -y
            sudo -u "$UNIXUSER" dbus-launch gsettings set org.gnome.desktop.wm.preferences button-layout ":minimize,maximize,close"
            sudo -u "$UNIXUSER" dbus-launch gsettings set org.gnome.desktop.interface enable-animations false
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

    # Allow to power off by pressing the power button
    install_if_not acpid
    mkdir -p /etc/acpi/events
    cat << POWER > /etc/acpi/events/power
event=button/power
action=/sbin/poweroff
POWER
    print_text_in_color "$ICyan" "Waiting for acpid to restart..."
    sleep 5
    check_command systemctl restart acpid

    # Create plex user
    if ! id plex &>/dev/null
    then
        check_command adduser --no-create-home --quiet --disabled-login --force-badname --gecos "" "plex"
    fi

    # Add the user to the www-data and plex group to be able to write to all disks
    usermod --append --groups www-data,plex "$UNIXUSER"

    # Add firewall rule
    ufw allow 3389/tcp comment Remotedesktop &>/dev/null

    # Inform the user
    msg_box "XRDP was successfully installed. 
You should be able to connect via an RDP client with your server \
using the credentials of $UNIXUSER and the server ip-address $ADDRESS"
fi

# Needed to be able to access Nextcloud via localhost directly
nextcloud_occ_no_check config:system:delete trusted_proxies "11"

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

# grsync
if is_this_installed grsync
then
    GRSYNC_SWITCH=OFF
else
    GRSYNC_SWITCH=ON
fi

# MakeMKV
if is_this_installed makemkv-oss || is_this_installed makemkv-bin
then
    MAKEMKV_SWITCH=OFF
else
    MAKEMKV_SWITCH=ON
fi

# OnlyOffice
if is_this_installed onlyoffice-desktopeditors
then
    ONLYOFFICE_SWITCH=OFF
else
    ONLYOFFICE_SWITCH=ON
fi

# Picard
if is_this_installed picard
then
    PICARD_SWITCH=OFF
else
   PICARD_SWITCH=ON
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
"Eye of Gnome" "(Image Viewer)" "$EOG_SWITCH" \
"Firefox" "(Internet Browser)" "$FIREFOX_SWITCH" \
"Gedit" "(Text Editor)" "$GEDIT_SWITCH" \
"Grsync" "(File sync)" "$GRSYNC_SWITCH" \
"MakeMKV" "(Rip DVDs and Blu-rays)" "$MAKEMKV_SWITCH" \
"Nautilus" "(File Manager)" "$NAUTILUS_SWITCH" \
"OnlyOffice" "(Open Source Office Suite)" "$ONLYOFFICE_SWITCH" \
"Picard" "(Music tagger)" "$PICARD_SWITCH" \
"Sound Juicer" "(Rip CDs)" "$SJ_SWITCH" \
"VLC" "(Play Videos and Audio)" "$VLC_SWITCH" \
"XRDP" "(Uninstall XRDP and all listed desktop apps)" OFF 3>&1 1>&2 2>&3)

# Function for installing or removing packets
install_remove_packet() {
    if is_this_installed "$1"
    then
        print_text_in_color "$ICyan" "Uninstalling $2"
        apt-get purge "$1" -y
        if [ "$1" = "grsync" ]
        then
            apt-get purge gnome-themes-extra -y
        fi
        apt-get autoremove -y
        if [ "$1" = "nautilus" ]
        then
            rm -f /home/"$UNIXUSER"/.local/share/applications/org.gnome.Nautilus.desktop
            rm -f /home/"$UNIXUSER"/.config/gtk-3.0/bookmarks
        fi
        print_text_in_color "$ICyan" "$2 was successfully uninstalled."
    else
        print_text_in_color "$ICyan" "Installing $2"
        install_if_not "$1"
        # Settings for nautilus
        if [ "$1" = "nautilus" ]
        then
            mkdir -p /home/"$UNIXUSER"/.local/share/applications/
            cp /usr/share/applications/org.gnome.Nautilus.desktop /home/"$UNIXUSER"/.local/share/applications/
            sed -i 's|^Exec=nautilus.*|Exec=nautilus --new-window /mnt|' /home/"$UNIXUSER"/.local/share/applications/org.gnome.Nautilus.desktop
            sed -i 's|DBusActivatable=true|# DBusActivatable=true|' /home/"$UNIXUSER"/.local/share/applications/org.gnome.Nautilus.desktop
            chmod +x /home/"$UNIXUSER"/.local/share/applications/org.gnome.Nautilus.desktop
            mkdir -p /home/"$UNIXUSER"/.config/gtk-3.0
            echo "file:///mnt" > /home/"$UNIXUSER"/.config/gtk-3.0/bookmarks
            chmod 664 /home/"$UNIXUSER"/.config/gtk-3.0/bookmarks
            chown -R "$UNIXUSER":"$UNIXUSER" /home/"$UNIXUSER"
        elif [ "$1" = "vlc" ]
        then
            sudo sed -i 's|geteuid|getppid|' /usr/bin/vlc
        elif [ "$1" = "grsync" ]
        then
            install_if_not gnome-themes-extra
        fi
        print_text_in_color "$ICyan" "$2 was successfully installed"
    fi
}

case "$choice" in
    *"XRDP"*)
        SUBTITLE="XRDP"
        msg_box "This option will uninstall XRDP and all other desktop applications from this list \
as well as the gnome desktop." "$SUBTITLE"
        if yesno_box_no "Do you want to do this?" "$SUBTITLE"
        then
            APPS=(evince eog firefox gedit grsync gnome-themes-extra makemkv-oss makemkv-bin nautilus onlyoffice-desktopeditors \
picard sound-juicer vlc acpid gnome-shell-extension-dash-to-panel gnome-shell-extension-arc-menu gnome-session xrdp)
            for app in "${APPS[@]}"
            do
                if is_this_installed "$app"
                then
                    apt-get purge "$app" -y
                fi
            done
            apt-get autoremove -y
            systemctl set-default multi-user
            add-apt-repository --remove ppa:heyarje/makemkv-beta -y
            apt-get update -q4 & spinner_loading
            rm -f /etc/polkit-1/localauthority/50-local.d/46-allow-update-repo.pkla
            rm -f /etc/polkit-1/localauthority/50-local.d/allow-update-repo.pkla
            rm -f /etc/polkit-1/localauthority/50-local.d/color.pkla
            rm -f /home/"$UNIXUSER"/.local/share/applications/org.gnome.Nautilus.desktop
            rm -f /home/"$UNIXUSER"/.config/gtk-3.0/bookmarks
            ufw delete allow 3389/tcp &>/dev/null
            msg_box "XRDP and all desktop applications were successfully uninstalled." "$SUBTITLE"
            exit
        fi
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
    *"Grsync"*)
        install_remove_packet grsync Grsync
    ;;&
    *"MakeMKV"*)
        SUBTITLE="MakeMKV"
        if is_this_installed makemkv-oss || is_this_installed makemkv-bin
        then
            print_text_in_color "$ICyan" "Uninstalling $SUBTITLE"
            apt-get purge makemkv-oss -y
            apt-get purge makemkv-bin -y
            apt-get autoremove -y
            add-apt-repository --remove ppa:heyarje/makemkv-beta -y
            apt-get update -q4 & spinner_loading
            print_text_in_color "$ICyan" "$SUBTITLE was successfully uninstalled."
        else
            msg_box "MakeMKV is not open source. This is their official website: makemkv.com
We will need to add a 3rd party repository to install it which can set your server under risk." "$SUBTITLE"
            if yesno_box_yes "Do you want to install MakeMKV nonetheless?" "$SUBTITLE"
            then
                print_text_in_color "$ICyan" "Installing $SUBTITLE"
                if add-apt-repository ppa:heyarje/makemkv-beta -y
                then
                    apt-get update -q4 & spinner_loading
                    apt-get install makemkv-oss makemkv-bin -y
                    print_text_in_color "$ICyan" "$SUBTITLE was successfully installed"
                else
                    msg_box "Something failed while trying to add the new repository" "$SUBTITLE"
                fi
            fi
        fi
        unset SUBTITLE
    ;;&
    *"Nautilus"*)
        install_remove_packet nautilus Nautilus
    ;;&
    *"OnlyOffice"*)
        SUBTITLE="OnlyOffice"
        if is_this_installed onlyoffice-desktopeditors
        then
            print_text_in_color "$ICyan" "Uninstalling $SUBTITLE"
            apt-get purge onlyoffice-desktopeditors -y
            apt-get autoremove -y
            rm -f /etc/apt/sources.list.d/onlyoffice-desktopeditors.list
            apt-get update -q4 & spinner_loading
            print_text_in_color "$ICyan" "$SUBTITLE was successfully uninstalled."
        else
            msg_box "OnlyOffice Desktop Editors are open source but not existing in the Ubuntu repositories.
Hence, we will add a 3rd-party repository to your server \
to be able to install and update OnlyOffice Desktop Editors using the apt packet manager.
This can set your server under risk, though!" "$SUBTITLE"
            if yesno_box_yes "Do you want to install OnlyOffice Desktop Editors nonetheless?" "$SUBTITLE"
            then
                print_text_in_color "$ICyan" "Installing $SUBTITLE"
                # From https://helpcenter.onlyoffice.com/installation/desktop-install-ubuntu.aspx
                mkdir -p ~/.gnupg
                gpg --no-default-keyring --keyring gnupg-ring:/tmp/onlyoffice.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys CB2DE8E5
                chmod 644 /tmp/onlyoffice.gpg
                chown root:root /tmp/onlyoffice.gpg
                mv /tmp/onlyoffice.gpg /usr/share/keyrings/onlyoffice.gpg
                echo "deb [signed-by=/usr/share/keyrings/onlyoffice.gpg] https://download.onlyoffice.com/repo/debian squeeze main" > "/etc/apt/sources.list.d/onlyoffice-desktopeditors.list"
                apt-get update -q4 & spinner_loading
                install_if_not onlyoffice-desktopeditors
                print_text_in_color "$ICyan" "$SUBTITLE was successfully installed"
            fi
        fi
        unset SUBTITLE
    ;;&
    *"Picard"*)
        install_remove_packet picard Picard
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
