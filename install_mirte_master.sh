#!/bin/bash
set -xe

MIRTE_SRC_DIR=/usr/local/src/mirte

if [[ ${type:=""} != "mirte_orangepi3b" ]]; then
	# Fix for wrong sound card
	sudo bash -c 'cat <<EOT >> /etc/asound.conf
defaults.pcm.card 1
defaults.ctl.card 1
EOT'

fi

cd $MIRTE_SRC_DIR/mirte-install-scripts/mirte-master/usb_switch/
sudo apt install libgpiod-dev -y
mkdir build
cd build
cmake ..
make -j
sudo ln -s $MIRTE_SRC_DIR/mirte-install-scripts/services/mirte-usb-switch.service /lib/systemd/system/
sudo systemctl daemon-reload
sudo systemctl stop mirte-usb-switch.service || /bin/true
sudo systemctl start mirte-usb-switch.service
sudo systemctl enable mirte-usb-switch.service

sudo ln -s $MIRTE_SRC_DIR/mirte-install-scripts/services/mirte-shutdown.service /lib/systemd/system/
sudo systemctl daemon-reload
sudo systemctl stop mirte-shutdown.service || /bin/true
sudo systemctl start mirte-shutdown.service
sudo systemctl enable mirte-shutdown.service

# create a gpio group and add mirte to it. This is needed to access the gpio ports, otherwise only sudo is allowed.
sudo groupadd gpiod
sudo usermod -a -G gpiod mirte
sudo echo '# udev rules for gpio port access through libgpiod
SUBSYSTEM=="gpio", KERNEL=="gpiochip*", GROUP="gpiod", MODE="0660"' | sudo tee /etc/udev/rules.d/60-gpiod.rules
# FIXME:(SuperJappie08): Is this neccessary? # pip install gpiod==1.5.4 # python3.8 version

# FIXME:(SuperJappie08): Is this neccessary?
# # chatgpt node stuff for @chris-pek
# pip install gtts playsound openai==0.28.0 sounddevice scipy SpeechRecognition soundfile transformers datasets pyyaml pydub Elevenlabs || true # some strange package versions
# pip install numpy==1.23.1                                                                                                                     # python3.8 fix

# mkdir ~/uboot_fix/
# cd ~/uboot_fix/
# # audio fix uboot for orange pi 3b
# if [[ ${type:=""} == "mirte_orangepi3b" ]]; then
# 	wget https://mirte.arend-jan.com/files/fixes/uboot/linux-u-boot-orangepi3b-edge_24.2.1_arm64__2023.10-S095b-P0000-H264e-V49ed-B11a8-R448a.deb
# 	sudo apt install ./linux-u-boot-orangepi3b-edge_24.2.1_arm64__2023.10-S095b-P0000-H264e-V49ed-B11a8-R448a.deb
# 	rm linux-u-boot-orangepi3b-edge_24.2.1_arm64__2023.10-S095b-P0000-H264e-V49ed-B11a8-R448a.deb
# 	cd ../
# 	rm -rf uboot_fix/
# fi

# cd ~/mirte_ws/src
# git clone --recurse-submodules https://github.com/arendjan/mirte-telemetrix-cpp.git

# FIXME:(SuperJappie08): Is this neccessary?
# cd ~/mirte_ws
# source /opt/ros/humble/setup.bash
# rosdep install -y --from-paths src/ --ignore-src --rosdistro humble
# colcon build --symlink-install --mixin release
