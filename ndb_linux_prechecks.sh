#!/usr/bin/env bash

# Copyright (c) 2010 - 2026 Nutanix Inc. All rights reserved.
# Author: era-dev@nutanix.com

ORACLE_DB="oracle_database"
POSTGRES_DB="postgres_database"
MARIA_DB="mariadb_database"
MYSQL_DB="mysql_database"
MONGODB_DB="mongodb_database"


LINE="  ----------------------------------------------------------------------------------"

SUCCESS="success"
FAIL="fail"
YES="YES"
NO="NO"
N_A="N/A"
NA="NA"
FALSE="false"
TRUE="true"
DETAILS="-d or --detailed"
SOFTWARE="software"
CONFIG="configuration"
SOFTWARE_DEP="software dependency"
CONFIG_DEP="configuration dependency"
package_manager="none"
global_status="$SUCCESS"
show_detailed="$FALSE"
NDB_DOC_URL="https://portal.nutanix.com/page/documents/details?targetId=Nutanix-NDB-User-Guide --> appendix --> Database server VM setup"
indent_detail="     "

cluster_port="9440"

internal_message="Below information is for internal use only"
internal_debug_message="DEPENDENCY_CHECK DEBUG INFORMATION"
DEBUG_DELIM="##"
VMINFO="vminfo"
vminfo_message="VMINFO DEBUG INFORMATION"

acl_ubuntu="^acl"
gcc="gcc"
readline="readline"
readline_ubuntu="libreadline"
readline_suse="libreadline"
unzip="unzip"
zip="zip"
libselinux_python="libselinux-python"
libselinux_python_rhel8="python3-libselinux"
libselinux_python_rhel="libselinux-python"
libselinux_python_ubuntu="python[3]*-selinux"
ifupdown_ubuntu="ifupdown"
net_tools_ubuntu="net-tools"
nftables_ubuntu="nftables"
tar_apt="^tar/"
tar_yum="tar"
tar_zypper="^tar-"
xfsprogs_mongodb_ubuntu_debian="xfsprogs"
libselinux_python_suse="libselinux"
lvcreate="lvcreate"
lvdisplay="lvdisplay"
lvscan="lvscan"
vgcreate="vgcreate"
vgdisplay="vgdisplay"
vgscan="vgscan"
pvcreate="pvcreate"
pvdisplay="pvdisplay"
pvscan="pvscan"
crontab="crontab"
lvm2="lvm2"
rsync="rsync"
bc="bc"
sshpass="sshpass"
ksh="ksh"
lsof="lsof"
systemd="systemd"
rsyslog="rsyslog"
logrotate="logrotate"
firewalld="firewalld"
ufw="ufw"
chrony="chrony"
dbus_uuidgen="dbus-uuidgen"
lsscsi="lsscsi"
make_pkg="make"
wget_pkg="wget"
openssh_server_yum="openssh-server"
openssh_server_apt="openssh-server"
openssl_devel_yum="openssl-devel"
openssl_devel_apt="libssl-dev"
pcre_devel_yum="pcre-devel"
pcre2_devel_yum="pcre2-devel"
pcre_devel_apt="libpcre3-dev"
pcre2_devel_apt="libpcre2-dev"
systemd_devel_yum="systemd-devel"
systemd_devel_apt="libsystemd-dev"
zlib_devel_yum="zlib-devel"
zlib_devel_apt="zlib1g-dev"
libxcrypt_compat="libxcrypt-compat"
iptables_nft_services="iptables-nft-services"

# This file serves the multiple purposes -
# 1. It is shared with customers so that they can validate their DB server VMs before registration.
# 2. It is invoked directly by nutest FTs.
# 3. It is called by the product code - as a part of pre-checks done before we submit a registration operation.
# For purposes 1 & 2, using of ndb_sudo and logging via era_priv_cmd.sh may not be required or desirable.
# So we set the default values as "sudo" and "" respectively.
# Also, customers who are comfortable with sudo commands being run on their VM, do not need
# to copy era_priv_cmd.sh or ndb_sudo before running this script.
era_sudo_script=""
prism_connectivity="NOT_CHECKED"
ndb_sudo_script="sudo"
show_detailed="$FALSE"

usage() {
    echo "   Syntax: $ ./era_linux_prechecks.sh -t|--database_type <database_type> -n|--ndb_drive_user <ndb_drive_user> [-c|--cluster_ip <cluster_ip>] [-p|--cluster_port] [-d|--detailed] [-s|--restricted_sudo]  [-u|--db_os_user <db_os_user>] [-w|--software_home <software_home>] [-g|--oracle_grid_home <oracle_grid_home>] [-h|--help]"
    echo "   Options:"
    echo "   -t | --database_type Database type can be: $ORACLE_DB, $POSTGRES_DB, $MARIA_DB, $MYSQL_DB, $MONGODB_DB"
    echo "   -n | --ndb_drive_user can be used to specify the user that you want to register the DBServer VM within NDB"
    echo "   -w | --software_home Database software installation directory (e.g., /usr/pgsql-16)"
    echo "   -g | --oracle_grid_home Oracle Grid Infrastructure home directory"
}

check_era_priv_cmd() {
    if [ ! -f "$era_sudo_script" ]; then
        echo "Error: era_priv_cmd.sh does not exist. Please copy the script at $HOME and provide execute permission."
        exit 1
    fi
}

check_ndb_sudo() {
    if [ ! -f "$ndb_sudo_script" ]; then
        echo "Error: ndb_sudo does not exist. Please copy the script at $HOME and provide execute permission."
        exit 1
    fi
}

check_ndb_drive_user_is_current() {
    if [ "$(id -un)" != "$ndb_drive_user" ]; then
        echo "Error: Current User is not '$ndb_drive_user'. Please re-run this script as the user that you want to register as with NDB or login as '$ndb_drive_user' and re-run the script again."
        exit 1
    fi
}

while [ "$1" != "" ]; do
    case "$1" in
        -t | --database_type )
            shift
            database_type="$1"
            ;;
        -d | --detailed )
            show_detailed="$TRUE"
            ;;
        -c | --cluster_ip )
            shift
            cluster_ip="$1"
            ;;
        -p | --cluster_port )
            shift
            cluster_port="$1"
            ;;
        -h | --help )
            usage
            exit
            ;;
        -e | --era_server )
            is_era_server_call="$TRUE"
            ;;
        # This flag forces the script to execute bash commands using ndb_sudo
        # When calling this script from the production code, ALWAYS set this flag
        # Some customers have sudo restrictions on their VMs- this script will
        # fail certain operations like provisioning for them if plain sudo is used.
        -s | --restricted_sudo )
            era_sudo_script="$HOME/era_priv_cmd.sh"
            ndb_sudo_script=$HOME/ndb_sudo
            check_era_priv_cmd
            check_ndb_sudo
            ;;
        -u | --db_os_user )
            shift
            db_os_user="$1"
            ;;
        -w | --software_home )
            shift
            software_home="$1"
            ;;
        -g | --oracle_grid_home )
            shift
            oracle_grid_home="$1"
            ;;
        -n | --ndb_drive_user )
            shift
            ndb_drive_user="$1"
            check_ndb_drive_user_is_current
            ;;
        * )
            usage
            exit 1
    esac
    shift
done

# Handle mandatory arguments here
# Database type
if [ -z "$database_type" ]; then
    echo ""
    echo "$LINE"
    echo "   Error: Database type not specified"
    usage
    echo "$LINE"
    echo ""
    exit 1
fi

# ndb_drive_user name check
if [ -z "$ndb_drive_user" ]; then
    echo "Error: Run as user not specified. Please provide the user that you wish to register the DBServer VM within NDB using -n|--ndb_drive_user option."
    usage
    exit 1
fi

# Validate database type
valid_database_type="$FALSE"
if [ "$database_type" = "$ORACLE_DB" ]; then
    valid_database_type="$TRUE"
elif [ "$database_type" = "$POSTGRES_DB" ]; then
    valid_database_type="$TRUE"
elif [ "$database_type" = "$MARIA_DB" ]; then
    valid_database_type="$TRUE"
elif [ "$database_type" = "$MYSQL_DB" ]; then
    valid_database_type="$TRUE"
elif [ "$database_type" = "$MONGODB_DB" ]; then
    valid_database_type="$TRUE"
fi

if [ "$valid_database_type" = "$FALSE" ]; then
    echo ""
    echo "$LINE"
    echo "   Error: Database '$database_type' is not supported by Era"
    echo "   Era supported database types: $ORACLE_DB, $POSTGRES_DB, $MARIA_DB, $MYSQL_DB, $MONGODB_DB"
    echo "$LINE"
    echo ""
    exit 1
fi

check_error() {
	if [ "$1" -ne 0 ]; then
        echo "$NO"
    else
        echo "$YES"
	fi
}

get_global_status() {
	if [ "$1" = "$SUCCESS" ]; then
	    if [ "$2" = "$NO" ]; then
            echo "$FAIL"
        else
            echo "$SUCCESS"
        fi
	else
	    echo "$FAIL"
	fi
}

global_temp_code=0

ten="          "
forty="$ten$ten$ten$ten"
indent1="    "
indent2="        "

print_function() {
    component="$1"
    component="${component:0:20}${forty:0:$((20 - ${#component}))}"
    printf '%20s' "${component}"
    echo " : $2"
}

detect_package_manager() {
    declare -A osPackageInfo;
    osPackageInfo[/etc/redhat-release]=yum
    osPackageInfo[/etc/arch-release]=pacman
    osPackageInfo[/etc/gentoo-release]=emerge
    osPackageInfo[/etc/SuSE-release]=zypper
    osPackageInfo[/etc/debian_version]=apt-get
    for f in "${!osPackageInfo[@]}"
    do
        if [ -f "$f" ];then
            echo "${osPackageInfo[$f]}"
        fi
    done
}

detect_package_manager2() {
  which yum > /dev/null 2>&1
  if [ "$?" -eq 0 ]
  then
    echo yum
    return
  fi
  which apt-get > /dev/null 2>&1
  if [ "$?" -eq 0 ]
  then
    echo apt-get
    return
  fi
  which zypper > /dev/null 2>&1
  if [ "$?" -eq 0 ]
  then
    echo zypper
    return
  fi
}

is_version8_os() {
  source /etc/os-release
  isValid=$(awk -v ver="$VERSION_ID" 'BEGIN{ print ((ver + 0) >= 8) }')
  if [ "$isValid" -eq 1 ];then
    echo "$TRUE"
  else
    echo "$FALSE"
  fi
}

is_version10_os() {
  source /etc/os-release
  isValid=$(awk -v ver="$VERSION_ID" 'BEGIN{ print ((ver + 0) >= 10) }')
  if [ "$isValid" -eq 1 ];then
    echo "$TRUE"
  else
    echo "$FALSE"
  fi
}

search_for_package() {
    if [ "$package_manager" = "yum" ]; then
        $ndb_sudo_script rpm -q "$1" > /dev/null 2>&1
    elif [ "$package_manager" = "apt-get" ]; then
        $ndb_sudo_script apt list --installed 2>/dev/null | grep "$1" > /dev/null 2>&1
    elif [ "$package_manager" = "zypper" ]; then
        $ndb_sudo_script rpm -qa | grep "$1" > /dev/null 2>&1
    else
        eraerror > /dev/null 2>&1
    fi
    global_temp_code="$?"
}

install_package_help() {
    if [ "$package_manager" = "yum" ]; then
        echo "$indent2$indent_detail  Tip: You can try 'sudo yum install $1 -y'"
    elif [ "$package_manager" = "apt-get" ]; then
        if [ ! -z "$2" ]; then
            echo "$indent2$indent_detail  Tip: You can try 'sudo apt-get install $2 -y'"
        else
            echo "$indent2$indent_detail  Tip: You can try 'sudo apt-get install $1 -y'"
        fi
    else
        eraerror > /dev/null 2>&1
    fi
    global_temp_code="$?"
}

user_exists(){
    id "$1" > /dev/null 2>&1
    global_temp_code="$?"
}

check_use_devicesfile() {
    lvmconfig_output=$($ndb_sudo_script lvmconfig --type full devices/use_devicesfile 2>/dev/null)
    effective_value=$(echo "$lvmconfig_output" | awk -F'=' '{print $2}' | tr -d ' ' | tr -d '\n')
    if [ -n "$effective_value" ]; then
        if [ "$effective_value" = "0" ] || [ "$effective_value" = "1" ]; then
            return "$effective_value"
        fi
    fi
    return 0
}

check_for_numa_off() {
    # handle commented lines in /etc/default/grub
    if $ndb_sudo_script grep -v '^#' /etc/default/grub | grep -q 'numa=off'; then
        return 0
    else
        return 1
    fi
}

check_for_transparent_hugepage() {
    # handle commented lines in /etc/default/grub
    if $ndb_sudo_script grep -v '^#' /etc/default/grub | grep -q 'transparent_hugepage=never'; then
        return 0
    else
        return 1
    fi
}

check_for_grub_blk_mq() {
    local scsi_ok=1
    local dm_ok=1
    if $ndb_sudo_script grep -v '^#' /etc/default/grub | grep -q 'scsi_mod.use_blk_mq=1'; then
        scsi_ok=0
    fi
    if $ndb_sudo_script grep -v '^#' /etc/default/grub | grep -q 'dm_mod.use_blk_mq=y'; then
        dm_ok=0
    fi
    if [ "$scsi_ok" -eq 0 ] && [ "$dm_ok" -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

check_sudoers_requiretty() {
    if $ndb_sudo_script grep -v '^#' /etc/sudoers 2>/dev/null | grep -qE '^\s*Defaults\s+requiretty'; then
        return 1
    else
        return 0
    fi
}


check_patroni_present() {
    if [ -f /usr/local/bin/patroni ] || [ -f /usr/bin/patroni ]; then
        return 0
    else
        return 1
    fi
}

check_patronictl_present() {
    if [ -f /usr/local/bin/patronictl ] || [ -f /usr/bin/patronictl ]; then
        return 0
    else
        return 1
    fi
}

check_haproxy_config() {
    local all_ok=0
    [ -f /usr/local/bin/haproxy ] || [ -f /usr/bin/haproxy ] || all_ok=1
    [ -f /usr/lib/systemd/system/haproxy.service ] || all_ok=1
    return $all_ok
}

check_etcd_present() {
    if [ -f /usr/local/bin/etcd ] || [ -f /usr/bin/etcd ]; then
        return 0
    else
        return 1
    fi
}

check_firewalld_active() {
    # Check if firewalld service is active
    if $ndb_sudo_script systemctl is-active firewalld 2>/dev/null | grep -q '^active$'; then
        return 0  # firewalld is active
    else
        return 1  # firewalld is not active
    fi
}

check_pip_packages() {
    local pip_list
    pip_list=$(python3 -m pip list 2>/dev/null)
    
    local all_ok=0
    echo "$pip_list" | grep -qi 'urllib3' || all_ok=1
    echo "$pip_list" | grep -qi 'psycopg2-binary' || all_ok=1
    echo "$pip_list" | grep -qi 'setuptools' || all_ok=1
    echo "$pip_list" | grep -qi 'cdiff' || all_ok=1
    echo "$pip_list" | grep -qi 'python-etcd' || echo "$pip_list" | grep -qi 'etcd3' || all_ok=1
    
    return $all_ok
}

check_sysctl_config() {
    local all_ok=0
    [ "$($ndb_sudo_script sysctl -n vm.zone_reclaim_mode 2>/dev/null)" = "0" ] || all_ok=1
    [ "$($ndb_sudo_script sysctl -n vm.max_map_count 2>/dev/null)" = "128000" ] || all_ok=1
    [ "$($ndb_sudo_script sysctl -n net.ipv4.tcp_fin_timeout 2>/dev/null)" = "30" ] || all_ok=1
    [ "$($ndb_sudo_script sysctl -n net.ipv4.tcp_keepalive_intvl 2>/dev/null)" = "30" ] || all_ok=1
    [ "$($ndb_sudo_script sysctl -n net.ipv4.tcp_keepalive_time 2>/dev/null)" = "120" ] || all_ok=1
    [ "$($ndb_sudo_script sysctl -n net.ipv4.tcp_max_syn_backlog 2>/dev/null)" = "4096" ] || all_ok=1
    [ "$($ndb_sudo_script sysctl -n net.ipv4.tcp_keepalive_probes 2>/dev/null)" = "6" ] || all_ok=1
    [ "$($ndb_sudo_script sysctl -n net.core.somaxconn 2>/dev/null)" = "4096" ] || all_ok=1
    
    return $all_ok
}

# Detect OS distribution from /etc/os-release
# Returns: RHEL, ROCKY_LINUX, UBUNTU, DEBIAN, OEL, SUSE or UNKNOWN
detect_os_distribution() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            rhel|redhat)
                echo "RHEL"
                ;;
            rocky)
                echo "ROCKY_LINUX"
                ;;
            ubuntu)
                echo "UBUNTU"
                ;;
            debian)
                echo "DEBIAN"
                ;;
            ol|oracle)
                echo "OEL"
                ;;
            sles|suse|opensuse*)
                echo "SUSE"
                ;;
            *)
                echo "UNKNOWN"
                ;;
        esac
    else
        echo "UNKNOWN"
    fi
}

# Detect OS version from /etc/os-release
detect_os_version() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$VERSION_ID"
    else
        echo "UNKNOWN"
    fi
}

# Detect database version based on database type using software_home
# Args: $1 = db_type, $2 = software_home (optional)
# Returns: version string or "UNKNOWN"
detect_database_version() {
    local db_type="$1"
    local sw_home="$2"
    local version="UNKNOWN"
    local version_output=""

    case "$db_type" in
        "$POSTGRES_DB")
            if [ -n "$sw_home" ] && [ -x "$sw_home/bin/pg_config" ]; then
                version=$($ndb_sudo_script "$sw_home/bin/pg_config" --version 2>/dev/null | cut -d' ' -f2)
            fi
            ;;
        "$MYSQL_DB")
            if [ -n "$sw_home" ] && [ -x "$sw_home/bin/mysql" ]; then
                version_output=$($ndb_sudo_script "$sw_home/bin/mysql" --version 2>/dev/null)
            fi
            if [ -n "$version_output" ]; then
                if echo "$version_output" | grep -q "Distrib"; then
                    # Format: mysql Ver 14.12 Distrib 5.0.77, ...
                    version=$(echo "$version_output" | awk '{print $5}' | sed 's/,.*//g' | sed 's/-.*//g')
                else
                    # Format: mysql Ver 5.7 for Linux ...
                    version=$(echo "$version_output" | awk '{print $3}' | sed 's/-.*//g')
                fi
            fi
            ;;
        "$MARIA_DB")
            if [ -n "$sw_home" ] && [ -x "$sw_home/bin/mariadb" ]; then
                version_output=$($ndb_sudo_script "$sw_home/bin/mariadb" --version 2>/dev/null)
            fi
            if [ -n "$version_output" ]; then
                if echo "$version_output" | grep -q "Distrib"; then
                    # Format: mariadb Ver 14.12 Distrib 5.0.77, ...
                    version=$(echo "$version_output" | awk '{print $5}' | sed 's/,.*//g' | sed 's/-.*//g')
                else
                    # Format: mariadb Ver 5.7 for Linux ...
                    version=$(echo "$version_output" | awk '{print $3}' | sed 's/-.*//g')
                fi
            fi
            ;;
        "$MONGODB_DB")
            local mongod_output=""
            if [ -n "$sw_home" ] && [ -x "$sw_home/bin/mongod" ]; then
                mongod_output=$($ndb_sudo_script "$sw_home/bin/mongod" --version 2>/dev/null)
                version=$(echo "$mongod_output" | grep 'db version' | awk '{print substr($3,2)}')
            fi
            ;;
        "$ORACLE_DB")
            if [ -n "$sw_home" ] && [ -x "$sw_home/bin/sqlplus" ]; then
                version_output=$($ndb_sudo_script env ORACLE_HOME="$sw_home" "$sw_home/bin/sqlplus" -version 2>/dev/null)
                # Prefer "Version" line (18c+, includes RU patch info), fall back to "Release" line (pre-18c)
                version=$(echo "$version_output" | grep "^Version" | awk '{print $2}')
                if [ -z "$version" ]; then
                    version=$(echo "$version_output" | grep "Release" | sed -n 's/.*Release \([0-9.]*\).*/\1/p')
                fi
            fi
            ;;
    esac

    if [ -z "$version" ] || [ "$version" = "" ]; then
        version="UNKNOWN"
    fi
    echo "$version"
}

# Args: $1 = oracle_grid_home path
# Returns: version string or "UNKNOWN"
detect_oracle_grid_version() {
    local grid_home="$1"
    local version="UNKNOWN"

    if [ -n "$grid_home" ] && [ -x "$grid_home/bin/sqlplus" ]; then
        # Extract full version from "Version" line (e.g., 19.3.0.0.0)
        version=$($ndb_sudo_script env ORACLE_HOME="$grid_home" "$grid_home/bin/sqlplus" -version 2>/dev/null | grep "^Version" | awk '{print $2}')
    fi

    if [ -z "$version" ] || [ "$version" = "" ]; then
        version="UNKNOWN"
    fi
    echo "$version"
}

user=`whoami`
package_manager=`detect_package_manager`
if [ -z "$package_manager" ]
then
# if package manager is null, use method 2 to detect package manager.
      package_manager=`detect_package_manager2`
fi
if [ "$package_manager" = 'yum' ]
then
  isVersion8=`is_version8_os`
  isVersion10=`is_version10_os`
fi
# configuration checks
# NOPASS check gets covered as part of sudo access
# Checking sudo NOPASS access through era_priv_cmd.sh script
$ndb_sudo_script -n true > /dev/null 2>&1
sudo_access=`check_error "$?"`
global_status=`get_global_status "$global_status" "$sudo_access"`

if [ "$sudo_access" = "$NO" ]; then
echo ""
echo "$LINE"
echo "$indent2                  ** Error **"
echo "$indent2 Sudo access with NOPASS is not enabled on this machine"
echo "$indent2 Please enable sudo with NOPASS and re-run this script"
echo "$LINE"
echo ""
# Below block is for internal use only
if [ "$is_era_server_call" = "$TRUE" ]; then
    echo "$internal_message"
    echo "$internal_debug_message"
    echo "$CONFIG $DEBUG_DELIM sudo_access $DEBUG_DELIM $NO $DEBUG_DELIM Make sure the user '$user' has sudo access"
    echo "$CONFIG $DEBUG_DELIM sudo_nopass_access $DEBUG_DELIM $NO $DEBUG_DELIM Make sure the user '$user' has sudo NOPASS access"
    echo "=================================="
fi
exit 1
fi

#checking if use_devicesfile is set to 1 in /etc/lvm/lvm.conf
if ! check_use_devicesfile; then
    echo ""
    echo "$indent2 Please change the use_devicesfile setting in the /etc/lvm/lvm.conf file from 1 to 0."
    exit 1
fi

# these checks are independent of the database type
# check if numa=off is set in /etc/default/grub
# we don't want to raise an error if numa=off is not set, but we want to inform the user
numa_configured="$YES"
if ! check_for_numa_off; then
    numa_configured="$NO"
fi

# check if transparent_hugepage=never is set in /etc/default/grub
# we don't want to raise an error if transparent_hugepage=never is not set, but we want to inform the user
transparent_hugepage_configured="$YES"
if ! check_for_transparent_hugepage; then
    transparent_hugepage_configured="$NO"
fi

(which crontab > /dev/null 2>&1) && ((crontab -l > /dev/null 2>&1) || (crontab -l 2>&1 | grep 'no crontab for' > /dev/null)) > /dev/null 2>&1
crontab_configured=`check_error "$?"`
global_status=`get_global_status "$global_status" "$crontab_configured"`

# check prism api connectivity
warn_curl="$FALSE"
skip_cluster_check="$FALSE"
if [ ! -z "$cluster_ip" ]; then
    which curl &>/dev/null
    if [ "$?" -ne 0 ]; then
        warn_curl="$TRUE"

    else
        curl -k -X GET --header 'Accept: application/json' --connect-timeout 10 'https://'"$cluster_ip"':'"$cluster_port"'/PrismGateway/services/rest/v2.0/cluster/' &>/dev/null
        prism_connectivity=`check_error "$?"`
        global_status=`get_global_status "$global_status" "$prism_connectivity"`
    fi
else
   skip_cluster_check="$TRUE"
fi

secure_paths_configured="$N_A"
# If the current user is not root, check if secure_path is configured in /etc/sudoers
if [ "$(id -u)" -ne 0 ]; then
  a=`$ndb_sudo_script which lvdisplay`; a="${a%/*}"; $ndb_sudo_script cat /etc/sudoers | grep secure_path | grep Default | grep "$a" > /dev/null 2>&1
  secure_paths_configured=`check_error $?`
  global_status=`get_global_status "$global_status" "$secure_paths_configured"`
fi

# software checks
xfsprogs_present="$N_A"
if [ "$database_type" = "mongodb_database" ] && [ "$package_manager" = "apt-get" ]; then
    search_for_package "$xfsprogs_mongodb_ubuntu_debian"
    xfsprogs_present=`check_error "$global_temp_code"`
    global_status=`get_global_status "$global_status" "$xfsprogs_present"`
fi

nftables_present="$N_A"
if [ "$database_type" = "postgres_database" ] && [ "$package_manager" = "apt-get" ]; then
    search_for_package "$nftables_ubuntu"
    nftables_present=`check_error "$global_temp_code"`
    global_status=`get_global_status "$global_status" "$nftables_present"`
fi

grub_blk_mq_configured="$N_A"
if check_for_grub_blk_mq; then
    grub_blk_mq_configured="$YES"
else
    grub_blk_mq_configured="$NO"
fi

sudoers_requiretty_configured="$N_A"
if [ "$database_type" = "postgres_database" ]; then
  if check_sudoers_requiretty; then
    sudoers_requiretty_configured="$YES"
  else
    sudoers_requiretty_configured="$NO"
  fi
fi


patroni_present="$N_A"
if [ "$database_type" = "$POSTGRES_DB" ]; then
    if check_patroni_present; then
        patroni_present="$YES"
    else
        patroni_present="$NO"
    fi
fi
patronictl_present="$N_A"
if [ "$database_type" = "$POSTGRES_DB" ]; then
    if check_patronictl_present; then
        patronictl_present="$YES"
    else
        patronictl_present="$NO"
    fi
fi

haproxy_configured="$N_A"
if [ "$database_type" = "$POSTGRES_DB" ]; then
    if check_haproxy_config; then
        haproxy_configured="$YES"
    else
        haproxy_configured="$NO"
    fi
fi

etcd_present="$N_A"
if [ "$database_type" = "$POSTGRES_DB" ]; then
    if check_etcd_present; then
        etcd_present="$YES"
    else
        etcd_present="$NO"
    fi
fi

pip_packages_configured="$N_A"
if [ "$database_type" = "$POSTGRES_DB" ]; then
    if check_pip_packages; then
        pip_packages_configured="$YES"
    else
        pip_packages_configured="$NO"
    fi
fi

sysctl_config_configured="$N_A"
if check_sysctl_config; then
    sysctl_config_configured="$YES"
else
    sysctl_config_configured="$NO"
fi

# Firewall manager presence by distro family
firewalld_present="$N_A"
ufw_present="$N_A"
# Only enforce firewall presence for MySQL database type
if [ "$database_type" = "$MYSQL_DB" ]; then
    if [ "$package_manager" = "yum" ]; then
        # RHEL-like distros should have firewalld
        search_for_package "$firewalld"
        firewalld_present=`check_error "$global_temp_code"`
        global_status=`get_global_status "$global_status" "$firewalld_present"`
    elif [ "$package_manager" = "apt-get" ]; then
        # Ubuntu/Debian should have ufw
        search_for_package "$ufw"
        ufw_present=`check_error "$global_temp_code"`
        global_status=`get_global_status "$global_status" "$ufw_present"`
    fi
fi

firewalld_active="$N_A"
if [ "$database_type" = "$POSTGRES_DB" ] && [ "$package_manager" = "apt-get" ]; then
    if check_firewalld_active; then
        firewalld_active="$YES"
    else
        firewalld_active="$NO"
    fi
fi

# MySQL: SELinux should be permissive (or disabled) unless proper labels are configured
selinux_permissive="$N_A"
if [ "$database_type" = "$MYSQL_DB" ] || [ "$database_type" = "$POSTGRES_DB" ]; then
    # Prefer sestatus (persistent config) over runtime getenforce
    if command -v sestatus >/dev/null 2>&1; then
        # If SELinux is disabled, treat as permissive for our purposes
        selinux_status=`$ndb_sudo_script sestatus 2>/dev/null | awk -F: '/SELinux status/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print tolower($2)}'`
        if [ "$selinux_status" = "disabled" ]; then
            selinux_permissive="$YES"
        else
            # Check desired boot mode from config file (persistent)
            mode_from_cfg=`$ndb_sudo_script sestatus 2>/dev/null | awk -F: '/Mode from config file/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print tolower($2)}'`
            echo "$mode_from_cfg" | grep -qi 'permissive'
            selinux_permissive=`check_error "$?"`
        fi
    fi
    if [ "$database_type" = "$MYSQL_DB" ]; then
        global_status=`get_global_status "$global_status" "$selinux_permissive"`
    fi
fi

if [ "$database_type" = "$MONGODB_DB" ]; then
    db_os_user="${db_os_user:-mongod}"
    user_exists "$db_os_user"
    db_os_user_exist=`check_error "$global_temp_code"`
    global_status=`get_global_status "$global_status" "$db_os_user_exist"`
fi

if [ "$database_type" = "$POSTGRES_DB" ]; then
    db_os_user="${db_os_user:-postgres}"
    user_exists "$db_os_user"
    db_os_user_exist=`check_error "$global_temp_code"`
    global_status=`get_global_status "$global_status" "$db_os_user_exist"`
fi

if [ "$database_type" = "$MYSQL_DB" ]; then
    db_os_user="${db_os_user:-mysql}"
    user_exists "$db_os_user"
    db_os_user_exist=`check_error "$global_temp_code"`
    global_status=`get_global_status "$global_status" "$db_os_user_exist"`
fi

acl_present="$N_A"
if [ "$package_manager" = "apt-get" ]; then
    search_for_package "$acl_ubuntu"
    acl_present=`check_error "$global_temp_code"`
    global_status=`get_global_status "$global_status" "$acl_present"`
fi

gcc_present="$N_A"
if [ "$database_type" = "oracle_database" ] || [ "$database_type" = "$POSTGRES_DB" ]; then
    $ndb_sudo_script gcc -v > /dev/null 2>&1
    gcc_present=`check_error "$?"`
    if [ "$database_type" = "oracle_database" ]; then
        global_status=`get_global_status "$global_status" "$gcc_present"`
    fi
fi

bc_present="$N_A"
if [ "$database_type" = "oracle_database" ]; then
    $ndb_sudo_script bc -v > /dev/null 2>&1
    bc_present=`check_error "$?"`
    global_status=`get_global_status "$global_status" "$bc_present"`
fi

sshpass_present="$N_A"
if [ "$database_type" = "oracle_database" ]; then
    $ndb_sudo_script sshpass -V > /dev/null 2>&1
    sshpass_present=`check_error $?`
    global_status=`get_global_status "$global_status" "$sshpass_present"`
fi

ksh_present="$N_A"
if [ "$database_type" = "oracle_database" ]; then
    search_for_package "$ksh"
    ksh_present=`check_error "$global_temp_code"`
    global_status=`get_global_status "$global_status" "$ksh_present"`

fi

chrony_present="$N_A"
if [ "$database_type" = "$MYSQL_DB" ]; then
    search_for_package "$chrony"
    chrony_present=`check_error "$global_temp_code"`
    global_status=`get_global_status "$global_status" "$chrony_present"`
fi

# PostgreSQL HA build dependencies (warning-only, not blocking)
make_present="$N_A"
if [ "$database_type" = "$POSTGRES_DB" ]; then
    $ndb_sudo_script make -v > /dev/null 2>&1
    make_present=`check_error "$?"`
    # Not updating global_status - HA dependencies are optional for registration
fi


wget_present="$N_A"
if [ "$database_type" = "$POSTGRES_DB" ]; then
    which wget > /dev/null 2>&1
    wget_present=`check_error "$?"`
    # Not updating global_status - HA dependencies are optional for registration
fi

openssh_server_present="$N_A"
if [ "$database_type" = "$POSTGRES_DB" ]; then
    if [ "$package_manager" = "yum" ]; then
        search_for_package "$openssh_server_yum"
        openssh_server_present=`check_error "$global_temp_code"`
    elif [ "$package_manager" = "apt-get" ]; then
        search_for_package "$openssh_server_apt"
        openssh_server_present=`check_error "$global_temp_code"`
    fi
    global_status=`get_global_status "$global_status" "$openssh_server_present"`
fi

openssl_devel_present="$N_A"
if [ "$database_type" = "$POSTGRES_DB" ]; then
    if [ "$package_manager" = "yum" ]; then
        search_for_package "$openssl_devel_yum"
        openssl_devel_present=`check_error "$global_temp_code"`
    elif [ "$package_manager" = "apt-get" ]; then
        search_for_package "$openssl_devel_apt"
        openssl_devel_present=`check_error "$global_temp_code"`
    fi
    # Not updating global_status - HA dependencies are optional for registration
fi

pcre_devel_present="$N_A"
if [ "$database_type" = "$POSTGRES_DB" ]; then
    if [ "$package_manager" = "yum" ]; then
        search_for_package "$pcre_devel_yum"
        if [ "$global_temp_code" -eq 0 ]; then
            pcre_devel_present="$YES"
        else
            search_for_package "$pcre2_devel_yum"
            pcre_devel_present=`check_error "$global_temp_code"`
        fi
    elif [ "$package_manager" = "apt-get" ]; then
        search_for_package "$pcre_devel_apt"
        if [ "$global_temp_code" -eq 0 ]; then
            pcre_devel_present="$YES"
        else
            search_for_package "$pcre2_devel_apt"
            pcre_devel_present=`check_error "$global_temp_code"`
        fi
    fi
    # Not updating global_status - HA dependencies are optional for registration
fi

systemd_devel_present="$N_A"
if [ "$database_type" = "$POSTGRES_DB" ]; then
    if [ "$package_manager" = "yum" ]; then
        search_for_package "$systemd_devel_yum"
        systemd_devel_present=`check_error "$global_temp_code"`
    elif [ "$package_manager" = "apt-get" ]; then
        search_for_package "$systemd_devel_apt"
        systemd_devel_present=`check_error "$global_temp_code"`
    fi
    # Not updating global_status - HA dependencies are optional for registration
fi

zlib_devel_present="$N_A"
if [ "$database_type" = "$POSTGRES_DB" ]; then
    if [ "$package_manager" = "yum" ]; then
        search_for_package "$zlib_devel_yum"
        zlib_devel_present=`check_error "$global_temp_code"`
    elif [ "$package_manager" = "apt-get" ]; then
        search_for_package "$zlib_devel_apt"
        zlib_devel_present=`check_error "$global_temp_code"`
    fi
    # Not updating global_status - HA dependencies are optional for registration
fi

ifupdown_present="$N_A"
if [ "$package_manager" = "apt-get" ]; then
    search_for_package "$ifupdown_ubuntu"
    ifupdown_present=`check_error "$global_temp_code"`
    global_status=`get_global_status "$global_status" "$ifupdown_present"`
fi

net_tools_present="$N_A"
if [ "$package_manager" = "apt-get" ]; then
    search_for_package "$net_tools_ubuntu"
    net_tools_present=`check_error "$global_temp_code"`
    global_status=`get_global_status "$global_status" "$net_tools_present"`
fi
# conditional check for readline
readline_present="$NO"
if [ "$package_manager" = "yum" ]; then
    readline_present="$YES"
elif [ "$package_manager" = "apt-get" ]; then
    search_for_package "$readline_ubuntu"
    readline_present=`check_error "$global_temp_code"`
elif [ "$package_manager" = "zypper" ]; then
    search_for_package "$readline_suse"
    readline_present=`check_error "$global_temp_code"`
fi
global_status=`get_global_status "$global_status" "$readline_present"`

# conditional check for tar
tar_present="$NO"
if [ "$package_manager" = "yum" ]; then
    search_for_package "$tar_yum"
    tar_present=`check_error "$global_temp_code"`
elif [ "$package_manager" = "apt-get" ]; then
    search_for_package "$tar_apt"
    tar_present=`check_error "$global_temp_code"`
elif [ "$package_manager" = "zypper" ]; then
    search_for_package "$tar_zypper"
    tar_present=`check_error "$global_temp_code"`
fi
global_status=`get_global_status "$global_status" "$tar_present"`

# conditional check for libselinux-python
libselinux_present="$NO"
if [ "$package_manager" = "yum" ]; then
     if [ "$isVersion8" = "true" ]; then
      search_for_package "$libselinux_python_rhel8"
      libselinux_present=`check_error "$global_temp_code"`
    else
      search_for_package "$libselinux_python_rhel"
      libselinux_present=`check_error "$global_temp_code"`
    fi
elif [ "$package_manager" = "apt-get" ]; then
    search_for_package "$libselinux_python_ubuntu"
    libselinux_present=`check_error "$global_temp_code"`
elif [ "$package_manager" = "zypper" ]; then
    search_for_package "$libselinux_python_suse"
    libselinux_present=`check_error "$global_temp_code"`
fi
global_status=`get_global_status "$global_status" "$libselinux_present"`

# Conditional check for libxcrypt-compat (required for RHEL10+)
libxcrypt_compat_present="$N_A"
if [ "$package_manager" = "yum" ]; then
    if [ "$isVersion10" = "true" ]; then
        search_for_package "$libxcrypt_compat"
        libxcrypt_compat_present=`check_error "$global_temp_code"`
        global_status=`get_global_status "$global_status" "$libxcrypt_compat_present"`
    fi
fi

# Conditional check for iptables-nft-services (required for RHEL10+)
iptables_nft_services_present="$N_A"
if [ "$package_manager" = "yum" ]; then
    if [ "$isVersion10" = "true" ]; then
        search_for_package "$iptables_nft_services"
        iptables_nft_services_present=`check_error "$global_temp_code"`
        global_status=`get_global_status "$global_status" "$iptables_nft_services_present"`
    fi
fi

which unzip > /dev/null 2>&1
unzip_present=`check_error "$?"`
global_status=`get_global_status "$global_status" "$unzip_present"`

which zip > /dev/null 2>&1
zip_present=`check_error "$?"`
global_status=`get_global_status "$global_status" "$zip_present"`

$ndb_sudo_script which crontab > /dev/null 2>&1
crontab_present=`check_error "$?"`
global_status=`get_global_status "$global_status" "$crontab_present"`

$ndb_sudo_script which lvdisplay > /dev/null 2>&1
lvdisplay_present=`check_error "$?"`
global_status=`get_global_status "$global_status" "$lvdisplay_present"`

$ndb_sudo_script which lvcreate > /dev/null 2>&1
lvcreate_present=`check_error "$?"`
global_status=`get_global_status "$global_status" "$lvcreate_present"`

$ndb_sudo_script which lvscan > /dev/null 2>&1
lvscan_present=`check_error "$?"`
global_status=`get_global_status "$global_status" "$lvscan_present"`

$ndb_sudo_script which pvdisplay > /dev/null 2>&1
pvdisplay_present=`check_error "$?"`
global_status=`get_global_status "$global_status" "$pvdisplay_present"`

$ndb_sudo_script which pvcreate > /dev/null 2>&1
pvcreate_present=`check_error "$?"`
global_status=`get_global_status "$global_status" "$pvcreate_present"`

$ndb_sudo_script which pvscan > /dev/null 2>&1
pvscan_present=`check_error "$?"`
global_status=`get_global_status "$global_status" "$pvscan_present"`

$ndb_sudo_script which vgdisplay > /dev/null 2>&1
vgdisplay_present=`check_error "$?"`
global_status=`get_global_status "$global_status" "$vgdisplay_present"`

$ndb_sudo_script which vgcreate > /dev/null 2>&1
vgcreate_present=`check_error "$?"`
global_status=`get_global_status "$global_status" "$vgcreate_present"`

$ndb_sudo_script which vgscan > /dev/null 2>&1
vgscan_present=`check_error "$?"`
global_status=`get_global_status "$global_status" "$vgscan_present"`

$ndb_sudo_script which dbus-uuidgen > /dev/null 2>&1
dbus_uuidgen_present=`check_error "$?"`

$ndb_sudo_script which lsscsi > /dev/null 2>&1
lsscsi_present=`check_error "$?"`
global_status=`get_global_status "$global_status" "$lsscsi_present"`

which rsync > /dev/null 2>&1
rsync_present=`check_error "$?"`
global_status=`get_global_status "$global_status" "$rsync_present"`

$ndb_sudo_script which lsof > /dev/null 2>&1
lsof_present=`check_error "$?"`
global_status=`get_global_status "$global_status" "$lsof_present"`

search_for_package "$systemd"
systemd_present=`check_error "$global_temp_code"`
global_status=`get_global_status "$global_status" "$systemd_present"`

search_for_package "$rsyslog"
rsyslog_present=`check_error "$global_temp_code"`
global_status=`get_global_status "$global_status" "$rsyslog_present"`

search_for_package "$logrotate"
logrotate_present=`check_error "$global_temp_code"`
global_status=`get_global_status "$global_status" "$logrotate_present"`

# Collect VM info for compatibility validation (needed before report output)
os_distribution=`detect_os_distribution`
os_version=`detect_os_version`
database_version=`detect_database_version "$database_type" "$software_home"`

# Oracle-specific: collect grid home version for compatibility validation
oracle_grid_version="UNKNOWN"
if [ "$database_type" = "$ORACLE_DB" ]; then
    # Only collect version if oracle_grid_home is provided (for SIHA/RAC configurations)
    if [ -n "$oracle_grid_home" ] && [ "$oracle_grid_home" != "" ]; then
        oracle_grid_version=`detect_oracle_grid_version "$oracle_grid_home"`
    fi
fi

echo ""
echo ""
echo "--------------------------------------------------------------------"
echo "|              Era Pre-requirements Validation Report              |"
echo "--------------------------------------------------------------------"

echo ""
echo "$indent1 General Checks:"
echo "$indent1 ---------------"
echo "$indent2 1] Username           : $user (Same as current logged in user)"
echo "$indent2 2] Package manager    : $package_manager"
echo "$indent2 3] Database type      : $database_type"

echo ""
echo "$indent1 Era Configuration Dependencies:"
echo "$indent1 -------------------------------"
echo "$indent2 1] User has sudo access                         : $sudo_access"
echo "$indent2 2] User has sudo with NOPASS access             : $sudo_access"
echo "$indent2 3] Crontab configured for user                  : $crontab_configured"
echo "$indent2 4] Secure paths configured in /etc/sudoers file : $secure_paths_configured"
echo "$indent2 5] Prism API connectivity                       : $prism_connectivity"

echo ""
echo "$indent1 Era Software Dependencies:"
echo "$indent1 --------------------------"
echo "$indent2  1] GCC                  : $gcc_present"
echo "$indent2  2] readline             : $readline_present"
echo "$indent2  3] libselinux-python    : $libselinux_present"
echo "$indent2  4] crontab              : $crontab_present"
echo "$indent2  5] lvcreate             : $lvcreate_present"
echo "$indent2  6] lvscan               : $lvscan_present"
echo "$indent2  7] lvdisplay            : $lvdisplay_present"
echo "$indent2  8] vgcreate             : $vgcreate_present"
echo "$indent2  9] vgscan               : $vgscan_present"
echo "$indent2 10] vgdisplay            : $vgdisplay_present"
echo "$indent2 11] pvcreate             : $pvcreate_present"
echo "$indent2 12] pvscan               : $pvscan_present"
echo "$indent2 13] pvdisplay            : $pvdisplay_present"
echo "$indent2 14] zip                  : $zip_present"
echo "$indent2 15] unzip                : $unzip_present"
echo "$indent2 16] rsync                : $rsync_present"
echo "$indent2 17] bc                   : $bc_present"
echo "$indent2 18] sshpass              : $sshpass_present"
echo "$indent2 19] ksh                  : $ksh_present"
echo "$indent2 20] lsof                 : $lsof_present"
echo "$indent2 21] tar                  : $tar_present"
echo "$indent2 22] xfsprogs             : $xfsprogs_present"
echo "$indent2 23] ifupdown             : $ifupdown_present"
echo "$indent2 24] net-tools            : $net_tools_present"
echo "$indent2 25] nftables             : $nftables_present"
echo "$indent2 26] acl                  : $acl_present"
echo "$indent2 27] systemd              : $systemd_present"
echo "$indent2 28] rsyslog              : $rsyslog_present"
echo "$indent2 29] logrotate            : $logrotate_present"
echo "$indent2 30] db_os_user           : $db_os_user_exist"
echo "$indent2 31] chrony               : $chrony_present"
echo "$indent2 32] dbus-uuidgen         : $dbus_uuidgen_present"
echo "$indent2 33] lsscsi               : $lsscsi_present"
echo "$indent2 34] firewalld (RHEL)     : $firewalld_present"
echo "$indent2 35] firewalld (Ubuntu)   : $firewalld_active"
echo "$indent2 36] ufw (Ubuntu/Debian)  : $ufw_present"
echo "$indent2 37] SELinux permissive   : $selinux_permissive"
echo "$indent2 38] make                 : $make_present"
echo "$indent2 39] wget                 : $wget_present"
echo "$indent2 40] openssh-server       : $openssh_server_present"
echo "$indent2 41] grub_config          : $grub_blk_mq_configured"
echo "$indent2 42] sysctl_config        : $sysctl_config_configured"
echo "$indent2 43] sudoers_requiretty   : $sudoers_requiretty_configured"
echo "$indent2 44] openssl-devel        : $openssl_devel_present"
echo "$indent2 45] pcre-devel           : $pcre_devel_present"
echo "$indent2 46] systemd-devel        : $systemd_devel_present"
echo "$indent2 47] zlib-devel           : $zlib_devel_present"
echo "$indent2 48] pip_packages         : $pip_packages_configured"
echo "$indent2 50] patroni              : $patroni_present"
echo "$indent2 51] patronictl           : $patronictl_present"
echo "$indent2 52] HAProxy config       : $haproxy_configured"
echo "$indent2 53] etcd                 : $etcd_present"
echo "$indent2 54] libxcrypt-compat (RHEL10+) : $libxcrypt_compat_present"
echo "$indent2 55] iptables-nft-services (RHEL10+) : $iptables_nft_services_present"

echo ""

# Check if any warnings need to be displayed
warning_needed="$FALSE"
# Checks that warn when value is NO (POSIX-compliant, no bash arrays)
for val in "$numa_configured" "$transparent_hugepage_configured" "$grub_blk_mq_configured" \
           "$sudoers_requiretty_configured" "$db_os_user_exist" "$patroni_present" \
           "$patronictl_present" "$haproxy_configured" "$etcd_present" "$pip_packages_configured" \
           "$sysctl_config_configured" "$make_present" "$wget_present" "$openssl_devel_present" \
           "$pcre_devel_present" "$systemd_devel_present" "$zlib_devel_present"; do
    if [ "$val" = "$NO" ]; then
        warning_needed="$TRUE"
    fi
done

# Check firewalld_active separately (warns when YES)
if [ "$firewalld_active" = "$YES" ]; then
    warning_needed="$TRUE"
fi

# SELinux enforcing is a warning for Postgres (not a failure)
if [ "$database_type" = "$POSTGRES_DB" ] && [ "$selinux_permissive" = "$NO" ]; then
    warning_needed="$TRUE"
fi

if [ "$database_type" = "$POSTGRES_DB" ] && [ "$gcc_present" = "$NO" ]; then
    warning_needed="$TRUE"
fi

echo "$indent1 Summary:"
echo "$indent1 --------"
if [ "$global_status" = "$SUCCESS" ]; then
    echo "$indent2 This machine satisfies dependencies required by Era, it can be onboarded."
else
    echo "$indent2 This machine does not satisfy all of the dependencies required by Era."
    echo "$indent2 It can not be onboarded to Era unless all of these are satisfied."
    if [ "$show_detailed" = "$FALSE" ]; then
        echo ""
        echo "$indent2 Note: You can run this script using '$DETAILS' option to know the complete details"
    fi
fi

if [ "$warn_curl" = "$TRUE" ]; then
    echo
    echo "$indent1 **WARNING: Curl was not found on the device. Couldn't go ahead with the Prism API connectivity check."
    echo "$indent1 Please ensure Prism APIs are callable from the host."
fi

if [ "$skip_cluster_check" = "$TRUE" ]; then
    echo
    echo "$indent1 **WARNING: Cluster API was not provided. Couldn't go ahead with the Prism API connectivity check."
    echo "$indent1 Please ensure Prism APIs are callable from the host."
fi

if [ "$show_detailed" = "$TRUE" ]; then
    echo ""
    echo ""
    echo "$indent1 --------"
    echo "$indent1 Details:"
    echo "$indent1 --------"

    if [ "$global_status" = "$FAIL" ]; then
    # configuration details
    if [ "$sudo_access" = "$NO" ]; then
        echo ""
        echo "$indent2  sudo access ($CONFIG_DEP):"
        echo "$indent2     - The Era user on dbserver VM needs to have sudo access enabled"
    fi

    # NOPASS is already covered as part of sudo access. This is a placeholder check
    if [ "$sudo_access" = "$NO" ]; then
        echo ""
        echo "$indent2  sudo with NOPASS access ($CONFIG_DEP):"
        echo "$indent2     - The Era user on dbserver VM needs to have sudo with NOPASS enabled"
    fi

    if [ "$crontab_configured" = "$NO" ]; then
        echo ""
        echo "$indent2  Crontab for user ($CONFIG_DEP):"
        echo "$indent2     - The crontab should be enabled for the Era user as the Era daemon gets"
        echo "$indent2       installed as a cronjob process."
    fi

    if [ "$secure_paths_configured" = "$NO" ]; then
        echo ""
        echo "$indent2  Secure paths in /etc/sudoers ($CONFIG_DEP):"
        echo "$indent2     - The binary source directory paths for all the Era dependencies (lvcreate,"
        echo "$indent2       pvcreate, lvsca, etc.) must be updated in the /etc/sudoers file so that"
        echo "$indent2       they can be accessed remotely"
    fi

    if [ "$prism_connectivity" = "$NO" ]; then
        echo ""
        echo "$indent2  Prism API connectivity ($CONFIG_DEP):"
        echo "$indent2     - Prism APIs must be reachable for era software to work."
    fi

    # software dependency details
    if [ "$gcc_present" = "$NO" ]; then
        echo ""
        echo "$indent2  GCC ($SOFTWARE_DEP):"
        echo "$indent2     - The GCC system package is required to build and install the cx_oracle pip "
        echo "$indent2       package in Era shippable stack (required only for $ORACLE_DB)"
        install_package_help $gcc
    fi

    if [ "$bc_present" = "$NO" ]; then
        echo ""
        echo "$indent2  $bc ($SOFTWARE_DEP):"
        echo "$indent2     - The $bc system package is required to support ansible execution of "
        echo "$indent2       Database Provisioning and Cloning (required only for $ORACLE_DB)"
        install_package_help $bc
    fi

    if [ "$sshpass_present" = "$NO" ]; then
        echo ""
        echo "$indent2  $sshpass ($SOFTWARE_DEP):"
        echo "$indent2     - The $sshpass system package is required to support ansible execution of "
        echo "$indent2       Cluster Database Patching and Creating Standby Database (required only for $ORACLE_DB)"
        install_package_help $sshpass
    fi

    if [ "$ksh_present" = "$NO" ]; then
        echo ""
        echo "$indent2  $ksh ($SOFTWARE_DEP):"
        echo "$indent2     - The $ksh system package is required to support ansible execution of "
        echo "$indent2       Cluster Database Provisioning (required only for $ORACLE_DB)"
        install_package_help $ksh
    fi

    if [ "$readline_present" = "$NO" ]; then
        echo ""
        echo "$indent2  $readline ($SOFTWARE_DEP):"
        echo "$indent2     - The $readline system package is required to support the auto-complete feature"
        echo "$indent2       of Era command line interface"
        install_package_help $readline
    fi

    if [ "$tar_present" = "$NO" ]; then
        echo ""
        echo "$indent2  tar ($SOFTWARE_DEP):"
        echo "$indent2     - The tar system package is required to untar packages"
        echo "$indent2       of Era command line interface"
        install_package_help "tar"
    fi

    if [ "$xfsprogs_present" = "$NO" ]; then
        echo ""
        echo "$indent2  xfsprogs ($SOFTWARE_DEP):"
        echo "$indent2     - The xfsprogs system package is required to support file creation for MongoDB for Ubuntu/Debian OS"
        echo "$indent2       of Era command line interface"
        install_package_help "xfsprogs"
    fi

    if [ "$nftables_present" = "$NO" ]; then
        echo ""
        echo "$indent2  nftables ($SOFTWARE_DEP):"
        echo "$indent2     - The nftables system package is required to enable postgres HA"
        echo "$indent2       of Era command line interface"
        install_package_help "nftables"
    fi

    if [ "$ifupdown_present" = "$NO" ]; then
        echo ""
        echo "$indent2  ifupdown ($SOFTWARE_DEP):"
        echo "$indent2     - The ifupdown system package is required to improve IP configuration for Ubuntu/Debian OS"
        echo "$indent2       of Era command line interface"
        install_package_help "ifupdown"
    fi

    if [ "$net_tools_present" = "$NO" ]; then
        echo ""
        echo "$indent2  net-tools ($SOFTWARE_DEP):"
        echo "$indent2     - The net-tools system package is required to improve IP configuration for Ubuntu/Debian OS"
        echo "$indent2       of Era command line interface"
        install_package_help "net-tools"
    fi

    if [ "$libselinux_present" = "$NO" ]; then
        echo ""
        echo "$indent2  $libselinux_python ($SOFTWARE_DEP):"
        echo "$indent2     - The $libselinux_python system package is required to support ansible execution"
        install_package_help "$libselinux_python_rhel" "$libselinux_python_ubuntu"
    fi

    if [ "$libxcrypt_compat_present" = "$NO" ]; then
        echo ""
        echo "$indent2  $libxcrypt_compat ($SOFTWARE_DEP):"
        echo "$indent2     - The $libxcrypt_compat system package is required for RHEL10+ to provide"
        echo "$indent2       legacy crypt library compatibility"
        install_package_help "$libxcrypt_compat"
    fi

    if [ "$iptables_nft_services_present" = "$NO" ]; then
        echo ""
        echo "$indent2  $iptables_nft_services ($SOFTWARE_DEP):"
        echo "$indent2     - The $iptables_nft_services system package is required for RHEL10+ to provide"
        echo "$indent2       iptables compatibility with nftables backend"
        install_package_help "$iptables_nft_services"
    fi

    if [ "$crontab_present" = "$NO" ]; then
        echo ""
        echo "$indent2  $crontab ($SOFTWARE_DEP):"
        echo "$indent2     - The $crontab system utility is required to start Era Agent daemon on dbserver"
        install_package_help "$crontab"
    fi

    if [ "$lvcreate_present" = "$NO" ]; then
        echo ""
        echo "$indent2  $lvcreate ($SOFTWARE_DEP):"
        echo "$indent2     - The $lvcreate system utility is required to manage Era related LVM setups on dbserver"
        install_package_help "$lvm2"
    fi

    if [ "$lvscan_present" = "$NO" ]; then
        echo ""
        echo "$indent2  $lvscan ($SOFTWARE_DEP):"
        echo "$indent2     - The $lvscan system utility is required to manage Era related LVM setups on dbserver"
        install_package_help "$lvm2"
    fi

    if [ "$lvdisplay_present" = "$NO" ]; then
        echo ""
        echo "$indent2  $lvdisplay ($SOFTWARE_DEP):"
        echo "$indent2     - The $lvdisplay system utility is required to manage Era related LVM setups on dbserver"
        install_package_help "$lvm2"
    fi

    if [ "$vgcreate_present" = "$NO" ]; then
        echo ""
        echo "$indent2  $vgcreate ($SOFTWARE_DEP):"
        echo "$indent2     - The $vgcreate system utility is required to manage Era related LVM setups on dbserver"
        install_package_help "$lvm2"
    fi

    if [ "$vgscan_present" = "$NO" ]; then
        echo ""
        echo "$indent2  $vgscan ($SOFTWARE_DEP):"
        echo "$indent2     - The $vgscan system utility is required to manage Era related LVM setups on dbserver"
        install_package_help "$lvm2"
    fi

    if [ "$dbus_uuidgen_present" = "$NO" ]; then
        echo ""
        echo "$indent2  $dbus_uuidgen ($SOFTWARE_DEP):"
        echo "$indent2     - The $dbus_uuidgen system utility is required for network configurations on dbserver"
        install_package_help "dbus"
    fi

    if [ "$vgdisplay_present" = "$NO" ]; then
        echo ""
        echo "$indent2  $vgdisplay ($SOFTWARE_DEP):"
        echo "$indent2     - The $vgdisplay system utility is required to manage Era related LVM setups on dbserver"
        install_package_help "$lvm2"
    fi

    if [ "$pvcreate_present" = "$NO" ]; then
        echo ""
        echo "$indent2  $pvcreate ($SOFTWARE_DEP):"
        echo "$indent2     - The $pvcreate system utility is required to manage Era related LVM setups on dbserver"
        install_package_help "$lvm2"
    fi

    if [ "$pvscan_present" = "$NO" ]; then
        echo ""
        echo "$indent2  $pvscan ($SOFTWARE_DEP):"
        echo "$indent2     - The $pvscan system utility is required to manage Era related LVM setups on dbserver"
        install_package_help "$lvm2"
    fi

    if [ "$pvdisplay_present" = "$NO" ]; then
        echo ""
        echo "$indent2  $pvdisplay ($SOFTWARE_DEP):"
        echo "$indent2     - The $pvdisplay system utility is required to manage Era related LVM setups on dbserver"
        install_package_help "$lvm2"
    fi

    if [ "$unzip_present" = "$NO" ]; then
        echo ""
        echo "$indent2  $unzip ($SOFTWARE_DEP):"
        echo "$indent2     - The $unzip system utility is required to unzip the Era installation bundles"
        install_package_help "$unzip"
    fi

    if [ "$zip_present" = "$NO" ]; then
        echo ""
        echo "$indent2  $zip ($SOFTWARE_DEP):"
        echo "$indent2     - The $zip system utility is required to zip the Era diagnostic bundles"
        install_package_help "$unzip"
    fi

    if [ "$rsync_present" = "$NO" ]; then
        echo ""
        echo "$indent2  $rsync ($SOFTWARE_DEP):"
        echo "$indent2     - The $rsync system utility is required to copy contents for Software Profile Creation"
        install_package_help "$rsync"
    fi

    if [ "$lsof_present" = "$NO" ]; then
        echo ""
        echo "$indent2  $lsof ($SOFTWARE_DEP):"
        echo "$indent2     - The $lsof system utility is required to list open-files on the mount-points created by ERA"
        install_package_help "$lsof"
    fi
    if [ "$xfsprogs_present" = "$NO" ]; then
        echo ""
        echo "$indent2  $xfsprogs_mongodb_ubuntu_debian ($SOFTWARE_DEP):"
        echo "$indent2     - The $xfsprogs_mongodb_ubuntu_debian system utility is required to mount file systems"
        install_package_help "$xfsprogs_mongodb_ubuntu_debian"
    fi
    if [ "$ifupdown_present" = "$NO" ]; then
        echo ""
        echo "$indent2  $ifupdown_ubuntu ($SOFTWARE_DEP):"
        echo "$indent2     - The $ifupdown_ubuntu system utility is required for network setup"
        install_package_help "$ifupdown_ubuntu"
    fi
    if [ "$net_tools_present" = "$NO" ]; then
        echo ""
        echo "$indent2  $net_tools_ubuntu ($SOFTWARE_DEP):"
        echo "$indent2     - The $net_tools_ubuntu system utility is required for network setup"
        install_package_help "$net_tools_ubuntu"
    fi
    if [ "$nftables_present" = "$NO" ]; then
        echo ""
        echo "$indent2  $nftables_ubuntu ($SOFTWARE_DEP):"
        echo "$indent2     - The $nftables_ubuntu system utility is required for filtering ingress and egress traffic to the VM"
        install_package_help "$nftables_ubuntu"
    fi
    if [ "$acl_present" = "$NO" ]; then
        echo ""
        echo "$indent2  $acl_ubuntu ($SOFTWARE_DEP):"
        echo "$indent2     - The acl system utility is required for ansible tasks to run commands as unprivileged user"
        install_package_help "$acl_ubuntu"
    fi
    if [ "$systemd_present" = "$NO" ]; then
        echo ""
        echo "$indent2  $systemd ($SOFTWARE_DEP):"
        echo "$indent2     - The systemd utility is required for NDB logging"
        install_package_help "$systemd"
    fi
    if [ "$rsyslog_present" = "$NO" ]; then
        echo ""
        echo "$indent2  $rsyslog ($SOFTWARE_DEP):"
        echo "$indent2     - The rsyslog system utility is required for NDB logging"
        install_package_help "$rsyslog"
    fi
    if [ "$logrotate_present" = "$NO" ]; then
        echo ""
        echo "$indent2  $logrotate ($SOFTWARE_DEP):"
        echo "$indent2     - The logrotate system utility is required for NDB logging"
        install_package_help "$logrotate"
    fi
    if [ "$db_os_user_exist" = "$NO" ]; then
        echo ""
        echo "$indent2  $db_os_user ($CONFIG_DEP):"
        echo "$indent2     - The db_os_user $db_os_user is required to run the database services"
    fi
    if [ "$chrony_present" = "$NO" ]; then
        echo ""
        echo "$indent2  $chrony ($SOFTWARE_DEP):"
        echo "$indent2     - The $chrony system utility is required to manage time synchronization for the database"
        install_package_help "$chrony"
    fi
    if [ "$lsscsi_present" = "$NO" ]; then
        echo ""
        echo "$indent2  $lsscsi ($SOFTWARE_DEP):"
        echo "$indent2     - The $lsscsi system utility is required to list SCSI devices on dbserver"
        install_package_help "$lsscsi"
    fi
    if [ "$firewalld_present" = "$NO" ]; then
        echo ""
        echo "$indent2  $firewalld ($SOFTWARE_DEP):"
        echo "$indent2     - The $firewalld system utility is required to manage firewall rules for the database"
        install_package_help "$firewalld"
    fi
    if [ "$ufw_present" = "$NO" ]; then
        echo ""
        echo "$indent2  $ufw ($SOFTWARE_DEP):"
        echo "$indent2     - The $ufw system utility is required to manage firewall rules for the database"
        install_package_help "$ufw"
    fi
    if [ "$firewalld_active" = "$YES" ]; then
        echo ""
        echo "$indent2  firewalld active ($CONFIG_DEP):"
        echo "$indent2     - firewalld service is active. For PostgreSQL on Ubuntu, NDB recommends using nftables instead of firewalld."
        echo "$indent2     - Consider stopping and disabling firewalld: 'sudo systemctl stop firewalld && sudo systemctl disable firewalld && sudo systemctl mask firewalld'"
    fi
    if [ "$selinux_permissive" = "$NO" ] && [ "$database_type" = "$MYSQL_DB" ]; then
        echo ""
        echo "$indent2  SELinux mode ($CONFIG_DEP):"
        echo "$indent2     - SELinux is currently enforcing. Either switch to permissive/disabled or configure proper SELinux labels for MySQL binary, data and pid paths."
        echo "$indent2       To persist after reboot on RHEL-like systems (requires reboot):"
        echo "$indent2         sudo sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config"
    fi
    if [ "$wget_present" = "$NO" ]; then
        echo ""
        echo "$indent2  $wget_pkg ($SOFTWARE_DEP):"
        echo "$indent2     - The $wget_pkg utility is required for downloading source packages for PostgreSQL HA setup"
        install_package_help "$wget_pkg"
    fi
    if [ "$openssh_server_present" = "$NO" ]; then
        echo ""
        echo "$indent2  openssh-server ($SOFTWARE_DEP):"
        echo "$indent2     - The openssh-server package is required for SSH access and Era agent communication"
        install_package_help "openssh-server"
    fi
    fi

    if [ "$warning_needed" = "$TRUE" ]; then
        echo
        echo "$indent1 WARNINGS: Onboarding/Provisioning may fail. Please refer below recommendations:"
        echo "$indent1 Refer NDB documentation: $NDB_DOC_URL"
        echo "$indent1 ----------------------------------------------------------------------------------------------------------------------------"
        if [ "$numa_configured" = "$NO" ]; then
            echo "$indent2  - set numa=off at GRUB_CMDLINE_LINUX in /etc/default/grub file, "
            echo "$indent2     to update the grub configuration: grub2-mkconfig -o /etc/grub2.cfg"
            echo "$indent2"
        fi

        if [ "$transparent_hugepage_configured" = "$NO" ]; then
            echo "$indent2  - set transparent_hugepage=never at GRUB_CMDLINE_LINUX in /etc/default/grub file"
            echo "$indent2     to update the grub configuration: grub2-mkconfig -o /etc/grub2.cfg"
            echo "$indent2"
        fi

        if [ "$grub_blk_mq_configured" = "$NO" ]; then
            echo "$indent2  - set scsi_mod.use_blk_mq=1 and dm_mod.use_blk_mq=y at GRUB_CMDLINE_LINUX in /etc/default/grub file"
            echo "$indent2     to update the grub configuration: grub2-mkconfig -o /etc/grub2.cfg"
            echo "$indent2"
        fi

        if [ "$sudoers_requiretty_configured" = "$NO" ]; then
            echo "$indent2  - Remove 'Defaults requiretty' parameter from /etc/sudoers"
            echo "$indent2"
        fi

        if [ "$patroni_present" = "$NO" ]; then
            echo "$indent2  - Patroni binary should be present at /usr/local/bin/ and /usr/bin/ for PostgreSQL HA setup"
            echo "$indent2"
        fi

        if [ "$patronictl_present" = "$NO" ]; then
            echo "$indent2  - Patronictl binary should be present at /usr/local/bin/ and /usr/bin/ for PostgreSQL HA setup"
            echo "$indent2"
        fi

        if [ "$haproxy_configured" = "$NO" ]; then
            echo "$indent2  - HAProxy binary at /usr/local/bin/ or /usr/bin/ and /usr/lib/systemd/system/haproxy.service required for PostgreSQL HA"
            echo "$indent2"
        fi

        if [ "$etcd_present" = "$NO" ]; then
            echo "$indent2  - Etcd binary should be present at /usr/local/bin/ and /usr/bin/ for PostgreSQL HA setup"
            echo "$indent2"
        fi

        if [ "$pip_packages_configured" = "$NO" ]; then
            echo "$indent2  - Install pip3 packages via 'python3 -m pip install': urllib3, psycopg2-binary, setuptools, cdiff, python-etcd, etcd3"
            echo "$indent2"
        fi

        if [ "$sysctl_config_configured" = "$NO" ]; then
            echo "$indent2  - Ensure all sysctl settings in /etc/sysctl.conf:"
            echo "$indent2      vm.zone_reclaim_mode=0" 
            echo "$indent2      vm.max_map_count=128000"
            echo "$indent2      net.ipv4.tcp_fin_timeout=30"
            echo "$indent2      net.ipv4.tcp_keepalive_intvl=30"
            echo "$indent2      net.ipv4.tcp_keepalive_time=120"
            echo "$indent2      net.ipv4.tcp_max_syn_backlog=4096"
            echo "$indent2      net.ipv4.tcp_keepalive_probes=6"
            echo "$indent2      net.core.somaxconn=4096"
            echo "$indent2     to apply the changes: sudo sysctl -p"
            echo "$indent2"
        fi

        if [ "$make_present" = "$NO" ]; then
            echo "$indent2  - make build tool should be installed for compiling HAProxy binaries"
            echo "$indent2"
        fi

        if [ "$database_type" = "$POSTGRES_DB" ] && [ "$gcc_present" = "$NO" ]; then
            echo "$indent2  - gcc compiler should be installed for building/compiling HAProxy binaries for Postgres HA setup"
            echo "$indent2"
        fi

        if [ "$wget_present" = "$NO" ]; then
            echo "$indent2  - wget should be installed for downloading source packages"
            echo "$indent2"
        fi

        if [ "$openssl_devel_present" = "$NO" ]; then
            echo "$indent2  - openssl-devel/libssl-dev should be installed for compiling HAProxy binaries"
            echo "$indent2"
        fi

        if [ "$pcre_devel_present" = "$NO" ]; then
            echo "$indent2  - pcre-devel/libpcre3-dev OR pcre2-devel/libpcre2-dev should be installed for compiling HAProxy binaries"
            echo "$indent2"
        fi

        if [ "$systemd_devel_present" = "$NO" ]; then
            echo "$indent2  - systemd-devel/libsystemd-dev should be installed for compiling compiling HAProxy binaries"
            echo "$indent2"
        fi

        if [ "$zlib_devel_present" = "$NO" ]; then
            echo "$indent2  - zlib-devel/zlib1g-dev should be installed for compiling HAProxy binaries"
            echo "$indent2"
        fi

        if [ "$database_type" = "$POSTGRES_DB" ] && [ "$selinux_permissive" = "$NO" ]; then
            echo "$indent2  SELinux mode:"
            echo "$indent2  - SELinux is currently enforcing. PostgreSQL supports enforcing mode, but ensure proper SELinux policies are configured"
            echo "$indent2  please refer Nutanix NDB documentation" 
			echo "$indent2"
        fi
    fi
fi

if [ "$warning_needed" = "$TRUE" ] && [ "$show_detailed" = "$FALSE" ]; then
    echo ""
    echo "$indent1 **WARNING: There are warnings. Please execute script with '$DETAILS' option"
    echo "$indent2 $indent1 and review the warnings before onboarding. Any warnings may lead to provisioning failures."

fi
echo "=================================="

# Below block is for internal use only
if [ "$is_era_server_call" = "$TRUE" ]; then
    echo "$internal_message"
    echo "$internal_debug_message"
    echo "$CONFIG $DEBUG_DELIM sudo_access $DEBUG_DELIM $sudo_access $DEBUG_DELIM Make sure the user '$user' has sudo access"
    echo "$CONFIG $DEBUG_DELIM sudo_nopass_access $DEBUG_DELIM $sudo_access $DEBUG_DELIM Make sure the user '$user' has sudo NOPASS access"
    echo "$CONFIG $DEBUG_DELIM crontab $DEBUG_DELIM $crontab_configured $DEBUG_DELIM Make sure crontab is configured for the user"
    echo "$CONFIG $DEBUG_DELIM secure_paths $DEBUG_DELIM $secure_paths_configured $DEBUG_DELIM Make sure the binary paths are configured as 'secure_paths' in the /etc/sudoers file"
    echo "$CONFIG $DEBUG_DELIM prism_connectivity $DEBUG_DELIM $prism_connectivity $DEBUG_DELIM Make sure Prism APIs care callable from the VM"
    echo "$SOFTWARE$DEBUG_DELIM gcc$DEBUG_DELIM$gcc_present$DEBUG_DELIM Make sure gcc system package is installed on the VM. You can try 'sudo $package_manager install gcc -y' to install it"
    echo "$SOFTWARE$DEBUG_DELIM readline $DEBUG_DELIM $readline_present $DEBUG_DELIM Make sure readline system package is installed on the VM. You can try 'sudo $package_manager install readline -y' to install it"
    echo "$SOFTWARE$DEBUG_DELIM libselinux-python $DEBUG_DELIM $libselinux_present $DEBUG_DELIM Make sure libselinux_python is installed on the VM."
    echo "$SOFTWARE$DEBUG_DELIM libxcrypt-compat $DEBUG_DELIM $libxcrypt_compat_present $DEBUG_DELIM Make sure libxcrypt-compat system package is installed on the VM (required for RHEL10+). You can try 'sudo $package_manager install libxcrypt-compat -y' to install it"
    echo "$SOFTWARE$DEBUG_DELIM iptables-nft-services $DEBUG_DELIM $iptables_nft_services_present $DEBUG_DELIM Make sure iptables-nft-services system package is installed on the VM (required for RHEL10+). You can try 'sudo $package_manager install iptables-nft-services -y' to install it"
    echo "$SOFTWARE$DEBUG_DELIM unzip $DEBUG_DELIM $unzip_present $DEBUG_DELIM Make sure unzip system package is installed on the VM. You can try 'sudo $package_manager install unzip -y' to install it"
    echo "$SOFTWARE$DEBUG_DELIM zip $DEBUG_DELIM $zip_present $DEBUG_DELIM Make sure zip system package is installed on the VM. You can try 'sudo $package_manager install zip -y' to install it"
    echo "$SOFTWARE$DEBUG_DELIM crontab $DEBUG_DELIM $crontab_present $DEBUG_DELIM Make sure crontab system package is installed on the VM. You can try 'sudo $package_manager install crontab -y' to install it"
    echo "$SOFTWARE$DEBUG_DELIM lvcreate $DEBUG_DELIM $lvcreate_present $DEBUG_DELIM Make sure lvm system packages are installed on the VM. You can try 'sudo $package_manager install lvm2 -y' to install it"
    echo "$SOFTWARE$DEBUG_DELIM lvscan $DEBUG_DELIM $lvscan_present $DEBUG_DELIM Make sure lvm system packages are installed on the VM. You can try 'sudo $package_manager install lvm2 -y' to install it"
    echo "$SOFTWARE$DEBUG_DELIM lvdisplay $DEBUG_DELIM $lvdisplay_present $DEBUG_DELIM Make sure lvm system packages are installed on the VM. You can try 'sudo $package_manager install lvm2 -y' to install it"
    echo "$SOFTWARE$DEBUG_DELIM vgcreate $DEBUG_DELIM $vgcreate_present $DEBUG_DELIM Make sure lvm system packages are installed on the VM. You can try 'sudo $package_manager install lvm2 -y' to install it"
    echo "$SOFTWARE$DEBUG_DELIM vgscan $DEBUG_DELIM $vgscan_present $DEBUG_DELIM Make sure lvm system packages are installed on the VM. You can try 'sudo $package_manager install lvm2 -y' to install it"
    echo "$SOFTWARE$DEBUG_DELIM dbus-uuidgen $DEBUG_DELIM $dbus_uuidgen_present $DEBUG_DELIM Make sure dbus system packages are installed on the VM. You can try 'sudo $package_manager install dbus' to install it"
    echo "$SOFTWARE$DEBUG_DELIM lsscsi $DEBUG_DELIM $lsscsi_present $DEBUG_DELIM Make sure lsscsi system package is installed on the VM. You can try 'sudo $package_manager install lsscsi -y' to install it"
    echo "$SOFTWARE$DEBUG_DELIM vgdisplay $DEBUG_DELIM $vgdisplay_present $DEBUG_DELIM Make sure lvm system packages are installed on the VM. You can try 'sudo $package_manager install lvm2 -y' to install it"
    echo "$SOFTWARE$DEBUG_DELIM pvcreate $DEBUG_DELIM $pvcreate_present $DEBUG_DELIM Make sure lvm system packages are installed on the VM. You can try 'sudo $package_manager install lvm2 -y' to install it"
    echo "$SOFTWARE$DEBUG_DELIM pvscan $DEBUG_DELIM $pvscan_present $DEBUG_DELIM Make sure lvm system packages are installed on the VM. You can try 'sudo $package_manager install lvm2 -y' to install it"
    echo "$SOFTWARE$DEBUG_DELIM pvdisplay $DEBUG_DELIM $pvdisplay_present $DEBUG_DELIM Make sure lvm system packages are installed on the VM. You can try 'sudo $package_manager install lvm2 -y' to install it"
    echo "$SOFTWARE$DEBUG_DELIM rsync $DEBUG_DELIM $rsync_present $DEBUG_DELIM Make sure rsync system packages are installed on the VM. You can try 'sudo $package_manager install rsync -y' to install it"
    echo "$SOFTWARE$DEBUG_DELIM bc $DEBUG_DELIM $bc_present $DEBUG_DELIM Make sure bc system package is installed on the VM. You can try 'sudo $package_manager install bc -y' to install it"
    echo "$SOFTWARE$DEBUG_DELIM sshpass $DEBUG_DELIM $sshpass_present $DEBUG_DELIM Make sure sshpass system package is installed on the VM. You can try 'sudo $package_manager install sshpass -y' to install it"
    echo "$SOFTWARE$DEBUG_DELIM ksh $DEBUG_DELIM $ksh_present $DEBUG_DELIM Make sure ksh system package is installed on the VM. You can try 'sudo $package_manager install ksh -y' to install it"
    echo "$SOFTWARE$DEBUG_DELIM lsof $DEBUG_DELIM $lsof_present $DEBUG_DELIM Make sure lsof system package is installed on the VM. You can try 'sudo $package_manager install lsof -y' to install it"
    echo "$SOFTWARE$DEBUG_DELIM xfsprogs $DEBUG_DELIM $xfsprogs_present $DEBUG_DELIM Make sure xfsprogs system package is installed on the VM. You can try 'sudo $package_manager install xfsprogs -y' to install it $DEBUG_DELIM Required"
    echo "$SOFTWARE$DEBUG_DELIM ifupdown $DEBUG_DELIM $ifupdown_present $DEBUG_DELIM Make sure ifupdown system package is installed on the VM. You can try 'sudo $package_manager install ifupdown -y' to install it $DEBUG_DELIM Required"
    echo "$SOFTWARE$DEBUG_DELIM net-tools $DEBUG_DELIM $net_tools_present $DEBUG_DELIM Make sure net-tools system package is installed on the VM. You can try 'sudo $package_manager install net-tools -y' to install it $DEBUG_DELIM Required"
    echo "$SOFTWARE$DEBUG_DELIM nftables $DEBUG_DELIM $nftables_present $DEBUG_DELIM Make sure nftables system package is installed on the VM. You can try 'sudo $package_manager install nftables -y' to install it $DEBUG_DELIM Required"
    echo "$SOFTWARE$DEBUG_DELIM acl $DEBUG_DELIM $acl_present $DEBUG_DELIM Make sure acl system package is installed on the VM. You can try 'sudo $package_manager install acl -y' to install it $DEBUG_DELIM Required"
    echo "$SOFTWARE$DEBUG_DELIM systemd $DEBUG_DELIM $systemd $DEBUG_DELIM Make sure systemd system package is installed on the VM. You can try 'sudo $package_manager install systemd -y' to install it $DEBUG_DELIM Required"
    echo "$SOFTWARE$DEBUG_DELIM rsyslog $DEBUG_DELIM $rsyslog $DEBUG_DELIM Make sure rsyslog system package is installed on the VM. You can try 'sudo $package_manager install rsyslog -y' to install it $DEBUG_DELIM Required"
    echo "$SOFTWARE$DEBUG_DELIM logrotate $DEBUG_DELIM $logrotate $DEBUG_DELIM Make sure logrotate system package is installed on the VM. You can try 'sudo $package_manager install logrotate -y' to install it $DEBUG_DELIM Required"
    echo "$CONFIG $DEBUG_DELIM db_os_user $DEBUG_DELIM $db_os_user_exist $DEBUG_DELIM Make sure the user '$db_os_user' exists on the VM"
    echo "$SOFTWARE$DEBUG_DELIM chrony $DEBUG_DELIM $chrony_present $DEBUG_DELIM Make sure chrony system package is installed on the VM. You can try 'sudo $package_manager install chrony -y' to install it"
    echo "===================================================================="
    # VM Info section for compatibility validation
    echo "$vminfo_message"
    echo "$VMINFO$DEBUG_DELIM os_distribution $DEBUG_DELIM $os_distribution"
    echo "$VMINFO$DEBUG_DELIM os_version $DEBUG_DELIM $os_version"
    echo "$VMINFO$DEBUG_DELIM database_version $DEBUG_DELIM $database_version"
    echo "$VMINFO$DEBUG_DELIM oracle_grid_version $DEBUG_DELIM $oracle_grid_version"
    echo "===================================================================="
fi

if [ "$database_type" != "oracle_database" ] && [ "$global_status" != "$SUCCESS" ]; then
    exit 1
fi
