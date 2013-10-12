#!/bin/bash

# To avoid MEMORY TARGET error:
# In Ubuntu /dev/shm is just symbolic link to /run/shm, but Oracle requires it
# to be separate mount point.

RAM_SIZE=$(free -m | awk '/Mem/ { print $2; }')

echo "Removing link from /dev/shm to /run/shm..."
sudo rm -rf /dev/shm

echo "Setting /dev/shm as shmfs with size set to the size of RAM: ${RAM_SIZE}m"
sudo mkdir /dev/shm
sudo mount -t tmpfs shmfs -o size=${RAM_SIZE}m /dev/shm

echo "Creating /var/lock/subsys if needed"
if [ ! -d /var/lock/subsys ]; then
    mkdir -p /var/lock/subsys
fi

echo "Creating /var/lock/subsys/listener file if needed"
if [ ! -r /var/lock/subsys/listener ]; then
    touch /var/lock/subsys/listener
fi
