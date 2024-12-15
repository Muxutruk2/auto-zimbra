#!/usr/bin/env bash

set -o errexit  # abort on nonzero exitstatus
set -o nounset  # abort on unbound variable
set -o pipefail # don't hide errors within pipes

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root"
  exit 1
fi

# Function to prompt user for input
prompt() {
  local var_name="$1"
  local prompt_text="$2"
  read -rp "$prompt_text: " var_name
  export var_name
}

# Gather user inputs
prompt IP_ADDRESS "Enter the desired static IP address (e.g., 192.168.1.100)"
prompt DNS_SERVERS "Enter the DNS servers (comma-separated, e.g., 8.8.8.8,8.8.4.4)"
prompt DEFAULT_ROUTE "Enter the default route (e.g., 192.168.1.1)"
prompt INTERFACE "Enter the network interface (e.g., eth0)"
prompt HOSTNAME "Enter the desired hostname for Zimbra"
prompt INSTALL_URL "Enter the installation URL (e.g., mail.example.com)"

# Step 1: Configure netplan
NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"
echo "Creating netplan configuration at $NETPLAN_FILE..."
cat <<EOF >"$NETPLAN_FILE"
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      dhcp4: false
      addresses:
        - $IP_ADDRESS/24
      routes: 
        - to: default
          via: $DEFAULT_ROUTE
      nameservers:
        addresses: [$DNS_SERVERS]
EOF

# Apply netplan configuration
netplan apply

# Step 2: Disable firewall
ufw disable

# Step 3: Install netcat
apt update && apt install -y netcat

# Step 4: Stop AppArmor
systemctl stop apparmor
systemctl disable apparmor

# Step 5: Change hostname
echo "$INSTALL_URL" >/etc/hostname
hostnamectl set-hostname "$INSTALL_URL"

# Step 6: Let the user edit /etc/hosts
cat <<EOF
$IP_ADDRESS $INSTALL_URL $HOSTNAME
EOF
$EDITOR /etc/hosts

# Step 7: Disable systemd-resolved and edit resolv.conf
systemctl disable systemd-resolved
systemctl stop systemd-resolved
rm -f /etc/resolv.conf
cat <<EOF
Edit /etc/resolv.conf and add your desired DNS servers. Example:
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF
$EDITOR /etc/resolv.conf

# Step 8: Install Zimbra
echo "Downloading Zimbra..."
wget https://files.zimbra.com/downloads/10.0.0_GA/zimbra.tar.gz -O /tmp/zimbra.tar.gz

echo "Extracting Zimbra installer..."
tar -xvzf /tmp/zimbra.tar.gz -C /tmp

cd /tmp/zimbra || exit 1
echo "Running Zimbra installer..."
./install.sh

# Final message
echo "Zimbra installation completed. Please verify the setup."
