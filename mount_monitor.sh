#!/bin/bash

# Path to the INI file
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
INI_FILE="$SCRIPT_DIR/mount-status.txt"
CONFIG_FILE="$SCRIPT_DIR/mountmonitor-config.ini"

SLACK_WEBHOOK_URL=$(awk -F'=' '/^\[Slack\]/{f=1} f==1&&$1~/^slack_hook_url/{print $2;exit}' $CONFIG_FILE)
SLACK_CHANNEL=$(awk -F'=' '/^\[Slack\]/{f=1} f==1&&$1~/^slack_channel/{print $2;exit}' $CONFIG_FILE)

# Read the list of mounts to check from the config file
MOUNTS_IN_CONFIG=""
if [ -f "$CONFIG_FILE" ]; then
    section_start=$(awk '/^\[mounts\]/{print NR+1; exit 0;}' "$CONFIG_FILE")
    section_end=$(awk '/^\[containers\]/{print NR-1; exit 0;}' "$CONFIG_FILE")
    #echo "section_start:$section_start section_end:$section_end"
    if [ -z "$section_end" ]; then
        section_end="$(wc -l < "$CONFIG_FILE")"
    fi

    for ((i=$section_start;i<$section_end;i++)); do
        line=$(sed -n "${i}p" "$CONFIG_FILE")  # Get the line from config file
        mount=$(echo "$line" | cut -d= -f2)
        MOUNTS_IN_CONFIG+="${mount} "  # Concatenate the mount to the existing string with a space separator
    done
    MOUNTS_IN_CONFIG=${MOUNTS_IN_CONFIG% }  # Remove trailing space
    if [ -z "$MOUNTS_IN_CONFIG" ]; then
        echo "No mounts found in the [mounts] section of the config file"
        exit 1
    fi
else
    echo "No config file was found in: $CONFIG_FILE"
    exit 1
fi

# Read the list of mounts to check from the status file
MOUNTS_IN_STATUS=""
if [ -f "$INI_FILE" ]; then
    while read -r line; do
        mount=$(echo "$line" | cut -d= -f1)
        echo "mount:$mount"
        MOUNTS_IN_STATUS+="${mount} "  # Concatenate the mount to the existing string with a space separator
    done < "$INI_FILE"
    MOUNTS_IN_STATUS=${MOUNTS_IN_STATUS% }  # Remove trailing space
fi

# Check if the number of mounts is different than the ones in the INI config file
if [ "$MOUNTS_IN_STATUS" != "$MOUNTS_IN_CONFIG" ]; then
    echo "Number of mounts in the INI file is different than the ones in the config file, recreating the INI file"
    rm -f "$INI_FILE"
fi

# Initialize the mount status from the INI file, or create the file if it doesn't exist
if [ ! -f "$INI_FILE" ]; then
    # Create the INI file with the initial mount status
    touch "$INI_FILE"
    chmod 644 "$INI_FILE"
    for mount in $MOUNTS_IN_CONFIG; do
        echo "$mount=1" >> "$INI_FILE"
    done
fi

declare -A MOUNT_STATUS
if [ -f "$INI_FILE" ]; then
    while IFS='=' read -r key value; do
        MOUNT_STATUS["$key"]="$value"
    done < "$INI_FILE"
else
    for mount in $MOUNT_IN_STATUS; do
        MOUNT_STATUS["$mount"]="1"
    done
fi

declare -A MOUNTS
i=0
for mount in $MOUNTS_IN_STATUS; do
    MOUNTS[$i]=$mount
    ((i++))
done

#for mount in "${!MOUNT_STATUS[@]}"; do
#    echo "MOUNTS_STATUS $mount has status ${MOUNT_STATUS[$mount]}"
#done
#for mount in "${!MOUNTS[@]}"; do
#    echo "MOUNTS $mount has mountpoint ${MOUNTS[$mount]}"
#done

# Check each mount and set MOUNT_DISCONNECTED to 1 if any mount is disconnected
MOUNT_DISCONNECTED=0
for mount in $MOUNTS; do
    if ! mountpoint -q $mount; then
        MOUNT_DISCONNECTED=1
        if [ "${MOUNT_STATUS[$mount]}" != "0" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') $mount is disconnected"
            MOUNT_STATUS["$mount"]="0"
            curl -X POST --data-urlencode "payload={\"channel\": \"$SLACK_CHANNEL\", \"username\": \"mount_monitor\", \"text\": \"$mount is *disconnected* on $(hostname)\", \"icon_emoji\": \":open_file_folder:\"}" $SLACK_WEBHOOK_URL -s > /dev/null 2>&1
        fi
    else
        if [ "${MOUNT_STATUS[$mount]}" != "1" ]; then
            MOUNT_STATUS["$mount"]="1"
        fi
    fi
done

echo "MOUNT_DISCONNECTED=$MOUNT_DISCONNECTED"
read -p "press ENTER to continue"

# If any mount is disconnected, reconnect the mounts with sudo mount -a
if [ $MOUNT_DISCONNECTED -eq 1 ]; then
    sudo mount -a
    ALL_RECONNECTED=1
    for mount in $MOUNTS; do
        if ! mountpoint -q $mount; then
            ALL_RECONNECTED=0
            MOUNT_STATUS["$mount"]="0"
        else
            MOUNT_STATUS["$mount"]="1"
        fi
    done
    if [ $ALL_RECONNECTED -eq 1 ]; then

        # Call the Python script with arguments
        /usr/bin/python3 $SCRIPT_DIR/mount_docker.py
        echo "$(date '+%Y-%m-%d %H:%M:%S') All mounts are reconnected"
        curl -X POST --data-urlencode "payload={\"channel\": \"$SLACK_CHANNEL\", \"username\": \"mount_monitor\", \"text\": \"All mounts are *reconnected* on $(hostname)\", \"icon_emoji\": \":open_file_folder:\"}" $SLACK_WEBHOOK_URL -s
    fi
fi

# Save the updated mount status to the INI file, only if there are changes
for mount in $MOUNTS; do
    if [ "${MOUNT_STATUS[$mount]}" != "$(grep -E "^$mount=" "$INI_FILE" | cut -d= -f2)" ]; then
        sed -i "s|^$mount=.*|$mount=${MOUNT_STATUS[$mount]}|" "$INI_FILE"
        #echo "Mount status has changed, updating $INI_FILE"
    fi
done
