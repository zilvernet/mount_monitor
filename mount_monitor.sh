#!/bin/bash

# Path to the INI file
INI_FILE="mount-status.ini"
CONFIG_FILE="mountmonitor-config.ini"

SLACK_WEBHOOK_URL=$(awk -F'=' '/^\[Slack\]/{f=1} f==1&&$1~/^slack_hook_url/{print $2;exit}' $CONFIG_FILE)
SLACK_CHANNEL=$(awk -F'=' '/^\[Slack\]/{f=1} f==1&&$1~/^slack_channel/{print $2;exit}' $CONFIG_FILE)

# Read the list of mounts to check from the config file
MOUNTS=""
if [ -f "$CONFIG_FILE" ]; then
    section_start=$(awk '/^\[mounts\]/{print NR+1; exit 0;}' "$CONFIG_FILE")
    section_end=$(awk "/^\[[^m][^o][^u][^n][^t][^s]/ {print NR; exit 0;}" "$CONFIG_FILE")
    if [ -z "$section_end" ]; then
        section_end="$(wc -l < "$CONFIG_FILE")"
    fi
    MOUNTS=$(awk -F= -v start=$section_start -v end=$section_end 'NR>=start && NR<end{printf "%s ", $2}' "$CONFIG_FILE" | tr -d '\r\n')
    if [ -z "$MOUNTS" ]; then
        echo "No mounts found in the [mounts] section of the config file"
        exit 1
    fi
fi

# Initialize the mount status from the INI file, or create the file if it doesn't exist
declare -A MOUNT_STATUS
if [ -f "$INI_FILE" ]; then
    while IFS='=' read -r key value; do
        if [[ $key == /mnt/* ]]; then
            MOUNT_STATUS["$key"]="$value"
        fi
    done < <(sort "$INI_FILE" | uniq)
else
    for mount in $MOUNTS; do
        MOUNT_STATUS["$mount"]="1"
    done
fi

# Check each mount and set MOUNT_DISCONNECTED to 1 if any mount is disconnected
MOUNT_DISCONNECTED=0
for mount in $MOUNTS; do
    if ! mountpoint -q $mount; then
        MOUNT_DISCONNECTED=1
        if [ "${MOUNT_STATUS[$mount]}" != "0" ]; then
            echo "$mount is disconnected"
            MOUNT_STATUS["$mount"]="0"
            curl -X POST --data-urlencode "payload={\"channel\": \"$SLACK_CHANNEL\", \"username\": \"mount_monitor\", \"text\": \"$mount is *disconnected* on $(hostname)\", \"icon_emoji\": \":open_file_folder:\"}" $SLACK_WEBHOOK_URL -s
        fi
    else
        if [ "${MOUNT_STATUS[$mount]}" != "1" ]; then
            echo "$mount is reconnected"
            MOUNT_STATUS["$mount"]="1"
        fi
    fi
done

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
        /usr/bin/python3 mount_docker.py
        echo "All mounts are reconnected"
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
