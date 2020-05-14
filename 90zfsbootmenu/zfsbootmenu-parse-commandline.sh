#!/bin/sh

. /lib/dracut-lib.sh

# Let the command line override our host id.
spl_hostid=$(getarg spl_hostid=)
if [ -n "${spl_hostid}" ] ; then
  info "ZFSBootMenu: Using hostid from command line: ${spl_hostid}"
  AA=$(echo "${spl_hostid}" | cut -b 1,2)
  BB=$(echo "${spl_hostid}" | cut -b 3,4)
  CC=$(echo "${spl_hostid}" | cut -b 5,6)
  DD=$(echo "${spl_hostid}" | cut -b 7,8)
  echo -ne "\\x${DD}\\x${CC}\\x${BB}\\x${AA}" >/etc/hostid
elif [ -f "/etc/hostid" ] ; then
  info "ZFSBootMenu: Using hostid from /etc/hostid: $(hostid)"
else
  warn "ZFSBootMenu: No hostid found on kernel command line or /etc/hostid."
  warn "ZFSBootMenu: Pools may not import correctly."
fi

# Force import pools only when explicitly told to do so
if getargbool 0 force_import ; then
  info "ZFSBootMenu: Enabling force import of ZFS pools"
  import_args="-o readonly=on -f -N"
else
  import_args="-o readonly=on -N"
fi

# Import pools by default in read-write mode
if getargbool 0 read_write ; then
  info "ZFSBootMenu: Enabling read-write ZFS pool import"
  import_args="${import_args/readonly=on/readonly=off}"
fi

# Set a menu timeout, to allow immediate booting
menu_timeout=$( getarg timeout=)
if [ -n "${menu_timeout}" ]; then
  info "ZFSBootMenu: Setting menu timeout from command line: ${menu_timeout}"
else
  menu_timeout=10
fi

if getargbool 1 die_on_import_failure ; then
  info "ZFSBootMenu: Disabling die on import failure"
fi

# Get a list of pools to not import on boot
skip_pools=$( getarg skip_pools=)
if [ -n "${skip_pools}" ] ; then
  info "ZFSBootMenu: Setting ${skip_pools} as skippable pools"
  IFS=',' read -a skippable_pools <<<"${skip_pools}"
fi

wait_for_zfs=0
case "${root}" in
  ""|zfsbootmenu|zfsbootmenu:)
    # We'll take root unset, root=zfsbootmenu, or root=zfsbootmenu:
    root="zfsbootmenu"
    rootok=1
    wait_for_zfs=1

    info "ZFSBootMenu: Enabling menu after udev settles"
    ;;
  zfsbootmenu:POOL\=*)
    # Prefer a specific pool for bootfs value, root=zfsbootmenu:POOL=zroot
    root="${root#zfsbootmenu:POOL=}"
    rootok=1
    wait_for_zfs=1

    info "ZFSBootMenu: Preferring ${root} for bootfs"
    ;;
esac

# Make sure Dracut is happy that we have a root and will wait for ZFS
# modules to settle before mounting.
if [ ${wait_for_zfs} -eq 1 ]; then
  ln -s /dev/null /dev/root 2>/dev/null
  initqueuedir="${hookdir}/initqueue/finished"
  test -d "${initqueuedir}" || {
    initqueuedir="${hookdir}/initqueue-finished"
  }
  echo '[ -e /dev/zfs ]' > "${initqueuedir}/zfs.sh"
fi
