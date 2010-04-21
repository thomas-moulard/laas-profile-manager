#! /bin/sh
# Tools allowing the control of several LAAS development profiles.
# $Id$
# Copyright (C) 2010 Thomas Moulard
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# ------ #
# README #
# ------ #
#
# This tool manages compilation profiles for LAAS computers and more
# particularly for people working with RobotPkg and HPP/KPP packages.


# ---------------- #
# Global variables #
# ---------------- #

profiles_directory=$HOME/profiles
git_prefix=ssh://softs.laas.fr/git

default_stable_software="hpp-walkfootplanner"
default_unstable_software=""

me=$0
version='0.1'


# ---------------- #
# Helper functions #
# ---------------- #

set_colors()
{
  red='[0;31m';    lred='[1;31m'
  green='[0;32m';  lgreen='[1;32m'
  yellow='[0;33m'; lyellow='[1;33m'
  blue='[0;34m';   lblue='[1;34m'
  purple='[0;35m'; lpurple='[1;35m'
  cyan='[0;36m';   lcyan='[1;36m'
  grey='[0;37m';   lgrey='[1;37m'
  white='[0;38m';  lwhite='[1;38m'
  std='[m'
}

set_nocolors()
{
   red=;    lred=
   green=;  lgreen=
   yellow=; lyellow=
   blue=;   lblue=
   purple=; lpurple=
   cyan=;   lcyan=
   grey=;   lgrey=
   white=;  lwhite=
   std=
}

# abort err-msg
abort()
{
   echo "laas-profile-manager: ${lred}abort${std}: $@" \
   | sed '1!s/^[         ]*/             /' >&2
   exit 1
}

# error err-msg
error()
{
   echo "laas-profile-manager: ${lred}error${std}: $@" \
   | sed '1!s/^[         ]*/             /' >&2
}


# warn msg
warn()
{
   echo "laas-profile-manager: ${lred}warning${std}: $@" \
   | sed '1!s/^[         ]*/             /' >&2
}

# notice msg
notice()
{
   echo "laas-profile-manager: ${lyellow}notice${std}: $@" \
   | sed '1!s/^[         ]*/              /' >&2
}

# yesno question
yesno()
{
  printf "$@ [y/N] "
  read answer || return 1
  case $answer in
    y* | Y*) return 0;;
    *)       return 1;;
  esac
  return 42 # should never happen...
}



help()
{
cat <<EOF
usage: laas-profile-manager.sh [--help] [--version] COMMAND [ARGS]

Commands are:
  create		create a development profile
  remove		remove a development profile
  refresh-licenses      synchronize Kineo licenses

It is recommanded to name profiles using the following format:
   <profile-name>-<architecture>-<os>-<distribution>
For instance, the default profile on Fedora 12 would be:
   default-i386-linux-fedora-12
EOF
}

version()
{
cat <<EOF
laas-profile-manager.sh version $version

Written by Thomas Moulard <tmoulard@laas.fr>
EOF
}

retrieve_licenses()
{
#FIXME: find a better solution for this...
license_dir=/home/tmoulard/laas-profile-manager/licenses
test -d $license_dir && cp $license_dir/* "$profiles_directory/license/" \
 || return 1
return 0
}

check_profile_directory()
{
if ! test -d $profiles_directory; then
 if ! yesno "Do you want to create the profile directory ($profiles_directory)?"
 then
  exit 0
 fi
 mkdir "$profiles_directory"
fi

if ! test -d "$profiles_directory/license"; then
 mkdir "$profiles_directory/license"
 retrieve_licenses
fi
}

install_stable_package()
{
notice "Installing $1..."

cd "$profiles_directory/$profile_name" || abort "Failed to access profile."
cd src/stable
pkg_dir=`find -type d -and -name "$1" | grep -v wip`
cd $pkg_dir
make install
}

install_unstable_package()
{
notice "Should be installing $1, but unfortunately this feature is not yet implemented :)"
notice "Skipping..."
}

generate_config_sh()
{
config_file="$profiles_directory/$profile_name/config.sh"
cat > $config_file <<EOF
# Named directories.
p=$profiles_directory/$profile_name
pb=\$p/build; pi=\$p/install; ps=\$p/src
pbs=\$p/build/stable; pis=\$p/install/stable; pss=\$p/src/stable
pbu=\$p/build/unstable; piu=\$p/install/unstable; psu=\$p/src/unstable

# RobotPkg
export ROBOTPKG_BASE=\$pis
export PATH="\$ROBOTPKG_BASE/bin:\$PATH"
export PATH="\$ROBOTPKG_BASE/sbin:\$PATH"
export PKG_CONFIG_PATH="\$ROBOTPKG_BASE/lib/pkgconfig:\$PKG_CONFIG_PATH"
export LD_LIBRARY_PATH="\$ROBOTPKG_BASE/lib:\$LD_LIBRARY_PATH"
export LD_LIBRARY_PATH="\$ROBOTPKG_BASE/kineo/lib:\$LD_LIBRARY_PATH"
export PYTHONPATH="\$ROBOTPKG_BASE/lib/python2.6/site-packages:\$PYTHONPATH"

# Development prefix.
export PATH="\$piu/bin:\$PATH"
export PATH="\$piu/sbin:\$PATH"
export PKG_CONFIG_PATH="\$piu/lib/pkgconfig:\$PKG_CONFIG_PATH"
export LD_LIBRARY_PATH="\$piu/lib:\$LD_LIBRARY_PATH"
export PYTHONPATH="\$piu/lib/python2.6/site-packages:\$PYTHONPATH"
export LTDL_LIBRARY_PATH="\$piu/lib/roboptim-core:\$LTDL_LIBRARY_PATH"

# For RobOptim...
export LTDL_LIBRARY_PATH="\$ROBOTPKG_BASE/lib/roboptim:\$LTDL_LIBRARY_PATH"
export LTDL_LIBRARY_PATH="\$piu/lib/roboptim:\$LTDL_LIBRARY_PATH"

# Kineo
export RLM_LICENSE=\$(find \$p/../license/ -name "RLM_Toulouse-\`hostname | sed 's/.laas.fr\$//'\`-*.lic")
if test x"\$RLM_LICENSE" = x; then
 echo "Warning: No Kineo license have been found for that machine."
fi
export KPP_INSTALL_DIR=\$ROBOTPKG_BASE/kineo

export JRL_FTP_USER=jrl
export JRL_FTP_PASSWD=`cat /home/tmoulard/laas-profile-manager/ftp.pwd`

EOF
}

initialize_stable_software()
{
cd "$profiles_directory/$profile_name" || abort "Failed to access profile."
cd src || abort "Failed to change directory."
git clone $git_prefix/robots/robotpkg.git stable \
 || abort "Failed to clone robotpkg repository."
git clone $git_prefix/robots/robotpkg-wip.git stable/wip \
 || abort "Failed to clone robotpkg-wip repository."
cd .. || abort "Failed to change directory."
$profiles_directory/$profile_name/src/stable/bootstrap/bootstrap \
 --prefix="$profiles_directory/$profile_name/install/stable"

# Fix robotpkg.conf.
cat >> "$profiles_directory/$profile_name/install/stable/etc/robotpkg.conf" <<EOF
WRKOBJDIR=$profiles_directory/$profile_name/build/stable
MAKE_JOBS=3

ACCEPTABLE_LICENSES+=jdk14-license
ACCEPTABLE_LICENSES+=sun-java3d-license
ACCEPTABLE_LICENSES+=sun-jre6-license
ACCEPTABLE_LICENSES+=jmf-license
ACCEPTABLE_LICENSES+=sun-jdk6-license
ACCEPTABLE_LICENSES+=kineocam-license
ACCEPTABLE_LICENSES+=eclipse-public-license
ACCEPTABLE_LICENSES+=aemdesign-cfsqp-license
ACCEPTABLE_LICENSES+=openhrp-grx-license

PKG_OPTIONS.hpp-core+=                  verbose1
PKG_OPTIONS.hpp-openhrp+=               verbose1
PKG_OPTIONS.hpp-walkfootplanner+=       verbose
PKG_OPTIONS.hpp-walkplanner+=           verbose
PKG_OPTIONS.jrl-walkgen+=
PKG_OPTIONS.hpp-corbaserver+=           verbose1
PKG_OPTIONS.hpp-kwsplus+=               verbose1
PKG_OPTIONS.hpp-model+=                 verbose1
PKG_OPTIONS.hrp2-dynamics+=
PKG_OPTIONS.jrl-dynamics+=
PKG_OPTIONS.jrl-mathtools+=
PKG_OPTIONS.t3d+=                       verbose1
PKG_OPTIONS.kpp-interface+=             verbose1
PKG_OPTIONS.kpp-interfacewalk+=         verbose1

EOF

# Prefill RobotPkg distfiles.
mkdir "$profiles_directory/$profile_name/src/stable/distfiles/"
robotpkg_distfiles_dir="/home/tmoulard/laas-profile-manager/distfiles"
test -d $robotpkg_distfiles_dir \
 && cp $robotpkg_distfiles_dir/* \
       "$profiles_directory/$profile_name/src/stable/distfiles/" \
 || warn "Failed to prefill RobotPkg distfiles."
}

initialize_unstable_software()
{
cd "$profiles_directory/$profile_name" || abort "Failed to access profile."
cd src || "Failed to change directory."
mkdir unstable
cd unstable || "Failed to change directory."
mkdir genom hpp kpp roboptim third-party
}

create_profile()
{
if test $# -eq 0; then
 abort "Missing profile name."
fi

profile_name=$1

check_profile_directory
if test -d "$profiles_directory/$profile_name"; then
 abort "Profile already exist. Please delete it first."
fi

mkdir "$profiles_directory/$profile_name" || abort "Failed to create profile."
cd "$profiles_directory/$profile_name" || abort "Failed to access profile."

mkdir src build install

# stable software - RobotPkg
notice "Bootstrapping stable software (from RobotPkg)..."
initialize_stable_software

# unstable software - Git
notice "Bootstrapping unstable software (from Git)..."
initialize_unstable_software

# generate configuration shell script.
generate_config_sh

# load configuration before installing packages...
(source "$profiles_directory/$profile_name/config.sh"
for pkg in $default_stable_software; do
 if ! install_stable_package "$pkg"; then
  warn "Failed to install $pkg."
 fi
done

for pkg in $default_unstable_software; do
 if ! install_unstable_package "$pkg"; then
  warn "Failed to install $pkg."
 fi
done)
}

remove_profile()
{
if test $# -eq 0; then
 abort "Missing profile name."
fi

profile_name=$1

if ! test -d "$profiles_directory/$profile_name"; then
 warn "Profile $profile_name does not exist."
 exit 0
fi

if ! yesno "Profile $profile_name will be removed. Are you sure?"; then
 exit 0
fi
rm -rf "$profiles_directory/$profile_name"
}

refresh_licenses()
{
 check_profile_directory
 if retrieve_licenses; then
  notice "Licenses successfully refreshed."
 else
  error "Failed to refresh licenses."
 fi
}

load_profile()
{
if test $# -eq 0; then
 abort "Missing profile name."
fi

profile_name=$1

if ! test -d "$profiles_directory/$profile_name"; then
 abort "Profile does not exist."
fi
cat "$profiles_directory/$profile_name/config.sh"
}

# ------------------- #
# `main' starts here. #
# ------------------- #

# Define colors if stdout is a tty.
if test -t 1; then
   set_colors
else # stdout isn't a tty => don't print colors.
   set_nocolors
fi

# One argument at least is required.
if test $# -eq 0; then
   help "$@"
   exit 0
fi

# For dev's:
test "x$1" = x--debug && shift && set -x

case $1 in
   create)
      shift
      create_profile "$@"
      ;;
   remove)
      shift
      remove_profile "$@"
      ;;
   refresh-licenses)
      shift
      refresh_licenses "$@"
      ;;
   load-profile)
      shift
      load_profile "$@"
      ;;
   help | -help | --help | -h)
      shift
      help "$@"
      ;;
   version | -version | --version | -v)
      shift
      version "$@"
      ;;
   *)
      error "Unknown option $1"
      help "$@"
      ;;
esac
