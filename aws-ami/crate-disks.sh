#!/bin/sh

# remove automount of ephemeral devices
sed -i "/ephemeral/d" /etc/cloud/cloud.cfg

API="http://169.254.169.254/latest/meta-data"
DEVICES=$(curl -s "$API/block-device-mapping/" | grep -v 'ami\|root')

for NAME in $DEVICES
do
  DEV=$(curl -s "$API/block-device-mapping/$NAME")
  IS_FORMATTED=$(file -sL /dev/$DEV | grep "filesystem")

  if [ ! -z "$IS_FORMATTED" -a "$IS_FORMATTED" != " " ]; then
    echo "Device is formatted and ready to mount!"
  else
    echo "Device is not formatted"
    # try to format the device
    mkfs.ext4 -F /dev/$DEV
  fi

  # mount the device
  mkdir -p /mnt/$DEV
  mount /dev/$DEV /mnt/$DEV
  if [ $? -eq 0 ]; then
    echo "mount successful!"
  else
    echo "mount failed!"
  fi

  mkdir -p /mnt/$DEV/crate
  chown -R crate:crate /mnt/$DEV/crate
done
