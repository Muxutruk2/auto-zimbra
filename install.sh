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
# ZIMBRA
prompt ZIMBRA_IP "Enter the desired static IP address for ZIMBRA (e.g., 192.168.1.100)"
prompt ZIMBRA_FQDN "Enter the installation URL (e.g., mail.example.com)"
ZIMBRA_HOST=${ZIMBRA_FQDN%%.*}

# WINDOWS
prompt WINDWOS_IP "Enter the IP address for WINDOWS (e.g., 192.168.1.100)"
prompt WINDWOS_FQDN "Enter the FQDN for WINDOWS (e.g., WinServer.example.com)"
WINDOWS_HOST=${WINDOWS_FQDN%%.*}

# STATIC IP
prompt INTERFACE "Enter the network interface (e.g., eth0)"
prompt DEFAULT_ROUTE "Enter the default route (e.g., 192.168.1.1)"

# MISC
prompt TIMEZONE "Enter the timezone (e.g Europe/Madrid"

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
echo "$ZIMBRA_FQDN" >/etc/hostname
hostnamectl set-hostname "$ZIMBRA_FQDN"

# Step 6: Let the user edit /etc/hosts
cat <<EOF >"/etc/hosts"
127.0.0.1 localhost
127.0.1.1 $ZIMBRA_FQDN $ZIMBRA_HOST
$ZIMBRA_IP $ZIMBRA_FQDN $ZIMBRA_HOST
$WINDOWS_IP $WINDOWS_FQDN $WINDOWS_HOST
EOF
$EDITOR /etc/hosts

# Step 7: Disable systemd-resolved and edit resolv.conf
systemctl disable systemd-resolved
systemctl stop systemd-resolved
rm -f /etc/resolv.conf
cat <<EOF >"/etc/resolv.conf"
nameserver $WINDOWS_IP
EOF
$EDITOR /etc/resolv.conf

# Step 8: Install Zimbra
echo "Downloading Zimbra..."
wget https://files.zimbra.com/downloads/8.8.15_GA/zcs-8.8.15_GA_4179.UBUNTU20_64.20211118033954.tgz -O /tmp/zimbra.tar.gz

echo "Extracting Zimbra installer..."
tar -xvzf /tmp/zimbra.tar.gz -C /tmp

cd /tmp/zimbra || exit 1
echo "Running Zimbra installer..."
./install.sh

# Final message
echo "Zimbra installation completed. Please verify the setup."
