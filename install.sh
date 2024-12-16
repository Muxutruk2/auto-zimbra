#!/usr/bin/env bash

set -o errexit  # abort on nonzero exitstatus
set -o nounset  # abort on unbound variable
set -o pipefail # don't hide errors within pipes

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root"
  exit 1
fi

# Check if input file is provided
if [ "$#" -eq 1 ] && [ -f "$1" ]; then
  source "$1"
else
  read -rp "Enter the desired text editor (e.g., vim, nano" EDITOR
  # Prompt user for inputs if no file is provided
  read -rp "Enter the desired static IP address for ZIMBRA (e.g., 192.168.1.100): " ZIMBRA_IP
  read -rp "Enter the installation URL (e.g., mail.example.com): " ZIMBRA_FQDN

  read -rp "Enter the IP address for WINDOWS (e.g., 192.168.1.100): " WINDOWS_IP
  read -rp "Enter the FQDN for WINDOWS (e.g., WinServer.example.com): " WINDOWS_FQDN

  read -rp "Enter the network interface (e.g., eth0): " INTERFACE
  read -rp "Enter the default route (e.g., 192.168.1.1): " DEFAULT_ROUTE
fi
ZIMBRA_HOST=${ZIMBRA_FQDN%%.*}
WINDOWS_HOST=${WINDOWS_FQDN%%.*}

# Step 1: Configure netplan
NETPLAN_FILE="/etc/netplan/00-netcfg.yaml"
echo "Creating netplan configuration at $NETPLAN_FILE..."
cat <<EOF >"$NETPLAN_FILE"
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      dhcp4: false
      addresses:
        - $ZIMBRA_IP/24
      routes: 
        - to: default
          via: $DEFAULT_ROUTE
      nameservers:
        addresses: [$WINDOWS_IP]
EOF
$EDITOR $NETPLAN_FILE

# Apply netplan configuration
if ! netplan apply; then
  echo "Error applying netplan configuration. Reverting changes..."
  rm -f "$NETPLAN_FILE"
  exit 1
fi

# Step 2: Disable firewall
if ! ufw disable; then
  echo "Error disabling firewall. Attempting to restart ufw..."
  ufw enable || echo "Failed to restart ufw. Please check manually."
fi

# Step 3: Install netcat
if ! apt update || ! apt install -y netcat; then
  echo "Error installing netcat. Skipping this step."
fi

# Step 4: Stop AppArmor
if ! systemctl stop apparmor || ! systemctl disable apparmor; then
  echo "Error stopping or disabling AppArmor. Continuing without disabling AppArmor."
fi

# Step 5: Change hostname
echo "$ZIMBRA_FQDN" >/etc/hostname
if ! hostnamectl set-hostname "$ZIMBRA_FQDN"; then
  echo "Error setting hostname. Reverting changes..."
  echo "localhost" >/etc/hostname
  exit 1
fi
$EDITOR /etc/hostname

# Step 6: Let the user edit /etc/hosts
cat <<EOF >"/etc/hosts"
127.0.0.1 localhost
127.0.1.1 $ZIMBRA_FQDN $ZIMBRA_HOST
$ZIMBRA_IP $ZIMBRA_FQDN $ZIMBRA_HOST
$WINDOWS_IP $WINDOWS_FQDN $WINDOWS_HOST
EOF
$EDITOR /etc/hosts

# Step 7: Disable systemd-resolved and edit resolv.conf
if ! systemctl disable systemd-resolved || ! systemctl stop systemd-resolved; then
  echo "Error disabling systemd-resolved. Continuing without disabling it."
fi
rm -f /etc/resolv.conf
cat <<EOF >"/etc/resolv.conf"
nameserver $WINDOWS_IP
EOF
$EDITOR /etc/resolv.conf

# Step 8: Install Zimbra
echo "Downloading Zimbra..."
if ! wget https://files.zimbra.com/downloads/8.8.15_GA/zcs-8.8.15_GA_4179.UBUNTU20_64.20211118033954.tgz -O /tmp/zimbra.tar.gz; then
  echo "Error downloading Zimbra"
  exit 1
fi

echo "Extracting Zimbra installer..."
if ! tar -xvzf /tmp/zimbra.tar.gz -C /tmp; then
  echo "Error extracting Zimbra installer. Cleaning up and retrying..."
  exit 1
fi

# Let user select folder containing "z" in /tmp
INSTALL_DIR=""
PS3="Select the folder containing the Zimbra installer: "
select folder in $(find /tmp -type d -name "*z*" -printf "%f\n"); do
  if [ -n "$folder" ]; then
    INSTALL_DIR="/tmp/$folder"
    break
  fi
  echo "Invalid selection. Please try again."
done

if [ ! -d "$INSTALL_DIR" ]; then
  echo "Selected folder does not exist. Exiting."
  exit 1
fi

cd "$INSTALL_DIR" || {
  echo "Error accessing Zimbra installation directory. Please check the extraction process."
  exit 1
}

echo "Running Zimbra installer..."
if ! ./install.sh; then
  echo "Error during Zimbra installation. Please check the logs for details."
  exit 1
fi

# Final message
echo "Zimbra installation completed. Please verify the setup."
