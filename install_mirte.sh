#!/bin/bash
set -xe

MIRTE_SRC_DIR=/usr/local/src/mirte
. $MIRTE_SRC_DIR/settings.sh || true # read settings, like MIRTE_TYPE
MIRTE_TYPE="${MIRTE_TYPE:-default}"  # default, mirte-master

# disable ipv6, as not all package repositories are available over ipv6
sudo tee /etc/apt/apt.conf.d/99force-ipv4 <<EOF
Acquire::ForceIPv4 "true";
EOF

# Update
sudo apt update || true
sudo bash -c 'echo "mirte ALL = (ALL) NOPASSWD: ALL" >> /etc/sudoers' # allow mirte to use sudo without password, needed for auto-shutdown on battery

# Install locales
sudo apt install -y locales
sudo locale-gen "nl_NL.UTF-8"
sudo locale-gen "en_US.UTF-8"
sudo update-locale LC_ALL=en_US.UTF-8 LANGUAGE=en_US.UTF-8

# Install vcstool
cp repos.yaml $MIRTE_SRC_DIR
cp download_repos.sh $MIRTE_SRC_DIR || true
cd $MIRTE_SRC_DIR || exit 1
./download_repos.sh

# Install dependencies to be able to run python3 (3 default)
sudo apt install -y python3 python3-pip python3-setuptools python3-venv

# Set piwheels as pip repo
sudo bash -c "echo '[global]' > /etc/pip.conf"
sudo bash -c "echo 'extra-index-url=https://www.piwheels.org/simple' >> /etc/pip.conf"

cd $MIRTE_SRC_DIR/mirte-install-scripts
./install_arduino.sh

# Install Mirte ROS2 packages
cd $MIRTE_SRC_DIR/mirte-install-scripts
./install_ROS2.sh

# Install Mirte Python package
if [[ "$INSTALL_PYTHON" = true ]]; then
	cd $MIRTE_SRC_DIR/mirte-python
	pip3 install .
fi

# Install Mirte Interface
if [[ "$INSTALL_WEB" = true ]]; then
	cd $MIRTE_SRC_DIR/mirte-install-scripts
	./install_web.sh
fi

# Install Jupyter Notebook
if [[ "$INSTALL_JUPYTER" = true ]]; then
	cd $MIRTE_SRC_DIR/mirte-install-scripts
	./install_jupyter_ros.sh
fi

# Install numpy
pip3 install numpy

# Install bluetooth
#cd $MIRTE_SRC_DIR/mirte-install-scripts || exit 1
#./install_bt.sh

# if building for mirte-master:
if [[ $MIRTE_TYPE == "mirte-master" ]]; then

	# set default password for root to ...
	sudo sed -i '/^root:/d' /etc/shadow
	echo 'root:$6$iPpuScKGQTiuJk9r$cBXX/s.8UBp0bvrshHRhw/tHcmU3.beHBfCyJgP8Qhjx2CEO5.dyyvKips6loYQocSTgS/qEYxPrOQd/.qVi70:19793:0:99999:7:::' | sudo tee -a /etc/shadow
	# Install Mirte Master
	cd $MIRTE_SRC_DIR/mirte-install-scripts || exit 1
	./install_mirte_master.sh
fi

# Install Mirte documentation
#cd $MIRTE_SRC_DIR/mirte-documentation
#sudo apt install -y python3-venv libenchant-dev
#python3 -m venv docs-env
#source docs-env/bin/activate
#pip install docutils==0.16.0 sphinx-tabs==3.2.0  #TODO: use files to freeze versions
#pip install wheel sphinx sphinx-prompt sphinx-rtd-theme sphinxcontrib-spelling sphinxcontrib-napoleon
#mkdir -p _modules/catkin_ws/src
#cd _modules
#ln -s $MIRTE_SRC_DIR/mirte-python .
#cd mirte-python
#pip install .
#source /opt/ros/noetic/setup.bash
#source /home/mirte/mirte_ws/devel/setup.bash
#cd ../../
#make html
#deactivate

if [[ "$INSTALL_VSCODE" = true ]]; then
	cd $MIRTE_SRC_DIR/mirte-install-scripts || exit 1
	./install_vscode.sh
fi

# install audio support to use with mirte-pioneer pcb and orange pi zero 2
sudo apt install pulseaudio libasound2-dev libespeak1 -y
pip3 install simpleaudio pyttsx3 || true # simpleaudio uses an old python install system. TODO: replace or update

# Install overlayfs and make sd card read only (software)
sudo apt install -y overlayroot
# Currently only instaling, not enabled

# Install overlayfs (enabling in sd image tools)
# Setup expand overlayfs
{
	# enable mirte-overlay service
	sudo rm /lib/systemd/system/mirte-overlay.service || true
	sudo ln -s $MIRTE_SRC_DIR/mirte-install-scripts/services/mirte-overlay.service /lib/systemd/system/
	sudo systemctl enable mirte-overlay.service
} 2>&1 | sed -u 's/^/overlayfs::: /' &

#sudo bash -c "echo 'overlayroot=\"tmpfs\"' >> /etc/overlayroot.conf"

# update time in /etc/fake-hwclock.data
sudo fake-hwclock save

# remove force ipv4
sudo rm /etc/apt/apt.conf.d/99force-ipv4 || true
sudo rm /etc/resolv.conf || true # remove resolv.conf to use the one from the network.
