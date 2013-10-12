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

echo "Oracle XE has been removed."
