#!/bin/bash

sudo cp -r /usr/share/HackerOS/Config-Files/org.gnome.Software.desktop /usr/share/applications/

# Check if Release.txt exists
if [ ! -f /usr/share/HackerOS/Release.txt ]; then
    echo "Error: /usr/share/HackerOS/Release.txt not found"
    exit 1
fi

# Get current version from Release.txt
current_version=$(cat /usr/share/HackerOS/Release.txt | grep -oP '\d+\.\d+')

# Fetch latest version from SourceForge
latest_version=$(curl -s https://sourceforge.net/projects/hackeros/files/ | grep -oP 'HackerOS-\K\d+\.\d+' | sort -V | tail -n 1)

# Compare versions
if [ -z "$latest_version" ]; then
    echo "Error: Could not fetch latest version from SourceForge"
    exit 1
fi

if [ "$(printf '%s\n' "$latest_version" "$current_version" | sort -V | tail -n 1)" != "$current_version" ]; then
    echo "New version $latest_version available. Current version: $current_version"

    # Clone the update repository
    rm -rf /tmp/HackerOS
    git clone https://github.com/HackerOS-Linux-System/HackerOS.git /tmp/HackerOS

    # Check if clone was successful
    if [ $? -ne 0 ]; then
        echo "Error: Failed to clone repository"
        exit 1
    }

    # Make unpack.sh executable
    if [ -f /tmp/HackerOS/update-repos/unpack.sh ]; then
        sudo chmod a+x /tmp/HackerOS/update-repos/unpack.sh

        # Run the unpack script
        /tmp/HackerOS-Updates/unpack.sh
        if [ $? -eq 0 ]; then
            echo "Update script executed successfully"
        else
            echo "Error: Update script failed"
            exit 1
        fi
    else
        echo "Error: unpack.sh not found in repository"
        exit 1
    fi
else
    echo "System is up to date (version $current_version)"
fi
