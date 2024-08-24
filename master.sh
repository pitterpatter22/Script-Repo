#!/bin/bash

# Run this script with:
# wget https://raw.githubusercontent.com/seanssmith/Script-Repo/main/master.sh -O master.sh && sudo bash master.sh

# Variables for URLs and script info
this_script_url="https://raw.githubusercontent.com/seanssmith/Script-Repo/main/master.sh"
this_script_name="Master Script Repo"
formatter_url="https://raw.githubusercontent.com/seanssmith/TaskFormatter/main/bash_task_formatter/task_formatter.sh"
BRANCH="main"  # or whatever branch you are using

# Trap to clean up script on exit or interruption
trap remove_script EXIT

# Download and source the formatter script
wget $formatter_url -O task_formatter.sh > /dev/null 2>&1
source ./task_formatter.sh

# Ensure sudo is available
install_sudo() {
    if ! command -v sudo &> /dev/null; then
        echo -e "${CROSS_MARK} sudo is not installed. Installing sudo..."
        if [ -x "$(command -v apt-get)" ]; then
            apt-get update > /dev/null 2>&1 && apt-get install -y sudo > /dev/null 2>&1
        elif [ -x "$(command -v yum)" ]; then
            yum install -y sudo > /dev/null 2>&1
        else
            echo -e "${CROSS_MARK} Could not install sudo. Please install it manually."
            exit 1
        fi
    fi
}

# Ensure curl is available
install_curl() {
    if ! command -v curl &> /dev/null; then
        echo -e "${CROSS_MARK} curl is not installed. Installing curl..."
        if [ -x "$(command -v apt-get)" ]; then
            sudo apt-get update > /dev/null 2>&1 && sudo apt-get install -y curl > /dev/null 2>&1
        elif [ -x "$(command -v yum)" ]; then
            sudo yum install -y curl > /dev/null 2>&1
        else
            echo -e "${CROSS_MARK} Could not install curl. Please install it manually."
            exit 1
        fi
    fi
}

# Ensure jq is available
install_jq() {
    if ! command -v jq &> /dev/null; then
        echo -e "${CROSS_MARK} jq is not installed. Installing jq..."
        if [ -x "$(command -v apt-get)" ]; then
            sudo apt-get update > /dev/null 2>&1 && sudo apt-get install -y jq > /dev/null 2>&1
        elif [ -x "$(command -v yum)" ]; then
            sudo yum install -y jq > /dev/null 2>&1
        else
            echo -e "${CROSS_MARK} Could not install jq. Please install it manually."
            exit 1
        fi
    fi
}

# Clean up temporary files
cleanup_tmp_files() {
    echo -e "${CHECK_MARK} Cleaning up temporary files..."
    sudo rm -rf /tmp/github.com/seanssmith/Script-Repo*
    echo -e "${CHECK_MARK} Temporary files cleaned."
}

# Remove the master script and formatter
remove_script() {
    if [ -f "$0" ]; then
        rm -- "$0"
    fi
    if [ -f "task_formatter.sh" ]; then
        rm task_formatter.sh
    fi
    echo -e "${CHECK_MARK} Script and formatter cleaned up."
}

# Fetch list of scripts from GitHub repository
fetch_scripts() {
    scripts_recursive=$(curl -s "https://api.github.com/repos/seanssmith/Script-Repo/git/trees/$BRANCH?recursive=1" | jq -r '.tree[] | select(.type == "blob" and (.path | type == "string") and (.path | endswith(".sh"))?) | .path')
    scripts_root=$(curl -s "https://api.github.com/repos/seanssmith/Script-Repo/contents?ref=$BRANCH" | jq -r '.[] | select(.type == "file" and (.name | type == "string") and (.name | endswith(".sh"))?) | .path')
    echo -e "$scripts_root\n$scripts_recursive" | sort -u
}

# Download and run the selected script
run_script() {
    local script_path=$1
    local script_name=$(basename "$script_path")
    local url="https://raw.githubusercontent.com/seanssmith/Script-Repo/$BRANCH/$script_path"

    if [[ "$verbose" == "true" ]]; then
        echo "Requesting URL: $url"
    fi

    mkdir -p "/tmp/$(dirname "$script_path")"

    http_status=$(curl -sL -w "%{http_code}" -o "/tmp/$script_path" "$url")

    if [[ "$verbose" == "true" ]]; then
        echo "Request completed with status code: $http_status"
    fi

    if [[ "$http_status" == "200" ]]; then
        chmod +x "/tmp/$script_path"
        sudo bash "/tmp/$script_path" "$ORIGINAL_USER"
    else
        echo -e "${CROSS_MARK} Failed to download script"
