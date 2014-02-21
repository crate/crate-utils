#!/bin/bash
###############################################################################
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
gist_request=/tmp/agent-gist-request.tmp
gist_response=/tmp/agent-gist-response.tmp

if [ $(which curl) ]; then
    dl_cmd="curl -f"
else
    dl_cmd="wget --quiet"
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
    printf "\033[31m
It looks like you hit an issue when trying to install Crate.

Troubleshooting and basic usage information for Crate Data are available at:

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
else
    OS=$(uname -s)
fi

if [ $OS = "Darwin" ]; then
    printf "\033[31mThis script does not support installing on the Mac.

Please use the 1-step script available at https://app.datadoghq.com/account/settings#agent/mac.\033[0m\n"
    exit 1;
fi

# Python Detection
has_python=$(which python || echo "no")
if [ $has_python = "no" ]; then
    printf "\033[31mPython is required to install CRATE Data.\033[0m\n"
    exit 1;
fi

PY_VERSION=$(python -c 'import sys; print "%d.%d" % (sys.version_info[0], sys.version_info[1])')


# Install the necessary package sources
if [ $OS = "RedHat" ]; then

    if [ $(rpm -q crate-release) ]; then
        echo -e "\033[34m* The crate repository is already installed\033[0m"
    else
        echo -e "\033[34m\n* Installing YUM sources for Crate\n\033[0m"
        sudo sh -c "sudo rpm --import https://cdn.crate.io/downloads/yum/RPM-GPG-KEY-crate"
        sudo sh -c "sudo rpm -Uvh https://cdn.crate.io/downloads/yum/6/x86_64/crate-release-6.5-1.noarch.rpm"
    fi

    if [ $(rpm -q crate) ]; then
        echo -e "\033[34m* The Crate package is already installed\033[0m"
    else
        printf "\033[34m\n* Installing the Crate package\n\033[0m\n"
        sudo sh -c "sudo yum -y install crate"
    fi

    printf "\033[34m* Starting the Service...\n\033[0m\n"
    sudo mkdir -p /opt/crate/data/crate
    sudo chown crate:crate /opt/crate/data/crate
    sudo service crate start

elif [ $OS = "Debian" -o $OS = "Ubuntu" ]; then
    echo -e "\033[34m\n* Installing APT repository for Crate\n\033[0m"
    #sudo sh -c "sudo add-apt-repository ppa:crate/stable"
    #sudo sh -c "sudo apt-get update"

    dpkg -s "crate" | grep "installed" && {
        echo -e "\033[34m* The Crate package is already installed\033[0m"
    } || {
        printf "\033[34m\n* Installing the Crate package\n\033[0m\n"
        sudo sh -c "sudo apt-get install crate"
    }

    sudo service crate status | grep "running" && {
        echo -e "\033[34m* Crate is already running\033[0m"
    } || {
        printf "\033[34m* Starting the Service...\n\033[0m\n"
        sudo mkdir -p /opt/crate/data/crate
        sudo chown crate:crate /opt/crate/data/crate
        sudo service crate start

    }
else
    printf "\033[31mYour OS or distribution are not supported by this install script.
Please follow the instructions on the Agent setup page:

    https://app.datadoghq.com/account/settings#agent\033[0m\n"
    exit;
fi


printf "\033[32m
Your Crate Service has started up for the first time.

To checkout the admin UI open http://localhost:4200/admin in your browser
\033[0m
"

# exit successfully for now...
exit 0

