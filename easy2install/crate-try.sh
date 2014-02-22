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
# Crate Try script

set -e
logfile="crate-try.log"

if [ $(which curl) ]; then
    dl_cmd="curl -f"
else
    dl_cmd="wget --quiet -O-"
fi


function on_error() {
    printf "\033[31m
It looks like you hit an issue when trying Crate.

Troubleshooting and basic usage information for Crate are available at:

    https://crate.io/docs/

If you're still having problems, please send an email to support@crate.io
with the contents of crate-try.log and we'll do our very best to help you
solve your problem.\n\033[0m\n"
}
trap on_error ERR

function on_exit() {
    kill $(jobs -p)
}
trap on_exit EXIT

# OS/Distro Detection
if [ -f /etc/debian_version ]; then
    OS=Debian
elif [ -f /etc/redhat-release ]; then
    OS=RedHat
elif [ -f /etc/lsb-release ]; then
    . /etc/lsb-release
    OS=$DISTRIB_ID
else
    OS=$(uname -s)
fi


function post_start_cmd() {
    if [ -n $DISPLAY ]; then
        open http://localhost:4200/admin
    else
        printf "\033[31m
Crate has been started in foreground. Open crate admin at

    http://$(hostname):4200/admin

\n\033[0m\n"
    fi
}

function wait_until_running() {
    while ! nc -vz localhost 4200 > /dev/null 2>&1 /dev/null; do
        sleep 0.1
    done
}


printf "\033[34m\n* Downloading crate...\n\033[0m\n"
$dl_cmd https://cdn.crate.io/downloads/releases/crate-0.22.2.tar.gz > /tmp/crate-0.22.2.tar.gz
tar xvzf /tmp/crate-0.22.2.tar.gz

printf "\033[34m\n* Starting the Service...\n\033[0m\n"
crate-0.22.2/bin/crate -f &
wait_until_running
post_start_cmd
wait

