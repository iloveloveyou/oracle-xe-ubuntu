#!/bin/bash

ORACLE_XE_VERSION=11.2.0
ORACLE_XE_RPM_PACKAGE=oracle-xe-11.2.0-1.0.x86_64.rpm
ORACLE_XE_DEB_PACKAGE=oracle-xe-11.2.0-1.0.x86_64.deb
FS_FILESIZE_MAX=6815744

#params: src-file target-dir
function copy_file() {
    target="${2}/${1}"
    if [ -r "${target}" ]; then
	echo "${target} already exists. Skipping."
    else
	cp ${1} ${2}
    fi
}

function convert_rpm_to_deb() {
    #TODO check if alien is installed
    echo "Converting ${ORACLE_XE_RPM_PACKAGE} to ${ORACLE_XE_DEB_PACKAGE}:"
    # The '-c' option includes package scripts.
    alien -c "${ORACLE_XE_RPM_PACKAGE}"
    #TODO stop on error
}

function install_deb_package() {
    #TODO check if need to install deb package
    echo "Installing ${ORACLE_XE_DEB_PACKAGE}:"
    dpkg -i "${ORACLE_XE_DEB_PACKAGE}"
}

function install_chkconfig() {
    echo "Installing /sbin/chkconfig required in RedHats"
    chmod all+x chkconfig
    copy_file chkconfig /sbin
}

function install_shm() {
    echo "Installing /etc/rc2.d/S01shm_load to ensure working env in on system boot"
    chmod 755 S01shm_load
    copy_file S01shm_load /etc/rc2.d
}

function install_sysctl_file() {
    echo "Installing /etc/sysctl.d/60-oracle.conf"
    copy_file 60-oracle.conf /etc/sysctl.d
}

function load_new_kernel_parameters() {
    echo "Loading new kernel parameters"
    service procps start
    echo "Verifying: fs.file-max == ${FS_FILESIZE_MAX}"
    if [ $(sysctl -q fs.file-max | awk '/fs.file-max/ { print $3;}') != ${FS_FILESIZE_MAX} ]; then
	echo "ERROR: 'fs.file-max' in /etc/sysctl.d/60-oracle.conf should be set to ${FS_FILESIZE_MAX}."
	exit 1
    fi
}

function check_swap_space() {
    #TODO create tmp swap if needed
    echo "Checking minimum swap space required by Oracle XE."
    if [ $(free -m | awk ' /Swap/ { print $2; }') < 2048 ]; then
	echo "ERROR: Oracle XE requires minimum swap space of 2GB."
	exit 1
    fi
}

function create_required_links() {
    echo "Must have AWK in /bin/awk"
    if [ ! -x /bin/awk ]; then
	ln -s /usr/bin/awk /bin/awk
    fi
}

function set_oracle_xe_hostname() {
    #TODO Change host entries in the following files:
    echo "Change host entries in the following files:"
    echo /u01/app/oracle/product/${ORACLE_XE_VERSION}/xe/network/admin/listener.ora
    echo /u01/app/oracle/product/${ORACLE_XE_VERSION}/xe/network/admin/tnsnames.ora
}

function configure_oracle_xe() {
    #TODO automate running configuration script
    echo "Configuring database"
    /etc/init.d/oracle-xe configure
}

#params: username
function setup_user() {
    echo "Adding ${1} to the 'dba' group, to allow start the database"
    adduser ${1} dba

    echo "Setting up env vars for user: ${1}"
    #TODO add vars to .bashrc only if they don't exist
    cp .oracle-xe-env.sh ~${1}/
    echo 'source ~/.oracle-xe-env.sh' >> ~${1}/.bashrc
}

function post_install_message() {
    echo "Start database: service oracle-xe start"
    echo
    echo "If there is: Connected to an idle instance."
    echo "It means that the Oracle XE is not started during booting."
    echo "Start it using: startup"
    echo
    echo "To shutdown use: shutdown immediate"
    echo
    echo "Make sure: chown -R oracle.dba /var/tmp/.oracle"
    echo
    echo "To create a new user:"
    echo "  sqlplus sys as sysdba"
    echo "  create user myuser identified by mypassword;"
    echo "  grant connect,resource to myuser;"
    echo
}
