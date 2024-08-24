#!/bin/bash

# Run this script with:
# wget https://raw.githubusercontent.com/pitterpatter22/Script-Repo/main/Bootstrap%20Scripts/lxc-bootstrap.sh --no-check-certificate && sudo bash lxc-bootstrap.sh


#-----------------------------------#
#             VARIABLES             #
#-----------------------------------#

this_script_url="https://raw.githubusercontent.com/pitterpatter22/Script-Repo/main/Bootstrap%20Scripts/lxc-bootstrap.sh"
this_script_name="LXC Bootstrapper"
formatter_url="https://raw.githubusercontent.com/pitterpatter22/TaskFormatter/main/bash_task_formatter/task_formatter.sh"
scriptname=$0

# Initialize success flag
success=0

# Determine the user (use the first argument if provided, otherwise fallback)
USER_TO_RUN_AS="${1:-$SUDO_USER}"
USER_HOME=$(eval echo ~$USER_TO_RUN_AS)


#-----------------------------------#
#             FORMATTER             #
#-----------------------------------#

if [ ! -f "task_formatter.sh" ]; then
    wget $formatter_url --no-check-certificate -O task_formatter.sh > /dev/null 2>&1
fi

source ./task_formatter.sh

#-----------------------------------#
#             FUNCTIONS             #
#-----------------------------------#


install_netstat() {

    # Check if netstat netstat is installed
    if dpkg -l | grep -q net-tools; then
        echo -e "Netstat Installed $CHECK_MARK"
    else
        echo "Installing Netstat..."
        sudo apt-get install -y net-tools > /dev/null 2>&1
        echo -e "Netstat Installed $CHECK_MARK"
    fi

}


configure_ssh() {

    # Check if OpenSSH Server is installed
    if dpkg -l | grep -q openssh-server; then
        echo "OpenSSH Server is installed. Uninstalling..."
        sudo apt-get remove --purge -y openssh-server > /dev/null 2>&1
    else
        echo "OpenSSH Server is not installed. Proceeding with installation..."
    fi

    # Install OpenSSH Server
    echo "Installing OpenSSH Server..."
    sudo apt-get install -y openssh-server > /dev/null 2>&1


    # Start OpenSSH Server
    echo "Starting OpenSSH Server..."
    sudo systemctl start ssh

    # Enable OpenSSH Server to start on boot
    sudo systemctl enable ssh


}

validate_ssh() {

    # Check if OpenSSH Server is running and listening on port 22
    echo "Validating OpenSSH Server status..."

    # Check if SSH service is running
    if systemctl is-active --quiet ssh; then
        echo -e "OpenSSH Server is running $CHECK_MARK"
    else
        echo "OpenSSH Server is not running. Exiting..."
        exit 1
    fi

    # Check if OpenSSH Server is listening on port 22
    if sudo netstat -tuln | grep -q ":22"; then
        echo -e "OpenSSH Server is listening on port 22 $CHECK_MARK"
    else
        echo "OpenSSH Server is not listening on port 22. Exiting..."
    fi

    echo -e "OpenSSH Server is successfully installed, running, and listening on port 22 $CHECK_MARK"


}


# Function to validate installation

update_upgrade_packages() {
    sudo apt-get update > /dev/null 2>&1
    echo -e "Packages Updated $CHECK_MARK"
    sudo apt-get upgrade -y > /dev/null 2>&1
    echo -e "Packaged Upgraded $CHECK_MARK"
    sudo apt-get autoremove -y > /dev/null 2>&1
    echo -e "Packages Cleaned $CHECK_MARK"
}

# remove artifacts
remove_script() {
    if [ -f "$0" ]; then
        echo "Deleted master script..."
        rm -- "$0"
    fi
    if [ -f "task_formatter.sh" ]; then
        rm task_formatter.sh
    fi
    echo -e "Cleaned up $CHECK_MARK"
}

# Remove created files on Failure
cleanup_files() {

    echo -e "Cleaned up $CHECK_MARK"
}




#-----------------------------------#
#             MAIN LOGIC            #
#-----------------------------------#

'''
Run functions with this format:

    format_output {function_name} "Function Description"

    Example:
        
        format_output update_upgrade_packages "Update and Upgrade Packages"


To add in success monitoring when script is run from master.sh, run like this:

if ! format_output {function_name} "Function Description"; then
    cleanup_files
    success=1
fi

if ! format_output {function_name} "Function Description"; then
    cleanup_files
    success=1
fi


'''

# Print header
print_header "$this_script_name" "$this_script_url"

echo -e "Installing as User: $USER_TO_RUN_AS\nUser Home: $USER_HOME\n"


# Run the functions with formatted output
if ! format_output update_upgrade_packages "Update and Upgrade Packages"; then
    cleanup_files
    success=1
fi

if ! format_output install_netstat "Validating Dependencies"; then
    cleanup_files
    success=1
fi

if ! format_output configure_ssh "Configuring SSH"; then
    cleanup_files
    success=1
fi

if ! format_output validate_ssh "Validating SSH"; then
    cleanup_files
    success=1
fi


format_output remove_script "Cleaning up"

# Print final message
final_message "$this_script_name" $success

# Exit with appropriate status
exit $success