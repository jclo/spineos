#!/bin/bash
#
# Script to install slackware on an OVH VP SSD
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


OPTIONS=${OPTIONS:---no-check-certificate}
FIREWALL=${FIREWALL:-https://raw.github.com/jclo/spineos/14.2.1/rc.firewall.sh}
SLACKSCRIPT=${SLACKSCRIPT:-https://raw.github.com/jclo/spineos/14.2.1/_ovh/slack.sh}
SLACKROOTFS=${ROOTFS:-https://spineos.mobilabs.fr/_ovh/slack-rootfs.txz}
DEVICE='/dev/vdb' # ovh ssd (for vmware replace it by /dev/sda)
VOLUME=${DEVICE}1
LILODISK="disk = ${DEVICE} bios=0x80 max-partitions=7" #kvm (for vmware replace it by an empty string)
MODULES="ext4:virtio:virtio_pci:virtio_blk" # kvm (for vmware install the modules 'ext4:mptspi' instead)


# --- Private functions --------------------------------------------------------

##
# Returns 'true' if the platform is x86_64 running debian.
#
function _isDebianJessiex86_64() {
  local name=$(uname -n)
  local platform=$(uname -m)

  name=$(uname -n)
  platform=$(uname -m)

  echo 'Testing if the platform runs Debian 8.x 64bits ...'
  if [[ ${name} != 'rescue-pro' ]]; then
    echo 'It is not a debian in rescue-pro mode!'
    return 1
  fi

  if [[ ${platform} != 'x86_64' ]]; then
    echo 'It is not a x86_64 platform!'
    return 1
  fi

  return 0
}

##
# Checks if the volume /dev/vdb exists
#
function _isvolumevdb() {
  local dev=$DEVICE
  local vol=$VOLUME

  # Checks if the volume ${vol} exists:
  if [[ ! -e ${vol} ]]; then
    echo "The volume ${vol} does not exist!"
    return 1
  fi

  # Checks if it is mounted:
  if grep -qs ${vol} /proc/mounts; then
    echo "Umounting ${vol} ..."
    umount ${vol}
  fi

  # Checks if it contains the type '8e'
  VTYPE=$(fdisk -l | grep '8e')
  if [[ $VTYPE != *"${vol}"* ]]; then
    echo "The volume ${vol} is not formated with the Linux type 8e. Proceed!"
    echo -e "t\n8e\nw" | fdisk ${dev}
  fi

  return 0
}


##
# Installs the debian package LVM.
#
function _installLVM() {
  echo 'Installing the debian package lvm2 ...'
  export DEBIAN_FRONTEND=noninteractive
  apt-get update || { echo >&2 'apt-get update failed!'; return 1; }
  apt-get install -y lvm2 || { echo >&2 'The installation of the package lvm2 failed!'; return 1; }
  return 0
}


##
# Configures the logical volume vg0.
#
function _setLVMvolumes() {
  local vol=$VOLUME

  echo 'Creating volume group vg0 and logical volumes root and home ...'

  # Check if the lvm tools are installed:
  hash pvcreate 2>/dev/null || { echo >&2 'pvcreate is not installed!'; return 1; }

  # First remove all previous traces:
  umount -l /dev/vg0/root &>/dev/null
  umount -l /dev/vg0/home &>/dev/null
  lvremove -f /dev/vg0/root &>/dev/null
  lvremove -f /dev/vg0/home &>/dev/null
  vgremove -f /dev/vg0 &>/dev/null
  pvremove -f ${vol} &>/dev/null

  # Create the logical volumes:
  pvcreate ${vol} || { echo >&2 "pvcreate ${vol} failed!"; return 1; }
  vgcreate vg0 ${vol} || { echo >&2 "vgcreate vg0 ${vol} failed!"; return 1; }
  lvcreate -L 2G -n root vg0 || { echo >&2 'lvcreate -L 2G -n root vg0 failed!'; return 1; }
  lvcreate -L 7.9G -n home vg0 || { echo >&2 'lvcreate -L 7.9G -n home vg0 failed!'; return 1; }

  # Format them:
  mkfs.ext4 /dev/vg0/root || { echo >&2 'mkfs.ext4 /dev/vg0/root failed!'; return 1; }
  mkfs.ext4 /dev/vg0/home || { echo >&2 'mkfs.ext4 /dev/vg0/home failed!'; return 1; }

  # Mount the root volume:
  mount /dev/vg0/root /mnt

  return 0
}


##
# Installs a slackware rootfs.
#
function _installrootfs() {

  echo 'Installing a slackware rootfs ...'

  cd /tmp
  # Remove previous traces:
  rm -Rf slack-rootfs*
  # download rootfs:
  wget $OPTIONS $SLACKROOTFS
  tar xvf slack-rootfs.txz
  if [[ ! -d 'slack-rootfs' ]]; then
    echo 'slack-rootfs folder not created!'
    return 1
  fi

  # Patch installpkg to remove intempestive warnings:
  sed -i 's/LC_CTYPE L/L/' slack-rootfs/sbin/installpkg

  # Provide network resources to rootfs:
  cp /etc/resolv.conf slack-rootfs/etc/.
  mount --rbind /dev slack-rootfs/dev || { echo >&2 'mount --rbind /dev slack-rootfs/dev failed!'; return 1; }

  return 0
}


##
# Downloads and install the slackware packages.
#
function _installslackware() {

  echo 'Downloading and installing the slackware packages ...'

  # Get script to run in chroot:
  wget $OPTIONS $SLACKSCRIPT
  if [[ ! -e 'slack.sh' ]]; then
    echo 'The script slack.sh is missing!'
    return 1
  fi
  chmod +x slack.sh
  mv slack.sh slack-rootfs/tmp/.

  # Execute this script inside chroot:
  chroot /tmp/slack-rootfs /tmp/slack.sh

  return 0
}


##
# Copies slackware to /mnt.
#
function _copyslackware() {
  echo 'Copying Slackware rootfs to /mnt ...'
  cp -R /tmp/slack-rootfs/tmp/rootfs/* /mnt/. || { echo >&2 "Slackware rootfs can't be copies!"; return 1; }
  return 0
}


##
# Adds lilo.conf.
#
function _addliloconf() {

  cat > /mnt/etc/lilo.conf <<EOF
# LILO configuration file
append=" vt.default_utf8=0"
${LILODISK}
boot = ${DEVICE}
bitmap = /boot/slack.bmp
bmp-colors = 255,0,255,0,255,0
bmp-table = 60,6,1,16
bmp-timer = 65,27,0,255
prompt
timeout = 12
change-rules
  reset
vga = normal
# Linux bootable partition config begins
image = /boot/vmlinuz
  initrd = /boot/initrd.gz
  root = /dev/vg0/root
  label = Linux
  read-only
  append = "quiet"
# Linux bootable partition config ends
EOF
}


##
# Adds fstab.
#
function _addfstab() {
  cat > /mnt/etc/fstab <<EOF
/dev/vg0/root    /                ext4        defaults         1   1
/dev/vg0/home    /home            ext4        defaults         1   1
devpts           /dev/pts         devpts      gid=5,mode=620   0   0
proc             /proc            proc        defaults         0   0
tmpfs            /dev/shm         tmpfs       defaults         0   0
EOF
}


##
# Installs a firewall:
#
function _addfirewall() {
  cd /tmp
  wget $OPTIONS $FIREWALL
  if [[ ! -e 'rc.firewall.sh' ]]; then
    echo 'rc.firewall.sh cannot be downloaded!'
    return 1
  fi

  mv rc.firewall.sh /mnt/etc/rc.d/rc.firewall
  chmod +x /mnt/etc/rc.d/rc.firewall
  chmod +x /mnt/etc/rc.d/rc.ip_forward
  return 0
}


##
# Configures Slackware.
#
function _configureslackware() {
  local modules=$MODULES

  # Add lilo.conf:
  echo 'Adding a lilo.conf file ...'
  _addliloconf
  sleep 1

  # Add fstab:
  echo 'Adding a fstab ...'
  _addfstab
  sleep 1

  # Add a firewall:
  echo 'Adding a firewall ...'
  _addfirewall || { return 1; }

  # Enable root login for ssh:
  echo 'Authorizing root login for ssh ...'
  sed -i '/^#PermitRootLogin/a PermitRootLogin yes' /mnt/etc/ssh/sshd_config
  sleep 1

  # Enable DHCP:
  echo 'Enabling DHCP ...'
  sed -i 's/USE_DHCP\[0\]=""/USE_DHCP[0]="yes"/' /mnt/etc/rc.d/rc.inet1.conf
  sleep 1

  # Provide hardware resources:
  cp /etc/resolv.conf /mnt/etc/.
  mount --rbind /sys /mnt/sys
  mount --rbind /proc /mnt/proc
  mount --rbind /dev /mnt/dev

  # Create initrd file:
  echo 'Creating an initrd boot file for the generic kernel ...'

  chroot /mnt /bin/bash <<EOF
cd /boot
mkinitrd -c -k 4.4.14 -f ext4 -m ${modules} -r /dev/vg0/root -L -u
EOF
  sleep 1

  # Update lilo:
  echo 'Updating lilo ...'
  chroot /mnt /bin/bash <<EOF
lilo
EOF
  sleep 1

  # Add a root password:
  echo 'Adding a root password ...'
  PASS=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c8)
  chroot /mnt /bin/bash <<EOF
echo root:$PASS | chpasswd
EOF
  echo ''
  echo "Your root password is: $PASS"
  echo 'Memorize it!'
  echo 'Enjoy!'

  return 0
}


# -- Main
_isDebianJessiex86_64 || { echo >&2 "This platform isn't a Debian 64 bits. Process aborted ..."; exit 1; }
echo 'Done.'

_isvolumevdb || { echo >&2 "This platform has not the appropriate volumes. Process aborted ..."; exit 1; }
echo 'Done.'

_installLVM || { echo >&2 'The installation of the lvm2 package failed. Process aborted ...'; exit 1; }
echo 'Done.'

_setLVMvolumes || { echo >&2 "The LMV volumes can't be set. Process aborted ..."; exit 1; }
echo 'Done.'

_installrootfs || { echo >&2 "The slackware rootfs can't be installed. Process aborted ..."; exit 1; }
echo 'Done.'

_installslackware  || { echo >&2 "The slackware can't be installed. Process aborted ..."; exit 1; }
echo 'Done.'

_copyslackware  || { echo >&2 "The slackware rootfs can't be copied. Process aborted ..."; exit 1; }
echo 'Done.'

_configureslackware || { echo >&2 "The slackware configuration failed. Process aborted ..."; exit 1; }
echo 'Done.'
