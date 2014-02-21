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
It looks like you hit an issue when trying to install Crate Data.

Troubleshooting and basic usage information for Crate Data are available at:

    https://crate.io/documentation/

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

if [ $PY_VERSION = "2.4" -o $PY_VERSION = "2.5" ]; then
    DDBASE=true
else
    DDBASE=false
fi

# Install the necessary package sources
if [ $OS = "RedHat" ]; then
    echo -e "\033[34m\n* Installing YUM sources for Datadog\n\033[0m"
    sudo sh -c "echo -e '[datadog]\nname = Datadog, Inc.\nbaseurl = http://yum.datadoghq.com/rpm/\nenabled=1\ngpgcheck=0\npriority=1' > /etc/yum.repos.d/datadog.repo"

    printf "\033[34m* Installing the Datadog Agent package\n\033[0m\n"

    if $DDBASE; then
        sudo yum -y install datadog-agent-base
    else
        sudo yum -y install datadog-agent
    fi
elif [ $OS = "Debian" -o $OS = "Ubuntu" ]; then
    printf "\033[34m\n* Installing APT package sources for Datadog\n\033[0m\n"
    sudo sh -c "echo 'deb http://apt.datadoghq.com/ unstable main' > /etc/apt/sources.list.d/datadog.list"
    sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 C7A7DA52

    printf "\033[34m\n* Installing the Datadog Agent package\n\033[0m\n"
    sudo apt-get update
    if $DDBASE; then
        sudo apt-get install -y --force-yes datadog-agent-base
    else
        sudo apt-get install -y --force-yes datadog-agent
    fi
else
    printf "\033[31mYour OS or distribution are not supported by this install script.
Please follow the instructions on the Agent setup page:

    https://app.datadoghq.com/account/settings#agent\033[0m\n"
    exit;
fi

printf "\033[34m\n* Adding your API key to the Agent configuration: /etc/dd-agent/datadog.conf\n\033[0m\n"

if $DDBASE; then
    sudo sh -c "sed 's/api_key:.*/api_key: $apikey/' /etc/dd-agent/datadog.conf.example | sed 's/# dogstatsd_target :.*/dogstatsd_target: https:\/\/app.datadoghq.com/' > /etc/dd-agent/datadog.conf"
else
    sudo sh -c "sed 's/api_key:.*/api_key: $apikey/' /etc/dd-agent/datadog.conf.example > /etc/dd-agent/datadog.conf"
fi

printf "\033[34m* Starting the Agent...\n\033[0m\n"
sudo /etc/init.d/datadog-agent restart

# Datadog "base" installs don't have a forwarder, so we can't use the same
# check for the initial payload being sent.
if $DDBASE; then
printf "\033[32m
Your Agent has started up for the first time and is submitting metrics to
Datadog. You should see your Agent show up in Datadog shortly at:

    https://app.datadoghq.com/infrastructure\033[0m

If you ever want to stop the Agent, run:

    sudo /etc/init.d/datadog-agent stop

And to run it again run:

    sudo /etc/init.d/datadog-agent start
"
exit;
fi

# Wait for metrics to be submitted by the forwarder
printf "\033[32m
Your Agent has started up for the first time. We're currently verifying that
data is being submitted. You should see your Agent show up in Datadog shortly
at:

    https://app.datadoghq.com/infrastructure\033[0m

Waiting for metrics..."

c=0
while [ "$c" -lt "30" ]; do
    sleep 1
    echo -n "."
    c=$(($c+1))
done

$dl_cmd http://127.0.0.1:17123/status?threshold=0 > /dev/null 2>&1
success=$?
while [ "$success" -gt "0" ]; do
    sleep 1
    echo -n "."
    $dl_cmd http://127.0.0.1:17123/status?threshold=0 > /dev/null 2>&1
    success=$?
done

# Metrics are submitted, echo some instructions and exit
printf "\033[32m

Your Agent is running and functioning properly. It will continue to run in the
background and submit metrics to Datadog.

If you ever want to stop the Agent, run:

    sudo /etc/init.d/datadog-agent stop

And to run it again run:

    sudo /etc/init.d/datadog-agent start

\033[0m"