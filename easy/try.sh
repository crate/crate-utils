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

INV="\\033[7m"
BRN="\\033[33m"
RED="\\033[31m"
END="\\033[0m\\033[27m"

function wait_for_user() {
    read -p "Press RETURN to continue or any other key to abort" -r -n1 -s x
    if [[ "$x" != '' ]]; then
        exit 1
    fi
}

function prf() {
    echo -e "$INV$BRN$1$END\\n"
}

function on_error() {
    echo -e "$RED
It looks like you hit an issue when trying CrateDB.

Troubleshooting and basic usage information for CrateDB are available at:

    https://crate.io/docs/
$END"
}
trap on_error ERR

function on_exit() {
    # kill crate on exit
    kill "$(jobs -p)"
}

function pre_start_cmd() {
    # display info about crate admin on non gui systems
    if [[ ! $OS = "Darwin" && ! -n $DISPLAY ]]; then
        [ "$(hostname -d)" ] && HOST=$(hostname -f) || HOST=$(hostname)
        prf "Crate will get started in foreground. To open crate admin goto

    http://$HOST:4200/admin\\n"
    fi
}

function post_start_cmd() {
    # open crate admin if system has gui
    if [[ $OS = "Darwin" || -n $DISPLAY ]]; then
        open 'http://localhost:4200/#/help'
    fi
}

function wait_until_running() {
    # wait until crate is listening on port 4200
    while ! nc -vz localhost 4200 > /dev/null 2>&1 /dev/null; do
        sleep 0.1
    done
}


# OS/Distro Detection
if [ -f /etc/debian_version ]; then
    OS=Debian
elif [ -f /etc/redhat-release ]; then
    # Just mark as RedHat and we'll use Python version detection
    # to know what to install
    OS=RedHat
elif [ -f /etc/lsb-release ]; then
    # shellcheck disable=SC1091
    . /etc/lsb-release
    OS=$DISTRIB_ID
elif [ -f /etc/os-release ]; then
    # Arch Linux
    # shellcheck disable=SC1091
    . /etc/os-release
    OS=$ID
elif [ -f /etc/system-release ]; then
    OS=Amazon
else
    OS=$(uname -s)
fi

function has_java() {
    if [ "$OS" = "Darwin" ]; then
        /usr/libexec/java_home &> /dev/null || {
            return 1
        }
    else
        if [ ! "$(command -v java)" ]; then
            return 1
        fi
    fi
    return 0
}

has_java || {
    # check if java is installed
    if [ "$OS" = "Darwin" ]; then
        echo -e "\\n$RED Please make sure you have java installed and it is on your path.\\n"
        echo -e "\\n To install java goto http://www.oracle.com/technetwork/java/javase/downloads/index.html$END\\n\\n"

        open http://www.oracle.com/technetwork/java/javase/downloads/index.html
    elif [ "$OS" = "RedHat" ]; then
            echo -e "\\n$RED Please make sure you have java installed and it is on your path.$END\\n\\n"
            echo -e "$RED You can install it by running

        sudo yum install java-1.8.0-openjdk$END\\n\\n"
    elif [ "$OS" = "Debian" ] || [ "$OS" = "Ubuntu" ]; then
            echo -e "\\n$RED Please make sure you have java installed and it is on your path.$END\\n\\n"
            echo -e "$RED You can install it by running

        sudo apt-get install openjdk-8-jdk$END\\n\\n"
    elif [ "$OS" = "arch" ]; then
            echo -e "\\n$RED Please make sure you have java installed and it is on your path.$END\\n\\n"
            echo -e "$RED You can install it by running

        sudo pacman -S jre8-openjdk$END\\n\\n"
    fi
    wait_for_user
    has_java || {
        echo -e "\\n$RED \\n Java is still not installed. Aborting.$END\\n\\n"
        exit 1
    }
}

if has_java ; then
    JAVA_FULL=$(java -version 2>&1 | awk '/version/ {gsub(/"/, "", $3); print $3}')
    JAVA_VERSION=$(echo "$JAVA_FULL" | awk '{split($1, parts, ".")} END {print (parts[1] == 1 ? parts[2] : parts[1])}')
    JAVA_UPDATE=$(echo "$JAVA_FULL" | awk '{split($1, parts, "_")} END {print parts[2]}')

    if [ "$JAVA_VERSION" -ge 9 ] || { [ "$JAVA_VERSION" -eq 8 ] && [ "$JAVA_UPDATE" -ge 20 ] ; }; then
      prf "Running CrateDB with Java $JAVA_VERSION."
    else
      echo -e "\\n$RED CrateDB requires Java 8 update 20 or later.$END\\n\\n"
      exit 1
    fi
fi

trap on_exit EXIT

STABLE_RELEASE_URL=$(curl -Ls -I -w "%{url_effective}" https://cdn.crate.io/downloads/releases/crate_stable | tail -n1)
STABLE_RELEASE_FILENAME=${STABLE_RELEASE_URL##*/}
STABLE_RELEASE_VERSION=$(echo "$STABLE_RELEASE_FILENAME" | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+')
STABLE_RELEASE_DIR="crate-$STABLE_RELEASE_VERSION"

if [ ! -d "$STABLE_RELEASE_DIR" ]; then
    prf "Hi and thank you for trying out CrateDB $STABLE_RELEASE_VERSION"
    sleep 2
    prf "\\n* Downloading CrateDB...\\n"
    curl -L --max-redirs 1 -f https://cdn.crate.io/downloads/releases/crate_stable > "$STABLE_RELEASE_FILENAME"
    mkdir "$STABLE_RELEASE_DIR" && tar -xzf "$STABLE_RELEASE_FILENAME" -C "$STABLE_RELEASE_DIR" --strip-components 1
else
    prf "\\n* CrateDB $STABLE_RELEASE_VERSION has already been downloaded."
fi

prf "\\n* Starting CrateDB...\\n"
pre_start_cmd
"$STABLE_RELEASE_DIR/bin/crate" &
wait_until_running
post_start_cmd
wait
