#!/bin/bash
set -xe
echo "Starting networking fix script"
sudo systemctl stop mirte-shutdown
sudo systemctl stop mirte-ros
sudo apt update
# sudo apt-get upgrade -y "ros-humble-
cd /home/mirte/mirte_ws/src/mirte-ros-packages/
git fetch --all
git pull
git switch develop || true
cd /home/mirte/mirte_ws/src/ros2_astra_camera/
git fetch --all
git pull
cd /home/mirte/mirte_ws/
source ./install/setup.bash
rosdep install -y --from-paths src/ --ignore-src -r # The ROS DISTRO will be retrieved from the environment variable
source /home/mirte/mirte_ws/install/setup.bash
colcon build --symlink-install --packages-up-to mirte_fastdds_discovery_setup astra_camera mirte_bringup --mixin release
source /home/mirte/mirte_ws/install/setup.bash
# add MIRTE_FASTDDS=true to .mirte_settings.sh
echo "MIRTE_FASTDDS=true" >>/home/mirte/.mirte_settings.sh

cd /usr/local/src/mirte/mirte-install-scripts/

# overwrite file with new version
download_url="https://raw.githubusercontent.com/mirte-robot/mirte-install-scripts/refs/heads/develop/services/mirte_ros.sh"
curl -o /usr/local/src/mirte/mirte-install-scripts/services/mirte_ros.sh $download_url

echo "rebooting in 10 seconds"
sleep 10
sudo reboot now
#
