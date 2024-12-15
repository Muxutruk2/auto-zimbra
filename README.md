# Zimbra Installer

This repository contains a Bash script for automating the installation and initial configuration of **Zimbra Collaboration Suite** on an Ubuntu server. The script handles setting up a static IP, disabling unnecessary services, and installing Zimbra with minimal user interaction.

## Features

- Configures network settings via `netplan`.
- Sets a static IP address for the Zimbra server.
- Disables AppArmor and UFW firewall to prevent conflicts with Zimbra.
- Allows user input for essential configurations like IP addresses, hostnames, and time zones.
- Installs dependencies and downloads the Zimbra installer.

## Prerequisites

- An Ubuntu 20.04 (or compatible) server.
- Root user access (or a user with `sudo` privileges).
- Internet connectivity to download Zimbra and required packages.
- Basic knowledge of your network setup, including:
  - Static IP address for the Zimbra server.
  - FQDN (Fully Qualified Domain Name) for the server.
  - Default gateway.
  - DNS server information.

## Installation

1. **Clone the repository**:

   ```bash
   git clone https://github.com/Muxutruk2/zimbra-installer
   cd zimbra-installer
   ```

2. **Make the script executable**:

   ```bash
   chmod +x install.sh
   ```

3. **Run the script as root**:

   ```bash
   sudo ./install.sh
   ```

4. **Follow the prompts**:
   The script will ask for:

   - Static IP address for the Zimbra server.
   - FQDN for Zimbra and Windows servers.
   - Network interface name.
   - Default gateway.
   - Timezone (e.g., `Europe/Madrid`).

5. **Complete the installation**:
   The script will automatically configure the server, download the Zimbra installer, and run the installation script.

## Usage

After running the script, Zimbra will be installed and configured on your server. You can access the Zimbra admin panel using the URL you provided during setup (e.g., `https://mail.example.com`).

## Important Notes

- **Editing `/etc/hosts` and `/etc/resolv.conf`:** The script will prompt you to manually verify these files for accuracy. Ensure all entries are correct before proceeding.
- **Firewall and AppArmor:** The script disables UFW and AppArmor to avoid conflicts. If you wish to enable these services, ensure proper configuration for Zimbra beforehand.

## Troubleshooting

- **Hostname Issues:** If you encounter hostname-related issues, ensure the FQDN is properly set in `/etc/hostname` and `/etc/hosts`.
- **Network Problems:** Verify the static IP configuration in `/etc/netplan/00-netcfg.yaml`.
- **Zimbra Errors:** Check the Zimbra installation logs located in `/tmp/zimbra` for more details.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

**Disclaimer:** This script is provided as-is. Use it at your own risk. Always back up your data before making major changes to your server.
<<<<<<< HEAD

**Note:** This script has been tested and is intended to work with Ubuntu 20.04. Compatibility with other versions is not guaranteed.

=======
>>>>>>> c4ebf54 (Fixed README)
