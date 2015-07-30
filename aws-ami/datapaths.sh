#!/bin/bash -e

API="http://169.254.169.254/latest/meta-data"
DEVICES=$(curl -s "$API/block-device-mapping/" | grep -v 'ami\|root')
DATA_PATH=""

for NAME in $DEVICES
do
  DEV=$(curl -s "$API/block-device-mapping/$NAME/")
  MNT=$(df | grep $(readlink -f /dev/$DEV) | sed -e 's/\s\+/ /g' | cut -d" " -f6)
  DATA_PATH="$DATA_PATH,$MNT/crate"
done

if [ -z "$DEVICES" -a "$DEVICES" != " " ]; then
  # no device has been found
  mkdir -p /var/lib/crate
  chown -R crate:crate /var/lib/crate
  DATA_PATH=",/var/lib/crate"
fi

echo "$DATA_PATH" | cut -c 2-
