# Mount Monitor Script

This script checks if the specified mounts are connected on the system and sends a notification to Slack if any of them are disconnected. It also checks if the mounts have reconnected after running the mount -a command.

Usage:

```
./mount_monitor.sh
```

Configuration:

The script reads the configuration from a file named mountmonitor-config.ini. The configuration file should contain the following sections:

[mounts]: Contains the list of mounts to check.
[Slack]: Contains the Slack webhook URL and channel name to send notifications.
[containers]: Contains the list of Docker containers to restart after the mounts have reconnected.
If the configuration file is not found, the script uses the default mount list.

Dependencies:

awk: The script uses awk to parse the configuration file.
curl: The script uses curl to send notifications to Slack.
docker: The script uses docker to restart the Docker containers.
python: The script uses a Python script to restart the Docker containers.

Compatibility:

The script should work on most Linux systems that use bash. However, it has only been tested on Ubuntu 18.04 and CentOS 7.

Usage with Cron:

The recommended usage for this script is to set up a Cron job that runs the script every 10 minutes. Here's an example of a Cron entry that runs the script every 10 minutes:

```
*/10 * * * * /path/to/mount_monitor.sh > /dev/null 2>&1
```

Restarting Docker Containers:

After reconnecting the mounts, the script restarts the Docker containers that depend on these mounts. The list of containers to restart is specified in the containers section of the configuration file. The script uses a Python script named mount_docker.py to restart the Docker containers.

Contributing:

Please feel free to submit any issues or pull requests if you find any bugs or want to contribute to the project.
