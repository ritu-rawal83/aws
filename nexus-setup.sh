#!/bin/bash

# Exit on error
set -e

# Define variables
NEXUS_VERSION="3.44.0-01"  # Replace with the desired Nexus version
NEXUS_URL="https://download.sonatype.com/nexus/3/latest-unix.tar.gz"
NEXUS_DIR="/opt/nexus"
NEXUS_WORK_DIR="$NEXUS_DIR/sonatype-work"
NEXUS_USER="nexus"
NEXUS_SERVICE="/etc/systemd/system/nexus.service"

# Install Java (OpenJDK)
echo "Installing Java..."
yum install -y java-1.8.0-openjdk.x86_64 wget

# Create necessary directories
echo "Creating directories..."
mkdir -p $NEXUS_DIR
mkdir -p /tmp/nexus
mkdir -p $NEXUS_WORK_DIR

# Download Nexus
echo "Downloading Nexus..."
wget $NEXUS_URL -O /tmp/nexus/nexus.tar.gz

# Extract Nexus
echo "Extracting Nexus..."
tar -xzvf /tmp/nexus/nexus.tar.gz -C /tmp/nexus
NEXUS_EXTRACTED_DIR=$(ls -d /tmp/nexus/nexus-* | head -n 1)

# Move Nexus files to /opt/nexus
echo "Moving Nexus files to $NEXUS_DIR..."
mv $NEXUS_EXTRACTED_DIR/* $NEXUS_DIR/
rm -rf /tmp/nexus

# Create Nexus user if it doesn't exist
if id "$NEXUS_USER" &>/dev/null; then
    echo "User '$NEXUS_USER' already exists."
else
    echo "Creating user '$NEXUS_USER'..."
    useradd -r -m -s /bin/false $NEXUS_USER
fi

# Set ownership for Nexus directories
echo "Setting ownership for Nexus directories..."
chown -R $NEXUS_USER:$NEXUS_USER $NEXUS_DIR
chown -R $NEXUS_USER:$NEXUS_USER $NEXUS_WORK_DIR

# Create Nexus service file
echo "Creating Nexus service file..."
cat <<EOT > $NEXUS_SERVICE
[Unit]
Description=nexus service
After=network.target

[Service]
Type=forking
LimitNOFILE=65536
ExecStart=$NEXUS_DIR/bin/nexus start
ExecStop=$NEXUS_DIR/bin/nexus stop
User=$NEXUS_USER
Restart=on-abort

[Install]
WantedBy=multi-user.target
EOT

# Create nexus.rc file
echo "Creating nexus.rc file..."
echo "run_as_user=\"$NEXUS_USER\"" > $NEXUS_DIR/bin/nexus.rc

# Reload systemd to recognize the new service
echo "Reloading systemd..."
systemctl daemon-reload

# Start and enable the Nexus service
echo "Starting Nexus service..."
systemctl start nexus
systemctl enable nexus

# Check Nexus service status
echo "Nexus installation completed. Checking Nexus service status..."
systemctl status nexus
