#!/bin/bash

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    zenity --error --title="Error" --text="This script must be run as root. Please use sudo."
    exit 1
fi

# Check if zenity is installed
if ! command -v zenity &> /dev/null; then
    zenity --error --title="Error" --text="Zenity is not installed. Please install it first."
    exit 1
fi

# Function to create a new user
create_user() {
    USERNAME=$(zenity --entry --title="Create User" --text="Enter username:")
    if [ -z "$USERNAME" ]; then
        zenity --error --title="Error" --text="Username cannot be empty!"
        exit 1
    fi

    PASSWORD=$(zenity --password --title="Set Password" --text="Enter password for $USERNAME:")
    if [ -z "$PASSWORD" ]; then
        zenity --error --title="Error" --text="Password cannot be empty!"
        exit 1
    fi

    # Create user with home directory
    useradd -m -s /bin/bash "$USERNAME"
    echo "$USERNAME:$PASSWORD" | chpasswd

    # Check if user creation was successful
    if [ $? -eq 0 ]; then
        zenity --info --title="Success" --text="User $USERNAME created successfully!"
    else
        zenity --error --title="Error" --text="Failed to create user $USERNAME!"
        exit 1
    fi
}

# Function to select and configure disk
configure_disk() {
    # Get list of available disks
    DISKS=$(lsblk -d -o NAME,SIZE -n | awk '{print $1 " (" $2 ")"}')
    DISK=$(zenity --list --title="Select Disk" --text="Choose a disk for installation:" --column="Disk" $DISKS)
    DISK=$(echo "$DISK" | cut -d' ' -f1)  # Extract disk name

    if [ -z "$DISK" ]; then
        zenity --error --title="Error" --text="No disk selected!"
        exit 1
    fi

    # Ask if user wants LUKS encryption
    zenity --question --title="LUKS Encryption" --text="Do you want to enable LUKS encryption?" --ok-label="Yes" --cancel-label="No"
    USE_LUKS=$?

    # Confirm disk wipe
    zenity --warning --title="Warning" --text="All data on /dev/$DISK will be erased! Continue?" --ok-label="Yes" --cancel-label="No"
    if [ $? -ne 0 ]; then
        zenity --info --title="Cancelled" --text="Disk configuration cancelled."
        exit 1
    fi

    # Wipe disk
    wipefs -a "/dev/$DISK"

    # Create partition table
    parted -s "/dev/$DISK" mklabel gpt
    parted -s "/dev/$DISK" mkpart primary 1MiB 512MiB
    parted -s "/dev/$DISK" mkpart primary 512MiB 100%
    parted -s "/dev/$DISK" set 1 boot on

    # Format EFI partition
    mkfs.vfat -F32 "/dev/${DISK}1"

    # Handle LUKS encryption if selected
    if [ $USE_LUKS -eq 0 ]; then
        LUKS_PASSWORD=$(zenity --password --title="LUKS Password" --text="Enter LUKS encryption password:")
        if [ -z "$LUKS_PASSWORD" ]; then
            zenity --error --title="Error" --text="LUKS password cannot be empty!"
            exit 1
        fi
        echo -n "$LUKS_PASSWORD" | cryptsetup luksFormat "/dev/${DISK}2" -
        echo -n "$LUKS_PASSWORD" | cryptsetup luksOpen "/dev/${DISK}2" cryptroot -
        ROOT_DEVICE="/dev/mapper/cryptroot"
    else
        ROOT_DEVICE="/dev/${DISK}2"
    fi

    # Format root partition as Btrfs
    mkfs.btrfs "$ROOT_DEVICE"

    # Mount partitions
    mount "$ROOT_DEVICE" /mnt
    mkdir /mnt/boot
    mount "/dev/${DISK}1" /mnt/boot
}

# Function to set timezone
set_timezone() {
    TIMEZONES=$(timedatectl list-timezones)
    TIMEZONE=$(zenity --list --title="Select Timezone" --text="Choose your timezone:" --column="Timezone" $TIMEZONES)
    if [ -z "$TIMEZONE" ]; then
        zenity --error --title="Error" --text="No timezone selected!"
        exit 1
    fi
    timedatectl set-timezone "$TIMEZONE"
    echo "$TIMEZONE" > /mnt/etc/timezone
    zenity --info --title="Success" --text="Timezone set to $TIMEZONE"
}

# Function to set system language
set_language() {
    LANGUAGES=$(locale -a)
    LANGUAGE=$(zenity --list --title="Select Language" --text="Choose your system language:" --column="Language" $LANGUAGES)
    if [ -z "$LANGUAGE" ]; then
        zenity --error --title="Error" --text="No language selected!"
        exit 1
    fi
    echo "LANG=$LANGUAGE" > /mnt/etc/locale.conf
    zenity --info --title="Success" --text="System language set to $LANGUAGE"
}

# Function to install Cage compositor
install_cage() {
    # Install Cage and dependencies (assuming RPM-based distro like Fedora)
    (dnf install -y cage wayland-utils 2>&1 | zenity --progress --title="Installing Cage" --text="Installing Cage compositor..." --auto-close --pulsate) || {
        zenity --error --title="Error" --text="Failed to install Cage compositor!"
        exit 1
    }
    zenity --info --title="Success" --text="Cage compositor installed successfully!"
}

# Function to install and configure GRUB
install_grub() {
    # Install GRUB and dependencies
    (dnf install -y grub2-efi-x64 grub2-tools shim-x64 2>&1 | zenity --progress --title="Installing GRUB" --text="Installing GRUB bootloader..." --auto-close --pulsate) || {
        zenity --error --title="Error" --text="Failed to install GRUB!"
        exit 1
    }

    # Install GRUB to disk
    mkdir -p /mnt/boot/efi
    mount -t vfat "/dev/${DISK}1" /mnt/boot/efi
    grub2-install --target=x86_64-efi --efi-directory=/mnt/boot/efi --boot-directory=/mnt/boot --removable

    # Configure GRUB for LUKS if enabled
    if [ $USE_LUKS -eq 0 ]; then
        echo "GRUB_ENABLE_CRYPTODISK=y" >> /mnt/etc/default/grub
        UUID=$(blkid -s UUID -o value "/dev/${DISK}2")
        echo "cryptdevice=UUID=$UUID:cryptroot root=/dev/mapper/cryptroot" >> /mnt/etc/default/grub
    fi

    # Generate GRUB configuration
    mkdir -p /mnt/boot/grub
    grub2-mkconfig -o /mnt/boot/grub/grub.cfg

    # Set default GRUB timeout and other settings
    cat << EOF > /mnt/etc/default/grub
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="$(sed 's, release .*$,,g' /etc/system-release)"
GRUB_DEFAULT=saved
GRUB_DISABLE_SUBMENU=true
GRUB_TERMINAL_OUTPUT="console"
GRUB_CMDLINE_LINUX="rhgb quiet"
GRUB_DISABLE_RECOVERY="true"
GRUB_ENABLE_BLSCFG=true
EOF

    zenity --info --title="Success" --text="GRUB bootloader installed and configured successfully!"
}

# Main installation process
(
    echo "10"
    echo "# Creating user..."
    create_user
    sleep 1

    echo "25"
    echo "# Configuring disk..."
    configure_disk
    sleep 1

    echo "40"
    echo "# Setting timezone..."
    set_timezone
    sleep 1

    echo "55"
    echo "# Setting language..."
    set_language
    sleep 1

    echo "70"
    echo "# Installing Cage compositor..."
    install_cage
    sleep 1

    echo "85"
    echo "# Installing GRUB bootloader..."
    install_grub
    sleep 1

    echo "100"
    echo "# Installation complete!"
) | zenity --progress --title="Installation Progress" --text="Starting installation..." --percentage=0 --auto-close

zenity --info --title="Installation Complete" --text="Setup is complete! User created, disk configured, timezone and language set, Cage compositor and GRUB bootloader installed."

# Clean up mounts
umount /mnt/boot/efi
umount /mnt/boot
umount /mnt
if [ $USE_LUKS -eq 0 ]; then
    cryptsetup luksClose cryptroot
fi

exit 0
