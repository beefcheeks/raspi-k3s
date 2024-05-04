#!/bin/sh

# Directory to monitor
MONITORED_DIR="/opt/blueprints/"
TARGET_DIR="/config/blueprints/automation/custom/"
SLEEP_SECONDS=30

# Function to calculate MD5 checksums of files in a directory
calculate_checksums() {
    # Calculate MD5 checksums and base file names in the specified directory
    find "$1" -type f -exec md5sum {} + | awk -F / '{print $1 $NF}' | sort
}

# Function to monitor changes
monitor_changes() {
    while true; do
        # Calculate MD5 checksums of files in the monitored directory
        monitored_checksums=$(calculate_checksums "$MONITORED_DIR")

        # Calculate MD5 checksums of files in the target directory
        target_checksums=$(calculate_checksums "$TARGET_DIR")

        # Compare the checksums of the two directories
        if [ "$monitored_checksums" != "$target_checksums" ]; then
            # Perform actions when differences are detected
            echo "Differences detected between $MONITORED_DIR and $TARGET_DIR"
            echo "Deleting then copying files from $MONITORED_DIR to $TARGET_DIR..."
            rm "$TARGET_DIR"/*
            cp -rL "$MONITORED_DIR"/* "$TARGET_DIR"
            echo "Files copied successfully."
        fi
        # Wait for a period of time before checking again (e.g., 30 seconds)
        sleep $SLEEP_SECONDS
    done
}

# Call the function to start monitoring changes
monitor_changes
