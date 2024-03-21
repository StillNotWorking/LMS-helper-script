#!/bin/bash

# Function to check if the user has sudo privileges
check_sudo_privileges() {
    if sudo -n true 2>/dev/null; then
        echo "User has sudo privileges."
        return 0  # Return success
    else
        echo "User does not have sudo privileges."
        return 1  # Return failure
    fi
}