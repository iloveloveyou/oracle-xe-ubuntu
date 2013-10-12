#!/bin/bash

sudo -s

echo "Stopping Oracle XE..."
/etc/init.d/oracle-xe stop
ps -ef | grep oracle | grep -v grep | awk '{print $2}' | xargs kill

echo "Purging oracle-xe package..."
dpkg --purge oracle-xe
rm -r /u01
rm /etc/default/oracle-xe

echo "Removing rc.d file..."
update-rc.d -f oracle-xe remove

echo "Removing /etc/sysctl.d/60-oracle.conf"
rm -rf /etc/sysctl.d/60-oracle.conf
service procps start

echo "Reverting /dev/shm"
rm -rf /etc/rc2.d/S01shm_load

echo "Oracle XE has been removed."
