import configparser
import subprocess
import os

script_path = os.path.dirname(os.path.abspath(__file__))
config_path = os.path.join(script_path, 'mountmonitor-config.ini')

# Read the container names from the INI file
config = configparser.ConfigParser()
config.read(f'{config_path}')
containers = config.items('containers')

# Loop through the containers and restart them
for index, container_name in containers:
    subprocess.run(['docker', 'restart', container_name], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    print(f"Container {container_name} restarted.")
