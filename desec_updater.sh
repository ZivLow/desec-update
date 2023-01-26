#!/bin/bash

# Check if the configuration file exists
if [ -f deSEC_config ]; then
    # Read the API key and domains from the configuration file
    source deSEC_config
else
    # Prompt for the API key and domains
    read -p "Enter deSEC API key: " api_key
    read -p "Enter deSEC domains (separated by space): " domains

    # Create config file
    touch deSEC_config

    # Save the API key and domains to the configuration file
    echo "api_key=$api_key" >deSEC_config
    echo "domains=($domains)" >>deSEC_config
fi

# Get the current IP address
ip=$(curl -s https://api.ipify.org)

# Update the IP address for each domain
update_ip() {
    for domain in "${domains[@]}"; do
        echo "Updating $domain"
        curl "https://update.dedyn.io/?hostname=$domain&myipv4=$ip" --header "Authorization: Token $api_key"
        echo
        echo "Waiting 60 seconds"
        sleep 60
    done
}

# Run the script once now
update_ip
