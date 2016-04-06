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
RED="\033[1;31m"
END="\033[0m\033[27m"


function prf() {
    printf "$INV$BRN$1$END\n"
}

function prf_err() {
    printf "\n$RED$1$END\n"
}


# OS/Distro Detection
if [ -f /etc/os-release ]; then
    # Arch Linux, Debian, Ubuntu
    . /etc/os-release
    OS=$ID
elif [ -f /etc/debian_version ]; then
    # Old Debian releases
    OS=Debian
elif [ -f /etc/redhat-release ]; then
    # Just mark as RedHat and we'll use Python version detection
    # to know what to install
    OS=RedHat
    # check for systemd
    rpm -q systemd >> /dev/null && SYSTEMD_AVAILABLE=0
elif [ -f /etc/lsb-release ]; then
    . /etc/lsb-release
    OS=$DISTRIB_ID
elif [ -f /etc/arch-release ]; then
    # Archlinux Docker image has an arch-release file instead of os-release
    OS="arch"
elif [ -f /etc/system-release ]; then
    # Amazon Linux
    OS=Amazon
else
    OS=$(uname -s)
fi

if [ $OS = "Darwin" ]; then
    prf_err "This script does not support installing on the Mac.
Please use the 1-step trial script available at https://crate.io/docs/."
    exit 1;
fi

# Make lower case
OS=${OS,,}

if [ $(id -u) -eq 0 ]; then
    ASROOT=" --asroot "
    OPTSUDO=""
else
    ASROOT=""
    OPTSUDO="sudo "
fi

# Set up a named pipe for logging
npipe=/tmp/$$.tmp
mknod $npipe p

# Log all output to a log for error checking
tee <$npipe $logfile &
exec 1>&-
exec 1>$npipe 2>&1
trap "rm -f $npipe" EXIT

function on_error() {
    prf_err "It looks like you hit an issue when trying to install Crate.

Troubleshooting and basic usage information for Crate are available at:

    https://crate.io/docs/

If you're still having problems, please send an email to support@crate.io
with the contents of crate-install.log and we'll do our very best to help you
solve your problem.\n"
}
trap on_error ERR


# Install the necessary package sources
if [ $OS = "redhat" -o $OS = "amazon" -o $OS = "amzn" ]; then

    rpm -q crate-release >> /dev/null && CRATE_RELEASE_AVAILABLE=0
    if [ "$CRATE_RELEASE_AVAILABLE" == "0" ]; then
        prf "* The crate repository is already installed"
    else
        prf "* Installing YUM sources for Crate\n"
        $OPTSUDO rpm --import https://cdn.crate.io/downloads/yum/RPM-GPG-KEY-crate
        if [ "$SYSTEMD_AVAILABLE" == "0" ]; then
            CRATE_RELEASE_RPM="https://cdn.crate.io/downloads/yum/7/noarch/crate-release-7.0-1.noarch.rpm"
        else
            CRATE_RELEASE_RPM="https://cdn.crate.io/downloads/yum/6/x86_64/crate-release-6.5-1.noarch.rpm"
        fi
        $OPTSUDO rpm -Uvh $CRATE_RELEASE_RPM
    fi

    rpm -q crate >> /dev/null && CRATE_AVAILABLE=0
    if [ "$CRATE_AVAILABLE" == "0" ]; then
        prf "* The Crate package is already installed"
    else
        prf "\n* Installing the Crate package\n\n"
        $OPTSUDO yum -y install crate
    fi

    prf "* Starting the Service...\n\n"
    if [ "$SYSTEMD_AVAILABLE" == "0" ]; then
        $OPTSUDO mkdir -p /opt/crate/data/crate
        $OPTSUDO chown crate:crate /opt/crate/data/crate
        $OPTSUDO systemctl daemon-reload
        $OPTSUDO systemctl enable crate.service
        $OPTSUDO systemctl start crate.service
    else
        $OPTSUDO mkdir -p /opt/crate/data/crate
        $OPTSUDO chown crate:crate /opt/crate/data/crate
        $OPTSUDO service crate start
    fi
elif [ $OS == "debian" ]; then
    install_java ()
    {
        # Install Java via WebUpd8Team repository
        prf "* Installing Java 8 from WebUpd8Team repository"
        echo "deb http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main" | $OPTSUDO tee - /etc/apt/sources.list.d/webupd8team-java.list
        echo "deb-src http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main" | $OPTSUDO tee -a /etc/apt/sources.list.d/webupd8team-java.list
        $OPTSUDO apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys EEA14886
        $OPTSUDO apt-get update
        $OPTSUDO apt-get install -y oracle-java8-installer
        $OPTSUDO apt-get install -y oracle-java8-set-default
    }
    prf "\n* Installing APT repository for Crate\n"
    $OPTSUDO apt-get install -y apt-transport-https
    $OPTSUDO wget https://cdn.crate.io/downloads/apt/DEB-GPG-KEY-crate
    $OPTSUDO apt-key add DEB-GPG-KEY-crate -y
    VERSION=$(cat /etc/debian_version | cut -d "." -f1)
    if [ $VERSION == "7" ]; then
        DISTRO="wheezy"
        if type -p java > /dev/null; then
            JAVA_VERSION=$(`which java` -version 2>&1 | awk -F '"' '/version/ {print $2}' | awk -F. '{printf("%03d%03d",$1,$2);}')
            if [ $JAVA_VERSION -lt "001008" ]; then
                install_java
            fi
        else
            install_java
        fi
    elif [ $VERSION == "8" ]; then
        DISTRO="jessie"
        if [ $($OPTSUDO grep -e backports /etc/apt/sources.list | wc -l) -lt 1 ]; then
          echo "deb http://http.debian.net/debian ${DISTRO}-backports main" | $OPTSUDO tee -a /etc/apt/sources.list
        fi
    else
        prf_err "Your version $VERSION is not supported by Crate."
        exit 1
    fi
    if [ $($OPTSUDO grep -e crate /etc/apt/sources.list | wc -l) -lt 2 ]; then
        echo "deb https://cdn.crate.io/downloads/apt/stable/ ${DISTRO} main" | $OPTSUDO tee -a /etc/apt/sources.list
        echo "deb-src https://cdn.crate.io/downloads/apt/stable/ ${DISTRO} main" | $OPTSUDO tee -a /etc/apt/sources.list
    fi
    $OPTSUDO apt-get update

    dpkg -s "crate" | grep "installed" && {
        prf "* The Crate package is already installed"
    } || {
        prf "\n* Installing the Crate package\n\n"
        $OPTSUDO apt-get install -y crate
    }

    prf "* Starting the Service...\n\n"
    $OPTSUDO mkdir -p /opt/crate/data/crate
    $OPTSUDO chown crate:crate /opt/crate/data/crate
    if type -p systemd > /dev/null; then
        $OPTSUDO systemctl enable crate
        $OPTSUDO systemctl status crate | grep "running" && {
            prf "* Crate is already running"
            $OPTSUDO systemctl restart crate
        } || {
            prf "* Starting the Service...\n\n"
            $OPTSUDO systemctl start crate
        }
    else
        $OPTSUDO service crate status | grep "running" && {
            prf "* Crate is already running"
            $OPTSUDO service crate restart
        } || {
            prf "* Starting the Service...\n\n"
            $OPTSUDO service crate start
        }
    fi
elif [ $OS = "ubuntu" ]; then
    prf "\n* Installing APT repository for Crate\n"
    $OPTSUDO apt-get install -y python-software-properties software-properties-common
    $OPTSUDO add-apt-repository -y ppa:crate/stable
    $OPTSUDO apt-get update

    dpkg -s "crate" | grep "installed" && {
        prf "* The Crate package is already installed"
    } || {
        prf "\n* Installing the Crate package\n\n"
        $OPTSUDO apt-get install -y crate
    }

    $OPTSUDO service crate status | grep "running" && {
        prf "* Crate is already running"
    } || {
        prf "* Starting the Service...\n\n"
        $OPTSUDO mkdir -p /opt/crate/data/crate
        $OPTSUDO chown crate:crate /opt/crate/data/crate
        $OPTSUDO service crate start

    }
elif [ $OS = "arch" ]; then
    prf "\n* Installing Crate from Arch Linux AUR\n"
    prf "\n* Ensuring binutils is installed\n"
    $OPTSUDO pacman -S --noconfirm --asdeps --needed binutils
    mkdir -p ~/builds
    if [ -d "~/builds/crate" ]; then
        prf "\n* Deleting old builds\n"
        rm -rf ~/builds/crate
    fi
    prf "\n* Getting build files\n"
    cd ~/builds && curl -O https://aur.archlinux.org/packages/cr/crate/crate.tar.gz
    cd ~/builds && tar xzvf crate.tar.gz
    prf "\n* building and installing crate package\n"
    cd ~/builds/crate && makepkg $ASROOT -sfi
    prf "\n* starting daemon\n"
    $OPTSUDO systemctl start crate
else
    prf_err "Your OS or distribution $OS is not supported by this install script.
Please visit

    https://crate.io/docs/

For help.\n"
    exit 1;
fi


prf "Your Crate Service has started up for the first time.

To checkout the admin UI open http://$(hostname -f):4200/admin in your browser
"
