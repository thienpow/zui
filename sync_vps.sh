#!/bin/bash

# Define variables
LOCAL_PATH=~/dev/zui
VPS_USER=pow
VPS_IP=34.169.172.111
SSH_KEY=~/.ssh/google_compute_engine
VPS_PATH=~/dev/zui

# Function to check if command was successful
check_status() {
    if [ $? -ne 0 ]; then
        echo "Error: $1 failed"
        exit 1
    fi
}

# Ensure we're in the correct local directory
cd "$LOCAL_PATH" || {
    echo "Error: Cannot change to local directory $LOCAL_PATH"
    exit 1
}

# Git operations on local machine
echo "Pushing local changes..."
git push
check_status "Git push"

# SSH into VPS and pull changes
echo "Connecting to VPS and pulling changes..."
ssh -i "$SSH_KEY" "$VPS_USER@$VPS_IP" << EOF
    cd $VPS_PATH || {
        echo "Error: Cannot change to VPS directory $VPS_PATH"
        exit 1
    }
    git pull
    exit
EOF

check_status "VPS operations"

echo "Successfully updated both local and VPS repositories!"
