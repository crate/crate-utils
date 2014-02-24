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
# Crate Try script

set -e


INV="\033[7m"
BRN="\033[33m"
RED="\033[31m"
END="\033[0m\033[27m"

if [ ! $(which java) ]; then
    printf "\n$RED Please make sure you have java installed and it is on your path.$END\n\n"
    exit 1
else
    JAVA_VER=$(java -version 2>&1 | sed 's/java version "\(.*\)\.\(.*\)\..*"/\1\2/; 1q')
    if [ ! "$JAVA_VER" -ge 17 ]; then
        printf "\n$RED Crate requires java version >= 1.6.$END\n\n"
        exit 1
    fi
fi

function prf() {
    printf "$INV$BRN$1$END\n"
}

function on_error() {
    printf "$RED
It looks like you hit an issue when trying Crate.

Troubleshooting and basic usage information for Crate are available at:

    https://crate.io/docs/
$END"
}
trap on_error ERR

function on_exit() {
    # kill crate on exit
    kill $(jobs -p)
}
trap on_exit EXIT

function pre_start_cmd() {
    # display info about crate admin on non gui systems
    OS=$(uname -s)
    if [[ ! $OS = "Darwin" && ! -n $DISPLAY ]]; then
        [ $(hostname -d) ] && HOST=$(hostname -f) || HOST=$(hostname)
        prf "Crate will get started in foreground. To open crate admin goto

    http://$HOST:4200/admin\n"
    fi
}

function post_start_cmd() {
    # open crate admin if system has gui
    OS=$(uname -s)
    if [[ $OS = "Darwin" || -n $DISPLAY ]]; then
        open http://localhost:4200/admin
    fi
}

function wait_until_running() {
    # wait until crate is listening on port 4200
    while ! nc -vz localhost 4200 > /dev/null 2>&1 /dev/null; do
        sleep 0.1
    done
}



if [ $(which curl) ]; then
    dl_cmd="curl -f"
else
    dl_cmd="wget --quiet -O-"
fi

if [ ! -d crate-0.22.2 ]; then
    prf "\n* Downloading CRATE...\n"
    $dl_cmd https://cdn.crate.io/downloads/releases/crate-0.22.2.tar.gz > crate-0.22.2.tar.gz
    tar xzf crate-0.22.2.tar.gz
else
    prf "\n* CRATE has already been downloaded."
fi

prf "\n* Starting CRATE...\n"
pre_start_cmd
crate-0.22.2/bin/crate -f &
wait_until_running
post_start_cmd
wait

