#!/bin/bash
###############################################################################
#
# CRATE Utilities: https://github.com/crate/crate-utils
#
# Licensed to CRATE Technology GmbH ("Crate") under one or more contributor
# license agreements.  See the NOTICE file distributed with this work for
# additional information regarding copyright ownership.  Crate licenses
# this file to you under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.  You may
# obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
# License for the specific language governing permissions and limitations
# under the License.
#
# However, if you have executed another commercial license agreement
# with Crate these terms will supersede the license and you may use the
# software solely pursuant to the terms of the relevant commercial agreement.
#
###############################################################################
#
# YUM repo install script.

set -e
logfile="crate-install.log"

INV="\033[7m"
BRN="\033[33m"
RED="\033[31m"
END="\033[0m\033[27m"

function prf() {
    printf "$INV$BRN$1$END\n"
}

# Set up a named pipe for logging
npipe=/tmp/$$.tmp
mknod $npipe p

# Log all output to a log for error checking
tee <$npipe $logfile &
exec 1>&-
exec 1>$npipe 2>&1
trap "rm -f $npipe" EXIT


function on_error() {
    printf "\033[31m
It looks like you hit an issue when trying to install Crate.

Troubleshooting and basic usage information for Crate are available at:

    https://crate.io/docs/

If you're still having problems, please send an email to support@crate.io
with the contents of crate-install.log and we'll do our very best to help you
solve your problem.\n\033[0m\n"
}
trap on_error ERR

# OS/Distro Detection
if [ -f /etc/debian_version ]; then
    OS=Debian
elif [ -f /etc/redhat-release ]; then
    # Just mark as RedHat and we'll use Python version detection
    # to know what to install
    OS=RedHat
elif [ -f /etc/lsb-release ]; then
    . /etc/lsb-release
    OS=$DISTRIB_ID
elif [ -f /etc/os-release ]; then
    # Arch Linux
    . /etc/os-release
    OS=$ID
elif [ -f /etc/system-release ]; then
    # Amazon Linux
    OS=Amazon
else
    OS=$(uname -s)
fi

if [ $OS = "Darwin" ]; then
    printf "\033[31mThis script does not support installing on the Mac.

Please use the 1-step trial script available at https://crate.io/download.\033[0m\n"
    exit 1;
fi

# Install the necessary package sources
if [ $OS = "RedHat" -o $OS = "Amazon" ]; then

    if [ $(rpm -q crate-release >> /dev/null) ]; then
        prf "* The crate repository is already installed"
    else
        prf "* Installing YUM sources for Crate\n"
        sudo sh -c "sudo rpm --import https://cdn.crate.io/downloads/yum/RPM-GPG-KEY-crate"
        sudo sh -c "sudo rpm -Uvh https://cdn.crate.io/downloads/yum/6/x86_64/crate-release-6.5-1.noarch.rpm"
    fi

    if [ $(rpm -q crate >> /dev/null) ]; then
        prf "* The Crate package is already installed"
    else
        prf "\n* Installing the Crate package\n\n"
        sudo sh -c "sudo yum -y install crate"
    fi

    prf "* Starting the Service...\n\n"
    sudo mkdir -p /opt/crate/data/crate
    sudo chown crate:crate /opt/crate/data/crate
    sudo service crate start

elif [ $OS = "Debian" -o $OS = "Ubuntu" ]; then
    prf "\n* Installing APT repository for Crate\n"
    sudo sh -c "sudo add-apt-repository ppa:crate/stable"
    sudo sh -c "sudo apt-get update"

    dpkg -s "crate" | grep "installed" && {
        prf "* The Crate package is already installed"
    } || {
        prf "\n* Installing the Crate package\n\n"
        sudo sh -c "sudo apt-get install crate"
    }

    sudo service crate status | grep "running" && {
        prf "* Crate is already running"
    } || {
        prf "* Starting the Service...\n\n"
        sudo mkdir -p /opt/crate/data/crate
        sudo chown crate:crate /opt/crate/data/crate
        sudo service crate start

    }
elif [ $OS = "arch" ]; then
    prf "\n* Installing Crate from Arch Linux AUR\n"
    prf "\n* Ensuring base-devel is installed\n"
    sudo sh -c "sudo pacman -S base-devel"
    sh -c "mkdir -p ~/builds"
    if [ -d "~/builds/crate" ]; then
        prf "\n* Deleting old builds\n"
        sh -c "rm -rf ~/builds/crate"
    fi
    prf "\n* Getting build files\n"
    sh -c "cd ~/builds && curl -O https://aur.archlinux.org/packages/cr/crate/crate.tar.gz"
    sh -c "cd ~/builds && tar xzvf crate.tar.gz"
    prf "\n* building crate package\n"
    sh -c "cd ~/builds/crate && makepkg -sf"
    prf "\n* installing crate package\n"
    sh -c "cd ~/builds/crate && sudo pacman -U crate-0.31.0-1-any.pkg.tar.xz"
    prf "\n* starting daemon\n"
    sudo sh -c "sudo systemctl start crate"
else
    printf "$REDYour OS or distribution are not supported by this install script.
Please visit

    https://crate.io/docs/

For help. $END\n"
    exit;
fi


prf "Your Crate Service has started up for the first time.

To checkout the admin UI open http://$(hostname -f):4200/admin in your browser
"
