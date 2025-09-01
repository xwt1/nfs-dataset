#!/bin/sh
#
# Setup a simple NFS server exporting /nfs
#
# This script is derived from Jonathan Ellithorpe's Cloudlab profile at
# https://github.com/jdellithorpe/cloudlab-generic-profile. Thanks!
#
# Hacked by mike to work on FreeBSD. The whole strategy has been changed
# however. Rather than insert commands/variables into the standard system
# files to have every thing restart on reboot via the standard mechanisms,
# we handle all the startup from this script. This is because the standard
# mechanisms run well before the Emulab scripts have configured the
# experimental LAN we are serving files on. On the other hand, this script
# runs at the end of the Emulab scripts. I do not know how the old method
# worked even on Linux when there was a reboot!
#
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

NFSDIR="/nfs"
NFSNETNAME="nfsLan"          # must match profile LAN name
HOSTNAME_SHORT="$(hostname -s)"

# wait until RemoteBlockstore is mounted at /nfs
for i in $(seq 1 240); do mountpoint -q "$NFSDIR" && break; sleep 2; done

apt-get -yq update
apt-get -yq install nfs-kernel-server nfs-common rpcbind

# derive experiment-LAN IP of this server from /etc/hosts (name: nfs-nfsLan)
NFS_HOST_ALIAS="${HOSTNAME_SHORT}-${NFSNETNAME}"
if ! grep -q "^[0-9].*${NFS_HOST_ALIAS}\b" /etc/hosts; then
  echo "${NFS_HOST_ALIAS} not found in /etc/hosts" >&2
  exit 1
fi
NFS_IP=$(grep -m1 "^[0-9].*${NFS_HOST_ALIAS}\b" /etc/hosts | awk '{print $1}')
NFS_NET=$(echo "$NFS_IP" | awk -F. '{printf "%s.%s.%s.0", $1,$2,$3}')

# bind rpcbind to loopback + experiment LAN IP (like the official script)
echo "OPTIONS=\"-l -h 127.0.0.1 -h ${NFS_IP}\"" > /etc/default/rpcbind
# allow rpcbind from clients
sed -i.bak -e "s/^rpcbind/#rpcbind/" /etc/hosts.deny || true

# exports: export /nfs to the experiment /24
mkdir -p /etc/exports.d
# use exports.d to avoid clobbering existing /etc/exports
echo "${NFSDIR} ${NFS_NET}/24(rw,sync,no_root_squash,no_subtree_check,fsid=0)" > /etc/exports.d/nfs.exports

systemctl stop nfs-kernel-server || true
systemctl restart rpcbind || true
systemctl start nfs-kernel-server || true
exportfs -ra || true

# wait until the export is visible
for i in $(seq 1 120); do exportfs -v 2>/dev/null | grep -q "^${NFSDIR} " && break; sleep 2; done
exit 0
