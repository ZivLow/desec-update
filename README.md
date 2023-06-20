# deSEC IP Updater

Updates the IP address of multiple deSEC domains.

## Features
- Prompts for deSEC API key and domains if a configuration file does not exist
- Saves the API key and domains to a configuration file for future use
- Fetches the current IP using opendns via dig
- Updates the IP address for each domain in the list
- Waits 1 minute between each request to prevent rate-limiting
- Only performs ip_update if public IP is different from the A record in deSEC name servers
- Timestamping on log output
- ANSI colour log output
- Counter for the number of time ran IP has been checked and IP updates performed

## Usage
1. Download or clone the script to your local machine
```
git clone git@github.com:ZivLow/desec-update.git
cd desec-update
```
2. Make the script executable by running
```
sudo chmod +x desec_updater.sh ./config/colours.sh
```
3. Creating new configuration file
```
cd config
cp deSEC_config_example deSEC_config
```
4. Put your deSEC API key and domains in configuration file.
```
nano deSEC_config
```
Exit & save with `CTRL+X`

7. Set up a crontab job using:
```
crontab -e
```
8. Copy & paste crontab job from [crontab](config/crontab) file to your crontab.
```
*/3 * * * * ${HOME}/desec-update/desec_updater.sh
```
Save & exit with `CTRL+X`

### To test running once (optional)
1. Go to project root directory (~/desec-update/). \
Run the script once with:
```
./desec_updater.sh
```
2. The script may prompt you for your deSEC API key and the list of domains to update

## Logs
- Log files will be written to `log/` folder
- To view logs:
```
cat log/desec_updater_logs.log
```
- To view counters:
```
cat log/counter.log
```

## Note
- Make sure you have dig, bash(>v4.3) installed on your machine
- You can edit the script to change the wait time between requests
- Tested to work on Ubuntu 22.04 LTS

## Credits
This script is originally forked from [A-Emile's deSEC-updater](https://github.com/A-Emile/deSEC-updater) repository.
## Disclaimer
This script is provided as is, use it at your own risk. 
