#!/bin/bash

# Get path of script
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
CONFIG_FILE_PATH="${SCRIPT_DIR}/config/deSEC_config"
COLOURS_FILE_PATH="${SCRIPT_DIR}/config/colours.sh"
LOG_DIR="${SCRIPT_DIR}/log"
LOGS_FILE_PATH="${LOG_DIR}/desec_updater_logs.log"
COUNTER_FILE_PATH="${LOG_DIR}/counter.log"

### Functions ---------------------------------------------------------

# Log to console and to log file. Input $1 = string to log
function log() {
    local TIMESTAMP=$(date +"%r, %Z, %A, %e %B %Y")
    echo -e $1 | (echo -n "[${TIMESTAMP}]    " && cat) |& tee -a "${LOGS_FILE_PATH}"
}

# Test an IP address for validity:
# Usage:
#      valid_ip IP_ADDRESS
#      if [[ $? -eq 0 ]]; then echo good; else echo bad; fi
#   OR
#      if valid_ip IP_ADDRESS; then echo good; else echo bad; fi
function valid_ip()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

# Get the public IP address
# $1: ip variable name,     $2: array of commands to get public ip
# Return 0 = true (get IP success)
# Return 1 = false (get IP fail)
function get_public_ip() {

    local -n ip_local=$1
    local -n get_public_ip_commands_local=$2

    if valid_ip ${ip_local}; then
        # ip variable is already set
        return 0
    fi

    for get_public_ip_command in "${get_public_ip_commands_local[@]}"; do

        command_output_ip=$(${get_public_ip_command} | tr -d '"')

        if valid_ip ${command_output_ip}; then
            ip_local=${command_output_ip}
            log "Get Public IP ${Cyan}${ip_local}${Color_Off} from command: ${Purple}${get_public_ip_command}${Color_Off}"
            return 0
        elif [[ ${command_output_ip} == *"timed out"* ]]; then
            log "${BYellow}Timed out getting public IP from command: ${Purple}${get_public_ip_command}${Color_Off}"
            update_last_check_time "last_get_ip_timed_out_time" "${COUNTER_FILE_PATH}"
            update_counter_file "get_ip_timed_out_count" "${COUNTER_FILE_PATH}"
        elif [ -z "${command_output_ip}" ]; then
            log "${BRed}No answer from command: ${Purple}${get_public_ip_command} ${Color_Off}--> \"\""
            update_last_check_time "last_get_ip_no_answer_time" "${COUNTER_FILE_PATH}"
            update_counter_file "get_ip_no_answer_count" "${COUNTER_FILE_PATH}"
        else
            log "${BRed}Unknown error getting public IP from command: ${Purple}${get_public_ip_command} ${Color_Off}--> \"${command_output_ip}\""
            update_last_check_time "last_get_ip_unknown_error_time" "${COUNTER_FILE_PATH}"
            update_counter_file "get_ip_unknown_error_count" "${COUNTER_FILE_PATH}"
        fi

    done

    # if all commands have failed to get public ip address
    log "${BRed}Cannot get public IP from all commands!${Color_Off}"
    return 1
}

# Update the IP address for each domain
function update_ip() {
    local -n domains_local=$1
    local api_key_local=$2

    if ! get_public_ip "ip" "get_public_ip_commands"; then
        # Cannot get public IP address
        return 1
    fi

    for domain in "${domains_local[@]}"; do
        log "Updating $domain"
        curl "https://update.dedyn.io/?hostname=$domain&myipv4=$ip" --header "Authorization: Token $api_key_local"
        echo
        log "Waiting 60 seconds"
        sleep 60
    done

    return 0
}

# Check if current public IP address is different from stored ip address
# Return 0 = true (need to update)
# Return 1 = false (no need to update)
function need_update() {
    local -n domains_local=$1
    local -n name_servers_local=$2

    if ! get_public_ip "ip" "get_public_ip_commands"; then
        # Cannot get public IP address
        return 1
    fi

    for domain in "${domains_local[@]}"; do
        for name_server in "${name_servers_local[@]}"; do
            # Get the stored ip address for the domain in desec name server
            domain_ip=$(dig +short $domain @${name_server})

            # Check if current public IP address is same as the one from stored ip address
            if [ "${ip}" == "${domain_ip}" ]; then
                # No need to update the stored ip address for the current domain
                log "${Green}Good match: Public IP ${ip} is recorded with domain ${UCyan}${domain}${Green} via ${name_server}${Color_Off}"
                break
            else
                # Need to update the stored ip address for the current domain
                log "${BRed}No match: ${Purple}Public IP ${ip} is different from ${domain_ip} recorded with domain ${UCyan}${domain}${Purple} via ${name_server}${Color_Off}"
            fi

            # If all name servers stored ip address is different from current public IP address
            if [ "${name_server}" == "${name_servers[-1]}" ]; then
                # Need to update the stored ip address. 0 = true
                log "${On_Red}No match for all name servers:${Color_Off} ${IYellow}Need to update${Color_Off} ip address for ${UCyan}${domain}${Color_Off}"
                return 0
            fi
        done
    done

    # No need to update the stored ip address for all domains. 1 = false
    log "${On_IGreen}${BWhite}No updates needed for all domains.${Color_Off}"
    return 1
}

# Function to change values in file, given a key.
# $1 --> key	,	$2 --> new_value	,	$3 --> file path
function edit_counter_file()
{
    sed -i -e "s/^\([[:space:]]*$1=\).*/\1$2/1" "$3"
}

# Read the value for a specified key in a file
function read_properties() {
    local search_key="$1"
    local file="$2"

    local key value
    
    while IFS="=" read -r key value; do
        case "$key" in
        '#'*) ;;
        ${search_key})
            read -d '' -r "${search_key}" <<< $(printf "$value")
            ;;
        esac
    done < "$file"
}

# Update counter file
function update_counter_file() {
    local key=$1
    local file_path=$2

    local -i new_value=1

    # Check if counter found
    case $(grep -s "$key" "$file_path" >/dev/null; echo $?) in
        0)
            # If found
            read_properties "${key}" "${file_path}"

            # Increment value of key. ! is one level of indirection
            new_value=$((${!key}+1))

            # Edit counter file
            edit_counter_file "${key}" "${new_value}" "${file_path}"
            ;;
        1)
            # If not found
            # Append update_ip_count to configuration file
            echo "${key}=${new_value}" >> ${file_path}
            ;;
        *)
            # If an error occurred (no such file)
            log "${file_path} not found. Creating file..."
            
            # Append update_ip_count to configuration file
            echo "${key}=${new_value}" >> ${file_path}
            ;;
    esac
}

# Update last check time
function update_last_check_time() {
    local key=$1
    local file_path=$2

    local TIMESTAMP=$(date +"%r, %Z, %A, %e %B %Y")

    # Check if counter found
    case $(grep -s "$key" "$file_path" >/dev/null; echo $?) in
        0)
            # If found
            read_properties "${key}" "${file_path}"

            # Edit counter file
            edit_counter_file "${key}" "${TIMESTAMP}" "${file_path}"
            ;;
        1)
            # If not found

            # Append update_ip_count to configuration file
            echo "${key}=${TIMESTAMP}" >> ${file_path}
            ;;
        *)
            # If an error occurred (no such file)
            log "${file_path} not found. Creating file..."
            
            # Append update_ip_count to configuration file
            echo "${key}=${TIMESTAMP}" >> ${file_path}
            ;;
    esac
}

### Functions END ----------------------------------------------------


### Program ----------------------------------------------------------

# Check if log directory, log file, colours file exists
[ -d "${LOG_DIR}" ] || mkdir "${LOG_DIR}"
[ -f ${LOGS_FILE_PATH} ] && echo >> ${LOGS_FILE_PATH} || log "${LOGS_FILE_PATH} not found. Creating file..."
[ -f ${COLOURS_FILE_PATH} ] && source ${COLOURS_FILE_PATH} || log "Warning: No colours.sh file found."

# Check if the configuration file exists
if [ -f ${CONFIG_FILE_PATH} ]; then
    # Read the API key and domains from the configuration file
    source ${CONFIG_FILE_PATH}
else
    # Prompt for the API key and domains
    read -p "Enter deSEC API key: " api_key
    read -p "Enter deSEC domains (separated by space): " domains
    read -p "Enter name servers to check ip address stored for domains (separated by space): " name_servers

    # Create config file
    touch ${CONFIG_FILE_PATH}

    # Save the API key and domains to the configuration file
    echo "api_key=$api_key" > ${CONFIG_FILE_PATH}
    echo "domains=($domains)" >> ${CONFIG_FILE_PATH}
    echo "name_servers=($name_servers)" >> ${CONFIG_FILE_PATH}
fi

# Only update IP record on deSEC if need to update
if need_update "domains" "name_servers"; then
    update_ip "domains" "${api_key}"
    update_last_check_time "last_update_time" "${COUNTER_FILE_PATH}"
    update_counter_file "update_ip_count" "${COUNTER_FILE_PATH}"
fi

update_last_check_time "last_check_time" "${COUNTER_FILE_PATH}"
update_counter_file "check_ip_count" "${COUNTER_FILE_PATH}"

### Program END ------------------------------------------------------
