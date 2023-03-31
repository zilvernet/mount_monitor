# Mount Monitor Script

This script checks if the specified mounts are connected on the system and sends a notification to Slack if any of them are disconnected. It also checks if the mounts have reconnected after running the mount -a command.

Restarting Docker Containers:

After reconnecting the mounts, the script restarts the Docker containers that depend on these mounts. The list of containers to restart is specified in the containers section of the configuration file. The script uses a Python script named mount_docker.py to restart the Docker containers.

## Configuration:

The script reads the configuration from a file named mountmonitor-config.ini. The configuration file should contain the following sections:

- [mounts]: Contains the list of mounts to check.
- [containers]: Contains the list of Docker containers to restart after the mounts have reconnected.
- [Slack]: Contains the Slack webhook URL and channel name to send notifications.

## Dependencies:

- awk: The script uses awk to parse the configuration file.
- curl: The script uses curl to send notifications to Slack.
- docker: The script uses docker to restart the Docker containers.
- python: The script uses a Python script to restart the Docker containers.

## Compatibility:

The script should work on most Linux systems that use bash. However, it has only been tested on Ubuntu 18.04 and CentOS 7.

## Usage:
The script can be run manually by executing the command: 
```
./mount_monitor.sh
```

## Usage with Cron:

The recommended usage for this script is to set up a Cron job that runs the script every 10 minutes. Here's an example of a Cron entry that runs the script every 10 minutes:

```
*/10 * * * * /path/to/mount_monitor.sh > /path/to/mount_monitor.log 2>&1
```

Contributing:

Please feel free to submit any issues or pull requests if you find any bugs or want to contribute to the project.
