#!/bin/bash
set -xe
MIRTE_SRC_DIR=/usr/local/src/mirte

# Update
sudo apt update || true

# Install nodeenv
sudo apt install -y python3-pip python3-setuptools python3-wheel
# sudo -H pip install nodeenv
pipx install nodeenv # Could be installed from apt, but version is really old.

# Install nodeenv
nodeenv --node=18.0.0 $MIRTE_SRC_DIR/mirte-web-interface/node_env

# Install web interface
. $MIRTE_SRC_DIR/mirte-web-interface/node_env/bin/activate

# Install frontend
cd $MIRTE_SRC_DIR/mirte-web-interface/vue-frontend || exit 1
npm install .
npm rebuild
npm run build

# Install backend
cd $MIRTE_SRC_DIR/mirte-web-interface/nodejs-backend || exit 1
npm install .

cd $MIRTE_SRC_DIR/mirte-web-interface
git clone https://github.com/dheera/rosboard.git
sudo apt install python3-tornado
sudo apt install python3-numpy                      # Fist install simplejpeg dependencies
sudo pip install simplejpeg --break-system-packages # recommended, but ROSboard can fall back to cv2 or PIL instead

# Install wetty
#cd $MIRTE_SRC_DIR/mirte-web-interface
#npm -g install wetty
deactivate_node

# Install strace for linetrace functionality
sudo apt install -y strace
sudo apt install xxd

# Install nginx (as reverse proxy to all services)
sudo apt install -y nginx libnginx-mod-http-auth-pam
sudo cp $MIRTE_SRC_DIR/mirte-install-scripts/nginx.conf /etc/nginx/sites-available/mirte.conf
sudo cp $MIRTE_SRC_DIR/mirte-install-scripts/nginx_login.conf /etc/nginx/nginx_login.conf
sudo ln /etc/nginx/sites-available/mirte.conf /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default # otherwise this will catch :80 by default

# give nginx access to the passwords file for login
sudo usermod -aG shadow www-data

sudo cp $MIRTE_SRC_DIR/mirte-install-scripts/sites/401.html /var/www/html/

# Add systemd service
sudo rm /lib/systemd/system/mirte-web-interface.service || true
sudo ln -s $MIRTE_SRC_DIR/mirte-install-scripts/services/mirte-web-interface.service /lib/systemd/system/
sudo systemctl daemon-reload
sudo systemctl stop mirte-web-interface || /bin/true
sudo systemctl start mirte-web-interface
sudo systemctl enable mirte-web-interface

# install zerotier for better ros2 networking. User will need to manually join the network
curl -s https://install.zerotier.com | sudo bash
# remove zerotier identity as it otherwise will be the same for all devices using the same image
sudo rm /var/lib/zerotier-one/identity.public || true
sudo rm /var/lib/zerotier-one/identity.secret || true
# new identity should be generated on first boot
