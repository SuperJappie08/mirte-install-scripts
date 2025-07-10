#!/bin/bash
set -xe
MIRTE_SRC_DIR=/usr/local/src/mirte

# Fix for bug in systemd-resolved
# (https://askubuntu.com/questions/973017/wrong-nameserver-set-by-resolvconf-and-networkmanager)
# For the installation we need 8.8.8.8, but linking will be done in network_setup.sh
sudo rm -rf /etc/resolv.conf
sudo bash -c 'echo "nameserver 8.8.8.8" > /etc/resolv.conf'

# Make sure there are no conflicting hcdp-servers
sudo apt install -y dnsmasq-base
if [[ $(systemctl is-enabled hostadp >/dev/null) ]]; then
	systemctl disable hostapd
fi
# sed -i 's/#DNSStubListener=yes/DNSStubListener=no/g' /etc/systemd/resolved.conf # TODO: check this

# Install netplan (not installed on armbian) and networmanager (not installed by Raspberry)
#sudo apt install -y netplan.io
sudo apt install -y network-manager
#sudo cp $MIRTE_SRC_DIR/mirte-install-scripts/50-cloud-init.yaml /etc/netplan/
#sudo netplan apply
#sudo apt purge -y ifupdown

# Install wifi-connect
MY_ARCH=$(arch)
if [[ "$MY_ARCH" == "armv7l" ]]; then MY_ARCH="rpi"; fi
# TODO: check with armv7 if it works and dynamically download the correct version
# skip if amd64
if [[ "$MY_ARCH" != "x86_64" ]]; then
	if [[ "$MY_ARCH" == "aarch64" ]]; then
		wget https://github.com/ArendJan/balena-os-wifi-connect/releases/download/fix-zerotier/wifi-connect-aarch64-unknown-linux-gnu.zip
	fi
	if [[ "$MY_ARCH" == "???" ]]; then
		wget https://github.com/ArendJan/balena-os-wifi-connect/releases/download/fix-zerotier/wifi-connect-armv7-unknown-linux-gnueabihf.zip
	fi
	unzip wifi-connect*
	sudo mv wifi-connect /usr/local/sbin
	rm wifi-connect*
fi
# Added systemd service to account for fix: https://askubuntu.com/questions/472794/hostapd-error-nl80211-could-not-configure-driver-mode
sudo rm /lib/systemd/system/mirte-ap.service || true
sudo ln -s $MIRTE_SRC_DIR/mirte-install-scripts/services/mirte-ap.service /lib/systemd/system/

sudo systemctl daemon-reload
sudo systemctl stop mirte-ap || /bin/true
sudo systemctl start mirte-ap
sudo systemctl enable mirte-ap

# Added systemd service to check on boot error for OPi
sudo rm /lib/systemd/system/mirte-wifi-watchdog.service || true
sudo ln -s $MIRTE_SRC_DIR/mirte-install-scripts/services/mirte-wifi-watchdog.service /lib/systemd/system/

sudo systemctl daemon-reload
sudo systemctl stop mirte-wifi-watchdog || /bin/true
sudo systemctl start mirte-wifi-watchdog
sudo systemctl enable mirte-wifi-watchdog

# Install avahi
sudo apt install -y libnss-mdns
sudo apt install -y avahi-utils avahi-daemon
sudo apt install -y avahi-utils avahi-daemon # NOTE: Twice, since regular apt installation on armbian fails (https://forum.armbian.com/topic/10204-cant-install-avahi-on-armbian-while-building-custom-image/)

# Disable lo interface for avahi
sed -i 's/#deny-interfaces=eth1/deny-interfaces=lo/g' /etc/avahi/avahi-daemon.conf

# Install dependecies needed for setup script
sudo apt install -y inotify-tools wireless-tools

# Disable ssh root login
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config

# Install usb_ethernet script from EV3 (and apply the patch)
wget https://raw.githubusercontent.com/ev3dev/ev3-systemd/ev3dev-buster/scripts/ev3-usb.sh -P $MIRTE_SRC_DIR/mirte-install-scripts
sudo chown mirte:mirte $MIRTE_SRC_DIR/mirte-install-scripts/ev3-usb.sh
chmod +x $MIRTE_SRC_DIR/mirte-install-scripts/ev3-usb.sh
patch $MIRTE_SRC_DIR/mirte-install-scripts/ev3-usb.sh -i $MIRTE_SRC_DIR/mirte-install-scripts/fix_scripts/ev3-usb.patch
sudo bash -c 'echo "libcomposite" >> /etc/modules'
# remove g_serial from modules to let the ev3-usb script enable usb ethernet on the orange pi zero 1 as well.
sudo bash -c "sed -i '/g_serial/d' /etc/modules"

# Generate wifi password (TODO: generate random password and put on NTFS)
if [ ! -f /home/mirte/.wifi_pwd ]; then
	bash -c 'echo mirte_mirte > /home/mirte/.wifi_pwd'
fi

# Allow wifi_pwd to be modified using the web interface
sudo chmod 777 /home/mirte/.wifi_pwd

# Add hostname and make it writable
sudo bash -c 'echo "Mirte-XXXXXX" > /etc/hostname'
sudo chmod 777 /etc/hostname

# Fix for wpa_supplicant error
# sudo bash -c "echo 'match-device=driver:wlan0' >> /etc/NetworkManager/NetworkManager.conf"

# Fix for the aw859a (Orange Pi Zero2) driver. The wifi crashes when the bluetooth is
# working. We might need to see if bluetooth can be enabled after wifi was started
# correctly. For now, just disabling since we are not using it.
sudo systemctl disable aw859a-bluetooth || /bin/true
sudo systemctl disable bluetooth || /bin/true
sudo bash -c 'echo "install sprdbt_tty /bin/false" > /etc/modprobe.d/disable-sprdbt_tty.conf'
sudo bash -c 'echo "blacklist sprdbt_tty" > /etc/modprobe.d/disable-sprdbt_tty.conf'
sudo update-initramfs -u

# Disable armbian-led-state
sudo systemctl disable armbian-led-state || /bin/true

# set some network settings to have ROS2 working better https://autowarefoundation.github.io/autoware-documentation/main/installation/additional-settings-for-developers/network-configuration/dds-settings/#tune-system-wide-network-settings
cat <<EOF >>/etc/sysctl.d/10-cyclone-max.conf
# Increase the maximum receive buffer size for network packets
net.core.rmem_max=10485760  # 10Mib, default is 208 KiB

# IP fragmentation settings
net.ipv4.ipfrag_time=3  # in seconds, default is 30 s
net.ipv4.ipfrag_high_thresh=134217728  # 128 MiB, default is 256 KiB
EOF
sudo service procps force-reload
# Reboot after kernel panic
# The OPi has a fairly unstable wifi driver which might
# panic the kernel (at boot). Instead of waiting an unkown
# time and reboot manually, we will reboot automatically
sudo bash -c 'echo "kernel.panic = 10" > /etc/sysctl.conf'

rm -rf /etc/resolv.conf || true # remove resolv.conf to use the one from the network.
