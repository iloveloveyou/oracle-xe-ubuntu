#!/bin/bash

ORACLE_XE_VERSION=11.2.0
ORACLE_XE_RPM_PACKAGE=oracle-xe-${ORACLE_XE_VERSION}-1.0.x86_64.rpm
ORACLE_XE_DEB_PACKAGE=oracle-xe_${ORACLE_XE_VERSION}-2_amd64.deb
FS_FILESIZE_MAX=6815744

#params: src-file target-dir
function copy_file() {
    target="${2}/${1}"
    if [ -r "${target}" ]; then
	echo "${target} already exists. Skipping."
    else
	cp ${1} ${2}
	check_result $? "${target} installed" "installing ${target}"
    fi
}

function convert_rpm_and_install() {
    if [ -z "${CONVERT_INSTALL_PACKAGE}" ]; then
	echo "Skipping RPM to DEB conversion."
	echo "Assuming ${ORACLE_XE_DEB_PACKAGE} is already installed."
	echo
	return
    fi

    command -v alien >/dev/null 2>&1
    check_result $? "alien is installed" "'alien' is required to convert RPM to DEB."

    # The '-c' option includes package scripts.
    alien -c "${ORACLE_XE_RPM_PACKAGE}"
    check_result $? "converted to deb package" "conversion to deb package"

    dpkg -i "${ORACLE_XE_DEB_PACKAGE}"
    check_result $? "${ORACLE_XE_DEB_PACKAGE} installed" "installation of ${ORACLE_XE_DEB_PACKAGE}"
}

function install_chkconfig() {
    # /sbin/chkconfig required in RedHats
    copy_file chkconfig /sbin
}

function install_shm() {
    # /etc/rc2.d/S01shm_load to ensure working env in on system boot
    if [ ! -z "${TEMP_SHM_INSTALL}" ]; then
	./setup-shm-for-oracle-xe.sh
    else
	copy_file S01shm_load /etc/rc2.d
    fi
}

function install_sysctl_file() {
    # required kernel parameters
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
    #TODO add only if not there
    echo "Adding ${1} to the 'dba' group, to allow start the database"
    adduser ${1} dba

    echo "Setting up env vars for user: ${1}"
    #TODO add vars to .bashrc only if they don't exist
    cp .oracle-xe-env.sh ~${1}/
    echo 'source ~/.oracle-xe-env.sh' >> ~${1}/.bashrc
}

function post_install_message() {
    echo
    echo "Start database: service oracle-xe start"
    echo
    echo "If there is: 'Connected to an idle instance.'"
    echo "It means that the Oracle XE is not started during booting."
    echo "Start it using: startup"
    echo
    echo "Shutdown from SQLPlus: shutdown immediate"
    echo
    echo "Make sure: chown -R oracle.dba /var/tmp/.oracle"
    echo
    echo "To create a new user:"
    echo "  sqlplus sys as sysdba"
    echo "  create user myuser identified by mypassword;"
    echo "  grant connect,resource to myuser;"
    echo
}

#params: test result, ok message, fail message
function check_result() {
    if [ "${1}" == "0" ]; then
	echo -e "   ["'\E[32m'"\033[1mOK\033[0m]     - ${2}"
    else
	echo -e "   ["'\E[31m'"\033[1mFAILED\033[0m] - ${3}"
	exit 1
    fi
}

function usage() {
    echo "Usage: $0 [-i] [-s]"
    echo
    echo "Commands usually have longer counterparts."
    echo "  -h    - this screen"
    echo "  -i    - convert RPM to DEB and install it (requires alien)"
    echo "  -s    - config /dev/shm only temporarily"
    echo
    echo "Example 1: $0"
    echo "  Starts system configuration for Oracle XE."
    echo
    echo "Example 2: $0 -i"
    echo "  Converts Oracle XE from ${ORACLE_XE_RPM_PACKAGE} to deb package"
    echo "  and installs it. Then starts system configuration."
    echo
    echo "This script must be run as root."

    exit 1
}

while [ ! -z "${1}" ]; do
    case "$1" in
	-i|--install-package)
	    CONVERT_INSTALL_PACKAGE=true; shift 1;;
	-s|--tmp-shm)
	    TEMP_SHM_INSTALL=true; shift 1;;
	-h|--help)
	    usage;;
	*)
	    echo "Unknown param: '${1}'"
	    usage;;
    esac
done

convert_rpm_and_install
install_chkconfig
install_shm
install_sysctl_file
load_new_kernel_parameters
check_swap_space
create_required_links
post_install_message
