sudo apt install unzip
mkdir ~/Downloads \
cd ~/Downloads \
wget "https://github.com/jensjanssen-project/LinuxShellCollection/archive/refs/heads/main.zip" \
unzip main.zip -d ~ \
cd ~/LinuxShellCollection-main \
chmod +x Pi4_SetupRos2HumbleCtlxSdk.sh \
./Pi4_SetupRos2HumbleCtlxSdk.sh