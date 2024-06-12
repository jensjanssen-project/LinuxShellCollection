#!/usr/bin/env bash

#
# Clones ctrlX AUTOMATION SDK and
# installes the required files from ctrlx-automation-sdk-*.zip.
#

WORKING_DIR=$(pwd)
SDK_DIR=${WORKING_DIR}/ctrlx-automation-sdk
SEPARATION_LINE_1="===================================================================================================="
SEPARATION_LINE_2="----------------------------------------------------------------------------------------------------"

if [[ "--help" = $1 ]]; then
	echo ""
	echo "This script creates a local copy of the ctrlX AUTOMATION SDK github repository"
	echo "and installs the required files from the ctrlX AUTOMATION SDK zip archive."
	echo ""
	echo "During this process please enter the desired version (release) of the zip archive to install."
	echo ""
	exit 1
fi

echo ""
echo $SEPARATION_LINE_1
echo "Enter the desired version of the zip archive to install (e.g. 2.4.0)."
echo "This will be used as 'Tag' for the local github repository."
echo $SEPARATION_LINE_2
TAG=2.4.0
read -rp "Version ($TAG)? " TAG
if [ -z "$TAG" ]; then
	TAG=2.4.0
fi

echo ""
echo $SEPARATION_LINE_1
echo "Local SDK github repo: ${SDK_DIR}"
echo "Version (release):     ${TAG}"
echo $SEPARATION_LINE_2
read -rt 20 -p "OK? "

# Older versions have directories without x-permission so sudo ...
sudo rm -rf "${SDK_DIR}"/ 2>/dev/null

echo ""
echo $SEPARATION_LINE_1
echo "Cloning https://github.com/boschrexroth/ctrlx-automation-sdk.git ..."
echo $SEPARATION_LINE_2
git clone --quiet https://github.com/boschrexroth/ctrlx-automation-sdk.git
cd "$SDK_DIR" || exit

echo ""
echo $SEPARATION_LINE_1
echo "Checking out version (tag) ${TAG} ..."
echo $SEPARATION_LINE_2
# git checkout tags/${TAG}

cd "$WORKING_DIR" || exit

ZIP_ARCHIVE=ctrlx-automation-sdk-${TAG}.zip
# Delete existing zip archive
rm "$ZIP_ARCHIVE" 2>/dev/null

echo ""
echo $SEPARATION_LINE_1
DOWNLOAD_URL=https://github.com/boschrexroth/ctrlx-automation-sdk/releases/download/${TAG}/${ZIP_ARCHIVE}
echo "Downloading ${ZIP_ARCHIVE} ..."
echo $SEPARATION_LINE_2
wget -q "$DOWNLOAD_URL"

if [ ! -f "${ZIP_ARCHIVE}" ]; then
	echo ""
	echo "ERROR Could not download ${DOWNLOAD_URL}"
	exit 1
fi

# Create temp dir for unzip
ZIP_DIR=ctrlx-automation-sdk-${TAG}
# sudo required because in older zip archives some directories have no x permission (it's a bug)
sudo rm -rf "$ZIP_DIR" 2>/dev/null
mkdir "$ZIP_DIR"

echo ""
echo $SEPARATION_LINE_1
echo "Unzipping ctrlx-automation-sdk zip ..."
echo $SEPARATION_LINE_2
unzip -xKq "${ZIP_ARCHIVE}" -d "$ZIP_DIR"

echo ""
echo $SEPARATION_LINE_1
echo "Copying files from zip to local git repo, excepting existing files ..."
echo $SEPARATION_LINE_2
rsync -a --ignore-existing "$ZIP_DIR"/ctrlx-automation-sdk/* "$SDK_DIR"

# sudo required because in older zip archives some directories have no x permission (it's a bug)
sudo rm -rf "$ZIP_DIR" 2>/dev/null
rm "$ZIP_ARCHIVE" 2>/dev/null

cd "${SDK_DIR}" || exit

echo ""
echo $SEPARATION_LINE_1
echo "Setting permissions ..."
echo $SEPARATION_LINE_2

# Set drwxrwxr-x for directories and -rw-rw-r-- for files
find . \( -type d -exec chmod 775 {} \; \) -o \( -type f -exec chmod 664 {} \; \)
# oss.flatbuffers* so that oss.flatbuffers.1.12 also fits
chmod a+x bin/comm.datalayer/ubuntu22-gcc-aarch64/release/mddb_compiler
chmod a+x bin/comm.datalayer/ubuntu22-gcc-aarch64/release/dl_compliance
chmod a+x bin/oss.flatbuffers/ubuntu22-gcc-aarch64/release/flatc
chmod a+x bin/framework/ubuntu22-gcc-aarch64/rexroth-automation-frame

chmod a+x bin/comm.datalayer/ubuntu22-gcc-aarch64/mddb_compiler
chmod a+x bin/comm.datalayer/ubuntu22-gcc-aarch64/dl_compliance
chmod a+x bin/oss.flatbuffers/ubuntu22-gcc-aarch64/flatc
chmod a+x bin/framework/ubuntu22-gcc-aarch64/rexroth-automation-frame

# Add x permission to all .sh files
find . -name '*.sh' -exec chmod +x {} \;

cd "${SDK_DIR}"/deb || exit

echo ""
echo $SEPARATION_LINE_1
echo "Installing required component dpkg-scanpackages ..."
echo $SEPARATION_LINE_2
sudo apt-get install -y dpkg-dev

# Install debian package locally so that 'apt-get install' will find it (for building sample project snaps)
dpkg-scanpackages -m . >Packages

#sudo dpkg -i ctrlx-datalayer-2.6.1.deb
#sudo apt-get install -f

# Install the Package for ctrlX datalayer
# Get the current full path
FULL_PATH=$(pwd)

# Add package to sources list
echo "deb [trusted=yes] file:${FULL_PATH} ./" | sudo tee /etc/apt/sources.list.d/ctrlx-automation.list

# Ensure the APT system can access the directory and files
sudo chmod -R a+r "${FULL_PATH}"
sudo chown -R _apt:root "${FULL_PATH}"
sudo chmod a+X "${FULL_PATH}"


# Use newest sources list
sudo apt-get update

# Install newest ctrlx-datalayer package
#sudo apt-get install -y ctrlx-datalayer


set -e

echo " "
echo "============================================"
echo Installing snapcraft 6.x/stable
echo "============================================"
echo " "

sudo snap install snapcraft --channel=6.x/stable --classic


set -e

echo " "
echo "============================================"
echo Installing required Packages
echo "============================================"
echo " "
#
# This script installs debian packages required to build apps
# with the ctrlX AUTOMATION SDK.
#
# https://wiki.ubuntu.com/MultiarchSpec

#sudo dpkg --add-architecture arm64

DIST="$(lsb_release -sc)"
sudo echo "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports/ ${DIST} main restricted universe multiverse" | sudo tee /etc/apt/sources.list.d/multiarch-libs.list
sudo echo "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports/ ${DIST}-backports main restricted universe multiverse" | sudo tee -a /etc/apt/sources.list.d/multiarch-libs.list
sudo echo "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports/ ${DIST}-security main restricted universe multiverse" | sudo tee -a /etc/apt/sources.list.d/multiarch-libs.list
sudo echo "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports/ ${DIST}-updates main restricted universe multiverse" | sudo tee -a /etc/apt/sources.list.d/multiarch-libs.list

# Qualify architecture
#sudo sed -i 's/deb http:/deb [arch=amd64] http:/g' /etc/apt/sources.list

# Environment variable to enable/disable the use of certain CPU capabilities.
# 0x1: Disable all run-time detected optimizations
# see https://gnutls.org/manual/html_node/Debugging-and-auditing.html
# Fixes issue: "Method https has died unexpectedly! Sub-process https received signal 4"
# see https://askubuntu.com/questions/1420966/method-https-has-died-unexpectedly-sub-process-https-received-signal-4-after
export GNUTLS_CPUID_OVERRIDE=0x1

# Prevent prompt that ask to restart services
export DEBIAN_FRONTEND=noninteractive

sudo -E apt update
sudo -E apt upgrade

# install base packages ...
sudo -E apt install -y \
  zip \
  unzip \
  p7zip-full \
  git \
  apt-transport-https \
  whois \
  net-tools \
  pkg-config \
  jq \
  sshpass \
  dpkg-dev

# install python tools ...
sudo -E apt install -y \
  python3-pip \
  virtualenv

# install amd64 build tools ...
sudo -E apt install -y \
  build-essential \
  gdb \
  cmake

# install required amd64 packages ...
sudo -E apt install -y \
  libxml2-dev \
  uuid-dev \
  libbz2-1.0 \
  libzmq3-dev \
  libsystemd-dev \
  libssl-dev


