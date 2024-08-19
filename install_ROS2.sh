#!/bin/bash

# IMPORTANT:
# Do not upgrade apt-get since it will break the image. libc-bin will for some
# reason break and not be able to install new stuff on the image.

#TODO: get this as a parameter
MIRTE_SRC_DIR=/usr/local/src/mirte

# Install ROS Noetic
sudo apt install software-properties-common -y
sudo add-apt-repository universe -y
sudo apt update && sudo apt install curl -y
sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null
sudo apt update
sudo apt install -y ros-humble-ros-base
sudo apt install -y ros-humble-xacro
sudo apt install -y ros-dev-tools
grep -qxF "source /opt/ros/humble/setup.bash" /home/mirte/.bashrc || echo "source /opt/ros/humble/setup.bash" >> /home/mirte/.bashrc
source /opt/ros/humble/setup.bash
sudo rosdep init
rosdep update

# Install computer vision libraries
#TODO: make dependecies of ROS package
sudo apt install -y python3-pip python3-wheel python3-setuptools python3-opencv libzbar0
sudo pip3 install pyzbar mergedeep

# Move custom settings to writabel filesystem
#cp $MIRTE_SRC_DIR/mirte-ros-packages/mirte_telemetrix/config/mirte_user_settings.yaml /home/mirte/.user_settings.yaml
#rm $MIRTE_SRC_DIR/mirte-ros-packages/mirte_telemetrix/config/mirte_user_settings.yaml
#ln -s /home/mirte/.user_settings.yaml $MIRTE_SRC_DIR/mirte-ros-packages/config/mirte_user_settings.yaml

# Install Mirte ROS package
python3 -m pip install mergedeep
mkdir -p /home/mirte/mirte_ws/src
cd /home/mirte/mirte_ws/src
ln -s $MIRTE_SRC_DIR/mirte-ros-packages .

# Install source dependencies for slam
sudo apt install ros-humble-slam-toolbox -y
sudo apt install libboost-all-dev -y
git clone https://github.com/AlexKaravaev/ros2_laser_scan_matcher
git clone https://github.com/AlexKaravaev/csm
git clone https://github.com/ldrobotSensorTeam/ldlidar_stl_ros2

cd ..
rosdep install -y --from-paths src/ --ignore-src --rosdistro humble
colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release
grep -qxF "source /home/mirte/mirte_ws/install/setup.bash" /home/mirte/.bashrc || echo "source /home/mirte/mirte_ws/install/setup.bash" >> /home/mirte/.bashrc
source /home/mirte/mirte_ws/install/setup.bash

# install missing python dependencies rosbridge
#sudo apt install -y libffi-dev libjpeg-dev zlib1g-dev
#sudo pip3 install twisted pyOpenSSL autobahn tornado pymongo

# Add systemd service to start ROS nodes
sudo rm /lib/systemd/system/mirte-ros.service
sudo ln -s $MIRTE_SRC_DIR/mirte-install-scripts/services/mirte-ros.service /lib/systemd/system/

sudo systemctl daemon-reload
sudo systemctl stop mirte-ros || /bin/true
#sudo systemctl start mirte-ros
#sudo systemctl enable mirte-ros

sudo usermod -a -G video mirte
sudo adduser mirte dialout
python3 -m pip install telemetrix-rpi-pico

# Install OLED dependencies (adafruit dependecies often break, so explicityle set to versions)
sudo apt install -y python3-bitstring libfreetype6-dev libjpeg-dev zlib1g-dev fonts-dejavu
sudo pip3 install adafruit-circuitpython-busdevice==5.1.1 adafruit-circuitpython-framebuf==1.4.9 adafruit-circuitpython-typing==1.7.0 Adafruit-PlatformDetect==3.22.1
sudo pip3 install pillow adafruit-circuitpython-ssd1306==2.12.1

if [[ $MIRTE_TYPE == "mirte-master" ]]; then
	# install lidar and depth camera
	cd /home/mirte/mirte_ws/src || exit 1
	git clone https://github.com/Slamtec/rplidar_ros.git -b ros2
	git clone https://github.com/rafal-gorecki/ros2_astra_camera.git -b master # compressed images image transport fixes, fork of orbbec/...
	git clone https://github.com/clearpathrobotics/clearpath_mecanum_drive_controller
	cd ../../
	mkdir temp
	cd temp || exit 1
	sudo apt install -y libudev-dev
	git clone https://github.com/libuvc/libuvc.git
	cd libuvc
	mkdir build && cd build
	cmake .. && make -j4
	sudo make install
	sudo ldconfig
	cd ../../../
	sudo rm -rf temp
	cd /home/mirte/mirte_ws/ || exit 1
	rosdep install -y --from-paths src/ --ignore-src --rosdistro humble
	colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release
	source ./install/setup.bash
	cd  src/ros2_astra_camera/astra_camera
	./scripts/install.sh
	sudo udevadm control --reload && sudo udevadm trigger
	cd ../../rplidar_ros
	./scripts/create_udev_rules.sh
fi
