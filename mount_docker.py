import configparser
import subprocess

# Read the container names from the INI file
config = configparser.ConfigParser()
config.read('mountmonitor-config.ini')
containers = config.items('containers')

# Loop through the containers and restart them
for index, container_name in containers:
    print(f"Restarting container {container_name}...")
    subprocess.run(['docker', 'restart', container_name], check=True)
    print(f"Container {container_name} restarted.")
