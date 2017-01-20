#!/bin/sh
# Part of raspi-config https://github.com/RPi-Distro/raspi-config
#
# See LICENSE file for copyright and license details

INTERACTIVE=True
ASK_TO_REBOOT=0

is_live() {
    grep -q "boot=live" $CMDLINE
    return $?
}

get_init_sys() {
  if command -v systemctl > /dev/null && systemctl | grep -q '\-\.mount'; then
    SYSTEMD=1
  elif [ -f /etc/init.d/cron ] && [ ! -h /etc/init.d/cron ]; then
    SYSTEMD=0
  else
    echo "Unrecognised init system"
    return 1
  fi
}

calc_wt_size() {
  # NOTE: it's tempting to redirect stderr to /dev/null, so supress error
  # output from tput. However in this case, tput detects neither stdout or
  # stderr is a tty and so only gives default 80, 24 values
  WT_HEIGHT=17
  WT_WIDTH=$(tput cols)

  if [ -z "$WT_WIDTH" ] || [ "$WT_WIDTH" -lt 60 ]; then
    WT_WIDTH=80
  fi
  if [ "$WT_WIDTH" -gt 178 ]; then
    WT_WIDTH=120
  fi
  WT_MENU_HEIGHT=$(($WT_HEIGHT-7))
}

do_usb() {
	get_init_sys
	whiptail --msgbox "Please use an external power supply (USB HUB) to power your HDD/SSD. This will increase the RPI's performance at peaks.)\n\n All of your data will be deleted if you continue please backup/save your files on the HD/SSD that we are going to use first\n\n Now please connect the HD/SSD to the RPI and make sure its the only storage device (USB keyboard dongle is fine, just no other USB STORAGE or HD's.\n\n Having multiple devices plugged in will mess up the installation and you will have to start over." $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT

# Check if /dev/sda is present
lsblk | grep sda
if [ $? -eq 0 ]; then # yes
# Disable swap file, if it is setup before.
if 		[ -f /swapfile ]; then
      		swapoff -a
      		rm /swapfile
      		sed -i 's|.*swapfile.*||g' /etc/fstab
fi

# Wipe disk and create new partition
DEV="/dev/sda"
DEVHD="/dev/sda2"

fdisk $DEV << EOF
wipefs
EOF

fdisk $DEV << EOF
o
n
p
1

+10M
w
EOF

fdisk $DEV << EOF
n
p
2


w
EOF
sync
partprobe

# Swap
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
echo "/swapfile   none    swap    sw    0   0" >> /etc/fstab
sync
partprobe

# Set cmdline.txt
GDEVHDUUID=$(blkid -o value -s PARTUUID $DEVHD)
mount /dev/mmcblk0p1 /mnt
sed -i "s|root=/dev/mmcblk0p2|root=PARTUUID=$GDEVHDUUID|g" /mnt/cmdline.txt
umount /mnt

# External HD
    {
    i=1
    while read -r line; do
        i=$(( $i + 1 ))
        echo $i
    done < <(echo -ne '\n' | sudo mke2fs -t ext4 -b 4096 -L 'PI_ROOT' $DEVHD)
    } | whiptail --title "Progress" --gauge "Please wait while creating ext4 filesystem" 6 60 0

	sed -i 's|/dev/mmcblk0p2|#/dev/mmcblk0p2|g' /etc/fstab
	echo "PARTUUID=$GDEVHDUUID  /               ext4   defaults,noatime  0       1" >> /etc/fstab
	mount $DEVHD /mnt

clear
echo "Moving from SD to HD/SSD, this can take a while! Sit back and relax..."
echo
rsync -aAXv --exclude={"/boot/*","/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} / /mnt

	touch /var/scripts/HD
	umount /mnt
	sed -e '10,31d' /root/.profile
	whiptail --msgbox "Success, we will now reboot to finish switching /root..." 20 60 1
	reboot
else
	 whiptail --msgbox "Could not detect external storage, please start over..." 20 60 1
fi
}

do_expand_rootfs() {
  get_init_sys
  if [ $SYSTEMD -eq 1 ]; then
    ROOT_PART=$(mount | sed -n 's|^/dev/\(.*\) on / .*|\1|p')
  else
    if ! [ -h /dev/root ]; then
      whiptail --msgbox "/dev/root does not exist or is not a symlink. Don't know how to expand" 20 60 2
      return 0
    fi
    ROOT_PART=$(readlink /dev/root)
  fi

  PART_NUM=${ROOT_PART#mmcblk0p}
  if [ "$PART_NUM" = "$ROOT_PART" ]; then
    whiptail --msgbox "$ROOT_PART is not an SD card. Don't know how to expand" 20 60 2
    return 0
  fi

  # NOTE: the NOOBS partition layout confuses parted. For now, let's only
  # agree to work with a sufficiently simple partition layout
  if [ "$PART_NUM" -ne 2 ]; then
    whiptail --msgbox "Your partition layout is not currently supported by this tool. You are probably using NOOBS, in which case your root filesystem is already expanded anyway." 20 60 2
    return 0
  fi

  LAST_PART_NUM=$(parted /dev/mmcblk0 -ms unit s p | tail -n 1 | cut -f 1 -d:)
  if [ $LAST_PART_NUM -ne $PART_NUM ]; then
    whiptail --msgbox "$ROOT_PART is not the last partition. Don't know how to expand" 20 60 2
    return 0
  fi

  # Get the starting offset of the root partition
  PART_START=$(parted /dev/mmcblk0 -ms unit s p | grep "^${PART_NUM}" | cut -f 2 -d: | sed 's/[^0-9]//g')
  [ "$PART_START" ] || return 1
  # Return value will likely be error for fdisk as it fails to reload the
  # partition table because the root fs is mounted
  fdisk /dev/mmcblk0 <<EOF
p
d
$PART_NUM
n
p
$PART_NUM
$PART_START

p
w
EOF

  # now set up an init.d script
cat <<EOF > /etc/init.d/resize2fs_once &&
#!/bin/sh
### BEGIN INIT INFO
# Provides:          resize2fs_once
# Required-Start:
# Required-Stop:
# Default-Start: 3
# Default-Stop:
# Short-Description: Resize the root filesystem to fill partition
# Description:
### END INIT INFO

. /lib/lsb/init-functions

case "\$1" in
  start)
    log_daemon_msg "Starting resize2fs_once" &&
    resize2fs /dev/$ROOT_PART &&
    update-rc.d resize2fs_once remove &&
    rm /etc/init.d/resize2fs_once &&
    log_end_msg \$?
    ;;
  *)
    echo "Usage: \$0 start" >&2
    exit 3
    ;;
esac
EOF
 	sed -e '10,31d' /root/.profile
  chmod +x /etc/init.d/resize2fs_once &&
  update-rc.d resize2fs_once defaults &&
    whiptail --msgbox "Success, we will now reboot to finish resizing..." 20 60 1
		reboot
}

# Everything else needs to be run as root
if [ $(id -u) -ne 0 ]; then
  printf "Script must be run as root. Try 'sudo bash resize-sd.sh'\n"
  exit 1
fi

# Interactive use loop
if [ "$INTERACTIVE" = True ]; then
  get_init_sys
  calc_wt_size
  while true; do
      FUN=$(whiptail --title "NextBerry MicroSD/External drive selection" --menu "Setup Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --nocancel --ok-button Select \
			"A Expand Filesystem" "Ensures that all of the SD storage is available" \
			"B Use HDD/SSD/USB" "/root on external drive /boot on SD (recommended)" \
        3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -eq 1 ]; then
      do_finish
    elif [ $RET -eq 0 ]; then
      case "$FUN" in
      A\ *) do_expand_rootfs ;;
			B\ *) do_usb ;;
        *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
      esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
    else
      exit 1
    fi
  done
fi
