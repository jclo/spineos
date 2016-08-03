#!/bin/sh
#
# Slackware script to finalyze the build of SpineOS.
#
# copyright 2015-2016 jclo <jclo@mobilabs.fr> (http://www.mobilabs.fr/)
#
# This script downloads and activates a firewall based on iptables
# that drops all UDP/TCP inbound packets except SSH service on port
# 22.
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

VERSION="14.2.0"
FWPATH="https://raw.github.com/jclo/spineos/${VERSION}"
OPTION="--no-check-certificate"

#
# -- Functions
#

##
# Download and install rc.firewall service.
#
function _set_firewall() {
  cd /etc/rc.d

  # Download it:
  echo "Downloading rc.firewall..."
  wget $OPTION $FWPATH/rc.firewall.sh
  if [[ $? -ne 0 ]]; then
    echo "Failed to download rc.firewall.sh. Process aborted ..."
    exit 1
  fi

  # Ok. Rename it and activate the service:
  echo "Activating rc.firewall service..."
  mv rc.firewall.sh rc.firewall
  chmod +x rc.firewall
  chmod +x rc.ip_forward
}

##
# Force the root password to be changed at the first login.
#
function _force_update_root_password() {
  echo "Installing a script to force updating root password at the first login..."
  cat > /root/.bash_profile <<EOF
#
# This script forces the admin user to change the admin password after the login.
#

echo ' '
echo 'You MUST immediately change your password.'
echo 'Otherwise you CANNOT login anymore!'
echo ' '

# Copy the rsa certificates to 'root'
mkdir -p /root/.ssh
cp /etc/ssh/ssh_host_rsa_key /root/.ssh/id_rsa
cp /etc/ssh/ssh_host_rsa_key.pub /root/.ssh/id_rsa.pub

# Force root password to expire
passwd -e root

# Display status to user
chage -l root

# Delete the script
rm /root/.bash_profile

# end
EOF
  chmod +x /root/.bash_profile

}

#
# -- Main
#

# Is rc.firewall already installed?
cd /etc/rc.d
if [[ -f "rc.firewall" ]]; then
  echo "rc.firewall is already installed!"
else
  _set_firewall
fi

# Install a script to force changing the root password at first login:
_force_update_root_password

# Update version & keyboard map:
sed -i "s/^.*\bSlackware 14.2\b.*$/SpineOS ${VERSION} (Slackware 14.2)/" /etc/slackware-version
sed -i '4s/.*/ \/usr\/bin\/loadkeys us.map/' /etc/rc.d/rc.keymap

# Do not authorize ssh root login:
sed -i "s/^PermitRootLogin yes/#PermitRootLogin yes/" /etc/ssh/sshd_config

# Some clean up operations:

# Delete the cache:
if [[ -d "/var/cache/slackware" ]]; then
  echo "Flushing the caches..."
  rm -R "/var/cache/slackware"
fi

# Delete the current certificates:
echo "Deleting the current certificates..."
cd /etc/ssh
rm *.pub
rm *_key

# Delete the history:
echo "Deleting the bash history..."
rm /root/.bash_history

# Delete tmp content:
cd /tmp
find "/tmp" -type f -exec rm {} \;

# Shrink disk if vmware-toolbox-cmd tool is installed:
if [[ -x "/usr/bin/vmware-toolbox-cmd" ]]; then
  echo "Shrinking the disk 3 times ..."
  vmware-toolbox-cmd disk shrink /
  vmware-toolbox-cmd disk shrink /
  vmware-toolbox-cmd disk shrink /
fi

# --o-
