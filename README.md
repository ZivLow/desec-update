# deSEC IP Updater

This script updates the IP address of multiple deSEC domains.

## Features
- Prompts for deSEC API key and domains if a configuration file does not exist
- Saves the API key and domains to a configuration file for future use
- Fetches the current IP address from a "what's my IP" API
- Updates the IP address for each domain in the list
- Waits for 1 minutes between each request to prevent rate-limiting

## Usage
1. Download or clone the script to your local machine
2. Make the script executable by running `chmod +x desec_updater.sh`
3. Run the script with `./desec_updater.sh`
4. The script will prompt you for your deSEC API key and the list of domains to update

## Note
- Make sure you have curl installed on your machine
- You can edit the script to change the wait time between requests

This script is provided as is, use it at your own risk. 