<div id="table-of-contents">
<h2>Table of Contents</h2>
<div id="text-table-of-contents">
<ul>
<li><a href="#sec-1">1. Oracle XE in Ubuntu</a>
<ul>
<li><a href="#sec-1-1">1.1. Install Oracle XE package</a></li>
<li><a href="#sec-1-2">1.2. Usage</a></li>
<li><a href="#sec-1-3">1.3. Resources</a></li>
</ul>
</li>
</ul>
</div>
</div>
# Oracle XE in Ubuntu

Ubuntu installation scripts for Oracle XE database.

## Install Oracle XE package

-   Download Oracle XE RPM package from Oracle site

-   Convert to DEB and install:
    
        # The '-c' option includes package scripts.
        alien -c oracle-xe-11.2.0-1.0.x86_64.rpm
        dpkg -i oracle-xe_11.2.0-2_amd64.deb

## Usage

    The scripts must be run as root.
    
    Usage: ./install.sh [-i] [-s] [-h]
    
    Commands usually have longer counterparts.
      -h    - this screen
      -i    - convert RPM to DEB and install it (requires alien)
      -l    - configure Oracle Net Listener to listen on localhost not hostname (default: true)
      -s    - config /dev/shm only temporarily
    
    Example 1: ./install.sh
      Starts system configuration for Oracle XE.
      /dev/shm will be prepared on every system boot.
    
    Example 2: ./install.sh --tmp-shm --localhost false
      Starts system configuration for Oracle XE.
      It requires to run setup-shm-for-oracle-xe.sh before every first
      start of the DB after system reboot.
    
    Example 3: ./install.sh -i
      Converts Oracle XE from oracle-xe-11.2.0-1.0.x86_64.rpm to deb package
      and installs it. Then starts system configuration.
    
    Example 4: ./install.sh --help
      This screen.
    
    This script must be run as root.
    
    Edit Oracle XE configuration in oracle-xe-config.conf.

## Resources

The scripts have been written based on the following posts:

-   [Manish Raj's Blog - Installing oracle 11gr2](http://meandmyubuntulinux.blogspot.ca/2012/05/installing-oracle-11g-r2-express.html)

-   [Ask Ubuntu - How to install Oracle Express 11gR2?](http://askubuntu.com/questions/198163/how-to-install-oracle-express-11gr2)
