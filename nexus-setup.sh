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

# 1. Install required dependencies (Java and wget)
echo "Installing required dependencies (Java and wget)..."
if ! java -version &>/dev/null; then
    echo "Java is not installed. Installing Java 8 (OpenJDK)..."
    yum install -y java-1.8.0-openjdk.x86_64
else
    echo "Java is already installed."
fi

if ! command -v wget &>/dev/null; then
    echo "wget is not installed. Installing wget..."
    yum install -y wget
else
    echo "wget is already installed."
fi

# 2. Create necessary directories for Nexus
echo "Creating necessary directories..."
mkdir -p $NEXUS_DIR
mkdir -p /tmp/nexus
mkdir -p $NEXUS_WORK_DIR  # Ensure the sonatype-work directory is created

# Ensure the correct ownership and permissions
chown -R $NEXUS_USER:$NEXUS_USER $NEXUS_DIR
chmod -R 755 $NEXUS_DIR

# 3. Download and extract Nexus
echo "Downloading Nexus version $NEXUS_VERSION..."
wget $NEXUS_URL -O /tmp/nexus/nexus.tar.gz

echo "Extracting Nexus..."
tar -xzvf /tmp/nexus/nexus.tar.gz -C /tmp/nexus
NEXUS_EXTRACTED_DIR=$(ls -d /tmp/nexus/nexus-* | head -n 1)

# 4. Move Nexus files to /opt/nexus
echo "Moving Nexus files to $NEXUS_DIR..."
mv $NEXUS_EXTRACTED_DIR/* $NEXUS_DIR/
rm -rf /tmp/nexus

# 5. Create Nexus user if it doesn't exist
echo "Creating user '$NEXUS_USER' if it doesn't exist..."
if id "$NEXUS_USER" &>/dev/null; then
    echo "User '$NEXUS_USER' already exists."
else
    useradd -r -m -s /bin/false $NEXUS_USER
    echo "User '$NEXUS_USER' created."
fi

# 6. Set ownership for Nexus directories and files
echo "Setting ownership for Nexus directories and files..."
chown -R $NEXUS_USER:$NEXUS_USER $NEXUS_DIR
chown -R $NEXUS_USER:$NEXUS_USER $NEXUS_WORK_DIR

# 7. Ensure Nexus binaries are executable
echo "Setting execute permissions for Nexus binaries..."
chmod +x $NEXUS_DIR/bin/nexus
chmod +x $NEXUS_DIR/bin/nexus.vmoptions

# 8. Create Nexus service file
echo "Creating Nexus service file..."
cat <<EOT > $NEXUS_SERVICE
[Unit]
Description=Nexus Repository Manager
After=network.target

[Service]
Type=forking
LimitNOFILE=65536
ExecStart=$NEXUS_DIR/bin/nexus start
ExecStop=$NEXUS_DIR/bin/nexus stop
User=$NEXUS_USER
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOT

# 9. Ensure the service file has correct permissions
echo "Setting permissions for Nexus service file..."
chmod 644 $NEXUS_SERVICE

# 10. Create nexus.rc file for user configuration
echo "Creating nexus.rc file..."
echo "run_as_user=\"$NEXUS_USER\"" > $NEXUS_DIR/bin/nexus.rc

# 11. Reload systemd and start Nexus service
echo "Reloading systemd to recognize the new Nexus service..."
systemctl daemon-reload

echo "Starting Nexus service..."
systemctl start nexus

# 12. Enable Nexus service to start on boot
echo "Enabling Nexus service to start on boot..."
systemctl enable nexus

# 13. Check Nexus service status
echo "Nexus installation completed. Checking Nexus service status..."
systemctl status nexus
