#!/bin/bash
#
# Script to install a slackware minimalist server.
#
# copyright 2016 jclo <jclo@mobilabs.fr> (http://www.mobilabs.fr/)
#
# Redistribution and use of this script, with or without modification, is
# permitted provided that the following conditions are met:
#
# 1. Redistributions of this script must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
#  THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR IMPLIED
#  WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
#  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO
#  EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
#  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
#  OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
#  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
#  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
#  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# The type of slackware to install:
SUITE=${SUITE:-slackware64-14.2}
# Where to find the slackware packages:
MIRROR=${MIRROR:-http://mirrors.slackware.com/slackware}
# Where to download the packages:
CACHE=${CACHE:-/var/cache/packages}
# Where to install slackware:
ROOTFS=${ROOTFS:-/tmp/rootfs}

# The set of packages needed to build a minimalist slackware server:
PACKAGES=${PACKAGES:-" \
  aaa_base aaa_elflibs aaa_terminfo attr bash bin bzip2 coreutils cpio \
  dbus dcron devs dialog e2fsprogs elvis etc eudev findutils \
  gawk getty-ps glibc-solibs glibc-zoneinfo grep gzip \
  kbd kernel-generic kernel-modules kmod less lilo logrotate lvm2 mkinitrd \
  openssl-solibs patch pciutils pkgtools procps-ng quota \
  sed shadow sharutils slocate sysfsutils sysklogd syslinux sysvinit \
  sysvinit-functions sysvinit-scripts tar utempter util-linux which xz \
  diffutils screen slackpkg \
  icu4c libnl libnl3 libpcap mpfr \
  dhcpcd gnupg gpgme iptables iputils net-tools network-scripts ntp openssh wget"
}


# --- Private functions --------------------------------------------------------

##
# Sets an environment friendly to slackware scripts:
#
function _set_environment() {

  echo 'Preparing the ground for the slackware scripts ...'

  # Set the download server:
  echo 'Defining Slackware mirrors ...'
  echo "$MIRROR/$SUITE/" > /etc/slackpkg/mirrors

  return 0
}

##
# Downloads the slackware packages required to build a minimalist server.
#
function _download_slackware_packages {
  local DEST=$CACHE/slackware64

  # First, cleanup
  if [ -e $DEST ]; then
    echo "Cleaning up existing $DEST folder ... "
    rm -Rf $DEST
  fi

  # download the packages into the cache folder
  echo "Downloading the required slackware packages ..."
  sleep 3
  (
    # Update the list of packages:
    slackpkg -batch=on update

    # Download the packages:
    for package in $PACKAGES; do
      slackpkg -batch=on -default_answer=y download $package
    done
  )

  if [ $? -ne 0 ]; then
    echo "Failed to download the packages."
    return 1
  fi

}


##
# Creates a slackware rootfs.
#
function _create_slackware_rootfs() {
  local FLAT=$CACHE/flat
  local rootfs=$1

  if [ -e $rootfs ]; then
    echo "Cleaning up existing $rootfs folder ... "
    rm -fR $rootfs
  fi
  mkdir -p $rootfs

  echo "Copying packages in $FLAT ..."
  if [ -e $FLAT ]; then
    echo "Cleaning up existing $FLAT folder ... "
    rm -fR $FLAT
  fi
  mkdir -p $FLAT
  find $CACHE/slack*/. -name "*.t?z" -type f -exec cp {} $FLAT \;
  rm -Rf $CACHE/slackware64

  echo "Installing packages in $rootfs ... "
  for package in $FLAT/*.t?z ; do
    installpkg -root $rootfs -terse -priority ADD $package
  done

  return 0
}


# --- Main -

cd /tmp

_set_environment
if [[ $? -ne 0 ]]; then
  echo 'Something went wrong, we could not set the environment. Process aborted ...'
  exit 1
fi
echo 'Done.'
sleep 1

_download_slackware_packages
if [[ $? -ne 0 ]]; then
  echo 'Something went wrong, we could not download the slackware packages. Process aborted ...'
  exit 1
fi
echo 'Done.'
sleep 1

_create_slackware_rootfs $ROOTFS
if [[ $? -ne 0 ]]; then
  echo 'Something went wrong, we could not install the slackware packages. Process aborted ...'
  exit 1
fi
echo 'Done.'
