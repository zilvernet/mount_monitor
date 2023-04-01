#!/bin/bash

set -e

installpath="/opt/mountmonitor"

cd
sudo mkdir -p "$installpath"
sudo chown 1000:1000 "$installpath" -R
cd "$installpath"
curl -LO https://raw.githubusercontent.com/zilvernet/mount_monitor/main/mount_monitor.sh
curl -LO https://raw.githubusercontent.com/zilvernet/mount_monitor/main/mount_docker.py
chmod +x $installpath/mount_monitor.sh
chmod +x $installpath/mount_docker.py

if [ ! -f "$installpath/mountmonitor-config.ini" ]; then
  curl -LO https://raw.githubusercontent.com/zilvernet/mount_monitor/main/mountmonitor-config.ini
fi
