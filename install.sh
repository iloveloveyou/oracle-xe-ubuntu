#!/bin/bash

ORACLE_XE_VERSION=11.2.0
ORACLE_XE_RPM_PACKAGE=oracle-xe-${ORACLE_XE_VERSION}-1.0.x86_64.rpm
ORACLE_XE_DEB_PACKAGE=oracle-xe_${ORACLE_XE_VERSION}-2_amd64.deb
FS_FILESIZE_MAX=6815744
RUN_ON_LOCALHOST=true

#params: src-file target-dir
function copy_file() {
    target="${2}/${1}"
    if [ -r "${target}" ]; then
	print_ok "${target} exists"
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
    #echo "Loading new kernel parameters"
    service procps start
    [ $(sysctl -q fs.file-max | awk '/fs.file-max/ { print $3;}') -eq ${FS_FILESIZE_MAX} ]
    check_result $? "kernel param fs.file-max == ${FS_FILESIZE_MAX}" "'fs.file-max' in /etc/sysctl.d/60-oracle.conf should be set to ${FS_FILESIZE_MAX}."
}

function check_swap_space() {
    #TODO create tmp swap if needed
    [ $(free -m | awk ' /Swap/ { print $2; }') -ge 2048 ]
    check_result $? "minimum required swap space" "Oracle XE requires at least 2GB of swap space"
}

function install_awk() {
    if [ ! -x /bin/awk ]; then
	ln -s /usr/bin/awk /bin/awk
    fi
    [ -x /bin/awk ]
    check_result $? "/bin/awk" "must have AWK in /bin/awk"
}

function configure_oracle_xe() {
    oracle_xe_config=/etc/default/oracle-xe
    if [ ! -f ${oracle_xe_config} ]; then
	original_hostname="${HOSTNAME}"
	if [ "${RUN_ON_LOCALHOST}" == "true" ]; then
	    export HOSTNAME=localhost
	fi
	/etc/init.d/oracle-xe configure responseFile=oracle-xe-config.conf
	if [ -n "${HOSTNAME}" ]; then
	    export HOSTNAME="${original_hostname}"
	fi
    fi
    [ -f ${oracle_xe_config} ]
    check_result $? "Oracle XE configured (${oracle_xe_config})" "running Oracle XE config - try to run '/etc/init.d/oracle-xe configure' manually"
}

#params: username
function setup_user() {
    groups "${1}" | grep -q dba
    if [ $? != "0" ]; then
	echo "Adding ${1} to the 'dba' group, to allow to start/stop the database"
	adduser "${1}" dba
    fi

    copy_file .oracle-xe-env.sh ~${1}/
    #TODO add vars to .bashrc only if they don't exist
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
	print_ok "${2}"
    else
	print_failed "${3}"
	exit 1
    fi
}

#params: message
function print_ok() {
    echo -e "   ["'\E[32m'"\033[1mOK\033[0m]     - ${1}"
}

#params: message
function print_failed() {
    echo -e "   ["'\E[31m'"\033[1mFAILED\033[0m] - ${1}"
}

function usage() {
    echo "Usage: $0 [-i] [-s] [-h]"
    echo
    echo "Commands usually have longer counterparts."
    echo "  -h    - this screen"
    echo "  -i    - convert RPM to DEB and install it (requires alien)"
    echo "  -l    - configure Oracle Net Listener to listen on localhost not hostname (default: true)"
    echo "  -s    - config /dev/shm only temporarily"
    echo
    echo "Example 1: $0"
    echo "  Starts system configuration for Oracle XE."
    echo "  /dev/shm will be prepared on every system boot."
    echo
    echo "Example 2: $0 --tmp-shm --localhost false"
    echo "  Starts system configuration for Oracle XE."
    echo "  It requires to run setup-shm-for-oracle-xe.sh before every first"
    echo "  start of the DB after system reboot."
    echo
    echo "Example 3: $0 -i"
    echo "  Converts Oracle XE from ${ORACLE_XE_RPM_PACKAGE} to deb package"
    echo "  and installs it. Then starts system configuration."
    echo
    echo "Example 4: $0 --help"
    echo "  This screen."
    echo
    echo "This script must be run as root."
    echo
    echo "Edit Oracle XE configuration in oracle-xe-config.conf."

    exit 1
}

while [ ! -z "${1}" ]; do
    case "$1" in
	--dba-users)
	    DBA_USERS="${2}"; shift 2;;
	-i|--install-package)
	    CONVERT_INSTALL_PACKAGE=true; shift 1;;
	-l|--localhost)
	    RUN_ON_LOCALHOST="${2}"; shift 2;;
	-s|--tmp-shm)
	    TEMP_SHM_INSTALL=true; shift 1;;
	-h|--help)
	    usage;;
	*)
	    echo "Unknown param: '${1}'"
	    usage;;
    esac
done

if [ $(id -u) != "0" ]; then
    echo "You must be root user to run the script."
    exit 1
fi

convert_rpm_and_install
install_chkconfig
install_shm
install_sysctl_file
load_new_kernel_parameters
check_swap_space
install_awk
configure_oracle_xe
#setup_user
post_install_message
