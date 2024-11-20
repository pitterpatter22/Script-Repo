#!/bin/bash

# Run this script with:
# wget https://github.com/pitterpatter22/Script-Repo/tree/main/Bootstrap%20Scripts/ssh_portknocking.sh --no-check-certificate && sudo bash ssh_portknocking.sh [username]


#-----------------------------------#
#             VARIABLES             #
#-----------------------------------#

this_script_url="https://raw.githubusercontent.com/pitterpatter22/TaskFormatter/refs/heads/main/bash_task_formatter/task_formatter.sh"
this_script_name="SSH Port Knocking Setup"
formatter_url="https://raw.githubusercontent.com/pitterpatter22/TaskFormatter/main/bash_task_formatter/task_formatter.sh"
scriptname=$0


# Initialize success flag
success=0

# Determine the user (use the first argument if provided, otherwise fallback)
USER_TO_RUN_AS="${1:-$SUDO_USER}"
USER_HOME=$(eval echo ~$USER_TO_RUN_AS)

ssh_connect_port="22"
knockd_sequence="7345,8395,9321"
knockd_close_sequence="9321,8395,7345"
close_rule_delay=60 #seconds

#-----------------------------------#
#             FORMATTER             #
#-----------------------------------#

wget $formatter_url --no-check-certificate -O task_formatter.sh > /dev/null 2>&1
source ./task_formatter.sh


#-----------------------------------#
#             FUNCTIONS             #
#-----------------------------------#

# Function to update packages
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
    rm -- "$0"
    if [ -f "task_formatter.sh" ]; then
        rm task_formatter.sh
    fi
    echo -e "Cleaned up $CHECK_MARK"
}

# Remove created files on Failure
cleanup_files() {

    if [[ "$success" == 1 ]]; then
        echo -e "$COLOR_RED\n\nScript Failed, cleaning up\n\n$COLOR_RESET"
    fi

    #### Clean Knockd ####

    if [ -f "/etc/knockd.conf" ]; then
        rm /etc/knockd.conf
        systemctl stop knockd > /dev/null 2>&1
        systemctl disable knockd > /dev/null 2>&1
        echo -e "Cleaned up Knockd $CHECK_MARK"
    fi

    #### Clean IPTABLES ####

    if [ -f "/etc/iptables/rules.v4" ]; then
        sed -i 's/^/#/' "/etc/iptables/rules.v4" > /dev/null 2>&1
        echo -e "Commented out /etc/iptables/rules.v4 $CHECK_MARK"
    fi

    if [ -f "/etc/iptables/rules.v6" ]; then
        sed -i 's/^/#/' "/etc/iptables/rules.v6" > /dev/null 2>&1
        echo -e "Commented out /etc/iptables/rules.v6 $CHECK_MARK"
    fi

    iptables -F > /dev/null 2>&1
    echo "Flushed IPTABLES"

    # Allow Established and Related
    iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1
    # Allow SSH
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT > /dev/null 2>&1
    # Allow loopback traffic
    iptables -A INPUT -i lo -j ACCEPT > /dev/null 2>&1
    # Allow ICMP (ping)
    iptables -A INPUT -p icmp -j ACCEPT > /dev/null 2>&1
    echo "Added default allow rules"

    # Save the iptables rules
    iptables-save > /etc/iptables/rules.v4 > /dev/null 2>&1
    ip6tables-save > /etc/iptables/rules.v6 > /dev/null 2>&1
    echo "Saved iptables rules"

    echo -e "Cleaned up IPTABLES $CHECK_MARK"

    #### Clean SSH ####

    # Check if the Port setting already exists in sshd_config
    if grep -q "^Port" /etc/ssh/sshd_config > /dev/null 2>&1; then
        # Comment out the existing Port line
        sed -i '/^Port/s/^/#/' /etc/ssh/sshd_config > /dev/null 2>&1
        echo "Existing SSH port setting commented out."
    else
        echo "No existing SSH port found... Default port 22 is used."
    fi

    echo "SSH port reverted to 22."

    echo -e "Cleaned up SSH $CHECK_MARK"

}

# Function to check if the script is run as root
check_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 1>&2
    exit 1
  fi
}

# Function to install dependencies
install_dependencies() {
  echo "Installing dependencies..."
  apt update > /dev/null 2>&1
  apt install -y knockd iptables-persistent > /dev/null 2>&1
}

# Function to configure iptables
configure_iptables() {
  echo "Configuring iptables..."
  
  # Flush existing rules
  iptables -F > /dev/null 2>&1

  # Set default policies
  iptables -P INPUT DROP > /dev/null 2>&1
  iptables -P FORWARD DROP > /dev/null 2>&1
  iptables -P OUTPUT ACCEPT > /dev/null 2>&1

  # Allow already established connections
  iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT > /dev/null 2>&1

  # Allow loopback traffic
  iptables -A INPUT -i lo -j ACCEPT > /dev/null 2>&1

  # Allow ICMP (ping)
  iptables -A INPUT -p icmp -j ACCEPT > /dev/null 2>&1

  # Open the SSH port but only after knocking
  iptables -A INPUT -p tcp --dport 22 -j DROP > /dev/null 2>&1

  # Save the iptables rules
  iptables-save > /etc/iptables/rules.v4 > /dev/null 2>&1
  ip6tables-save > /etc/iptables/rules.v6 > /dev/null 2>&1

  echo "iptables configured and saved."
}

# Function to configure knockd
configure_knockd() {
    echo "Configuring knockd..."

    # Create knockd config file
    cat > /etc/knockd.conf <<EOL
[options]
        UseSyslog

[openSSH]
        sequence      = $knockd_sequence
        seq_timeout   = 15
        command       = /sbin/iptables -I INPUT -s %IP% -p tcp --dport $ssh_connect_port -j ACCEPT \
$( [[ -n "$notify_allow_command" ]] && echo "&& $notify_allow_command" ); \
(sleep $close_rule_delay && /sbin/iptables -D INPUT -s %IP% -p tcp --dport $ssh_connect_port -j ACCEPT \
$( [[ -n "$notify_close_command" ]] && echo "&& $notify_close_command" )) &
        tcpflags      = syn

[closeSSH]
        sequence      = $knockd_close_sequence
        seq_timeout   = 15
        command       = /sbin/iptables -D INPUT -s %IP% -p tcp --dport $ssh_connect_port -j ACCEPT
        tcpflags      = syn
EOL

    # Enable knockd to start on boot
    if ! systemctl enable knockd > /dev/null 2>&1; then
        echo "Failed to enable knockd. Exiting."
        exit 1
    fi

    # Restart knockd service
    if ! systemctl restart knockd > /dev/null 2>&1; then
        echo "Failed to restart knockd. Exiting."
        exit 1
    fi

    echo -e "knockd configured and started. $CHECK_MARK"
}

# Function to set up the SSH service
configure_ssh() {
  echo -e "Configuring SSH to use port $ssh_connect_port and only allow connection after port knocking..."

  # Check if the Port setting already exists in sshd_config
  if grep -q "^Port" /etc/ssh/sshd_config > /dev/null 2>&1; then
      # Comment out the existing Port line
      sed -i '/^Port/s/^/#/' /etc/ssh/sshd_config > /dev/null 2>&1
      echo "Existing SSH port setting commented out."
  else
      echo "No existing SSH port found... Default port 22 is used."
  fi

  # Add the new port setting at the end of the file
  echo "Port $ssh_connect_port" >> /etc/ssh/sshd_config
  echo "New SSH port set to $ssh_connect_port."

  # Make sure SSH is running
  systemctl restart ssh > /dev/null 2>&1

  echo -e "SSH configured to use $ssh_connect_port $CHECK_MARK"
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


main() {
    echo -e "Installing as User: $USER_TO_RUN_AS\nUser Home: $USER_HOME\n"

    # Ask if user wants notifications
    read -p "Do you want to add notifications when port knocking is triggered? (y/n): " add_notifications
    if [[ "$add_notifications" =~ ^[Yy]$ ]]; then
        # Prompt for Discord webhook URL
        read -p "Enter the Discord webhook URL to use for notifications: " user_webhook
        if [[ -n "$user_webhook" ]]; then
            discord_webhook="$user_webhook"
            echo -e "Using provided Discord webhook: $discord_webhook\n"

            notify_allow_command='curl -H "Content-Type: application/json" -d "{\"content\": \"SSH Port Knocking Triggered on $(hostname) from %IP%\"}" '"$discord_webhook"
            notify_close_command='curl -H "Content-Type: application/json" -d "{\"content\": \"SSH Port Knocking Closed on $(hostname) from %IP%\"}" '"$discord_webhook"
        else
            echo "No webhook provided. Notifications will not be added."
            unset notify_allow_command notify_close_command
        fi
    else
        echo "Skipping notification setup."
        unset notify_allow_command notify_close_command
    fi

    # Run the functions with formatted output
    if ! format_output update_upgrade_packages "Update and Upgrade Packages"; then
        success=1
        cleanup_files
    fi

    if ! format_output check_root "Checking Root"; then
        success=1
        cleanup_files
    fi

    if ! format_output install_dependencies "Installing Dependencies"; then
        success=1
        cleanup_files
    else
        echo -e "Install successful.... $CHECK_MARK"
    fi

    if ! format_output configure_iptables "Configuring IP Tables"; then
        success=1
        cleanup_files
    else
        echo -e "IP Tables configured successfully.... $CHECK_MARK"
    fi

    if ! format_output configure_knockd "Configuring Knockd"; then
        success=1
        cleanup_files
    else
        echo -e "Knockd setup successful.... $CHECK_MARK"
    fi

    if ! format_output configure_ssh "Configuring sshd for Port Knocking"; then
        success=1
        cleanup_files
    else
        echo -e "Port knocking for SSH setup completed successfully $CHECK_MARK"
        echo -e "knockd Connection Config:\nEnter:\t\t$knockd_sequence\nExit:\t\t$knockd_close_sequence\nSSH Port:\t$ssh_connect_port\n"
    fi
}



# Print header
print_header "$this_script_name" "$this_script_url"

option="${1}"

if [[ "$option" == "revert" ]]; then
    echo -e "${COLOR_YELLOW}Revert Option Detected...\n\n$COLOR_RESET"
    
    read -p "Revert knockd, sshd, and iptables to default? (y/n): " -r continue_revert
    echo -e "\n\n"
    if [[ "$continue_revert" == "y" ]]; then
        format_output cleanup_files "Setting configs to default..."
    fi
else
    main
fi

format_output remove_script "Cleaning up"

# Print final message
final_message "$this_script_name" $success

if [[ "$option" == "revert" && "$continue_revert" == "y" ]]; then
    echo -e "${COLOR_RED}About to restart sshd, this might disconnect the session...\n${COLOR_RESET}"
    read -p "Press enter to continue..."
    systemctl restart sshd ssh > /dev/null 2>&1

fi


# Exit with appropriate status
exit $success
