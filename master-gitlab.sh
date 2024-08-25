#!/bin/bash

# Run this script with:
# wget https://scripts.pitterpatter.io/master.sh && sudo bash master.sh

# Variables for URLs and script info
this_script_url="https://scripts.pitterpatter.io/master.sh"
this_script_name="Master Script Repo"
formatter_url="https://raw.githubusercontent.com/pitterpatter22/TaskFormatter/main/bash_task_formatter/task_formatter.sh"
BRANCH="main"  # or whatever branch you are using

gitlab_url="gitlab.example.com"

scriptname=$0
wget $formatter_url --no-check-certificate -O task_formatter.sh > /dev/null 2>&1

# Source the formatter script
source ./task_formatter.sh
BRANCH="main"  # or whatever branch you are using

# Check if the script is being run with sudo
if [ "$EUID" -eq 0 ]; then
    ORIGINAL_USER=${SUDO_USER:-$(whoami)}
else
    ORIGINAL_USER=$(whoami)
fi

# Function to check and install sudo if not present
install_sudo() {
    if ! command which sudo &> /dev/null; then
        echo "sudo is not installed. Installing sudo..."
        if [ -x "$(command -v apt-get)" ]; then
            apt-get update > /dev/null 2>&1 && apt-get install -y sudo > /dev/null 2>&1
        elif [ -x "$(command -v yum)" ]; then
            yum install -y sudo > /dev/null 2>&1
        else
            echo "Could not install sudo. Please install it manually."
            exit 1
        fi
    fi
}

# Function to check and install curl if not present
install_curl() {
    if ! command -v curl &> /dev/null; then
        echo "curl is not installed. Installing curl..."
        if [ -x "$(command -v apt-get)" ]; then
            sudo apt-get update > /dev/null 2>&1 && sudo apt-get install -y curl > /dev/null 2>&1
        elif [ -x "$(command -v yum)" ]; then
            sudo yum install -y curl > /dev/null 2>&1
        else
            echo "Could not install curl. Please install it manually."
            exit 1
        fi
    fi
}

# Function to check and install jq if not present
install_jq() {
    if ! command -v jq &> /dev/null; then
        echo "jq is not installed. Installing jq..."
        if [ -x "$(command -v apt-get)" ]; then
            sudo apt-get update > /dev/null 2>&1 && sudo apt-get install -y jq > /dev/null 2>&1
        elif [ -x "$(command -v yum)" ]; then
            sudo yum install -y jq > /dev/null 2>&1
        else
            echo "Could not install jq. Please install it manually."
            exit 1
        fi
    fi
}

# Function to clean up temporary files in /tmp
cleanup_tmp_files() {
    echo "Cleaning up temporary files..."
    sudo rm -rf /tmp/$gitlab_url* > /dev/null 2>&1
    echo "Temporary files cleaned."
}

remove_script() {
    if [ -f "task_formatter.sh" ]; then
        rm -- "$0"
        echo "Deleted master script..."
    fi
    if [ -f "task_formatter.sh" ]; then
        rm task_formatter.sh
    fi
}

# Function to fetch the list of scripts from the repository
fetch_scripts() {
    scripts_recursive=$(curl -k -s "https://$gitlab_url/api/v4/projects/1/repository/tree?recursive=true" | jq -r '.[] | select(.type == "blob" and .name and (.name | type == "string") and (.name | endswith(".sh"))) | .path')
    scripts_root=$(curl -k -s "https://$gitlab_url/api/v4/projects/1/repository/tree" | jq -r '.[] | select(.type == "blob" and .name and (.name | type == "string") and (.name | endswith(".sh"))) | .path')
    echo -e "$scripts_root\n$scripts_recursive" | sort -u
}

# Function to download and run a selected script
run_script() {
    local script_path=$1
    local encoded_script_path=$(echo "$script_path" | sed 's/\//%2F/g')
    local script_name=$(basename "$script_path")
    local url="https://$gitlab_url/api/v4/projects/1/repository/files/$encoded_script_path/raw?ref=$BRANCH"

    # If verbose mode, print the URL
    if [[ "$verbose" == "true" ]]; then
        echo "Requesting URL: $url"
    fi
    
    # Create necessary directories for the script
    mkdir -p "/tmp/$(dirname "$script_path")"
    
    # Make the request and capture the HTTP status code
    http_status=$(curl -k -sL -w "%{http_code}" -o "/tmp/$script_path" "$url")
    
    # If verbose mode, print the HTTP status code
    if [[ "$verbose" == "true" ]]; then
        echo "Request completed with status code: $http_status"
    fi

    if [[ "$http_status" == "200" ]]; then
        chmod +x "/tmp/$script_path"
        sudo bash "/tmp/$script_path" "$ORIGINAL_USER"
    else
        echo "Failed to download script: $script_name (HTTP status code: $http_status)"
    fi
}

# Main function to display the script selection menu and run the selected scripts
run_scripts() {
    printf "${COLOR_GREEN}Fetching list of available scripts from GitLab repository...${COLOR_RESET}\n"
    scripts=$(fetch_scripts)

    if [ -z "$scripts" ]; then
        printf "${COLOR_RED}No scripts found in the repository.${COLOR_RESET}\n"
        exit 1
    fi

    while true; do
        printf "${COLOR_BLUE}\nAvailable scripts:${COLOR_RESET}\n"
        select script in $scripts "Quit"; do
            if [ "$script" == "Quit" ]; then
                break 2
            elif [ -n "$script" ]; then
                printf "${COLOR_BLUE}You selected $script. Running script...${COLOR_RESET}\n"
                run_script "$script"
                break
            else
                printf "${COLOR_RED}Invalid selection. Please try again.${COLOR_RESET}\n"
            fi
        done

        printf "${COLOR_BLUE}Would you like to run more scripts? (y/n)${COLOR_RESET}\n"
        read -r choice
        if [[ "$choice" != "y" ]]; then
            break
        fi
    done
}

# Main script logic
clear

# Check for verbose flag
verbose="false"
if [[ "$1" == "-v" ]]; then
    verbose="true"
fi

# Print header
print_header "$this_script_name" "$this_script_url"

# Initialize success flag
success=0
install_sudo
install_curl
install_jq
run_scripts

# Cleanup created files
cleanup_tmp_files

# Clean up the master script and formatter
format_output remove_script "Cleaning up"

# Print final message
final_message "$this_script_name" $success

# Exit with appropriate status
exit $success