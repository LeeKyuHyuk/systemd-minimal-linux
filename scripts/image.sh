#!/bin/bash
#
# Image generate script
# Optional parameteres below:
set -o nounset
set -o errexit

# End of optional parameters

function step() {
  echo -e "\e[7m\e[1m>>> $1\e[0m"
}

function success() {
  echo -e "\e[1m\e[32m$1\e[0m"
}

function error() {
  echo -e "\e[1m\e[31m$1\e[0m"
}

function extract() {
  case $1 in
  *.tgz) tar -zxf $1 -C $2 ;;
  *.tar.gz) tar -zxf $1 -C $2 ;;
  *.tar.bz2) tar -jxf $1 -C $2 ;;
  *.tar.xz) tar -Jxf $1 -C $2 ;;
  esac
}

function check_environment() {
  if ! [[ -d $SOURCES_DIR ]]; then
    error "Please download tarball files!"
    error "Run './01-download-packages.sh'"
    exit 1
  fi
}

function timer() {
  if [[ $# -eq 0 ]]; then
    echo $(date '+%s')
  else
    local stime=$1
    etime=$(date '+%s')
    if [[ -z "$stime" ]]; then stime=$etime; fi
    dt=$((etime - stime))
    ds=$((dt % 60))
    dm=$(((dt / 60) % 60))
    dh=$((dt / 3600))
    printf '%02d:%02d:%02d' $dh $dm $ds
  fi
}

check_environment
total_build_time=$(timer)

rm -rf $IMAGES_DIR $BUILD_DIR
mkdir -pv $IMAGES_DIR/isoimage $BUILD_DIR
rsync -auH $ROOTFS_DIR $IMAGES_DIR
printf 'dbus -1 dbus -1 * /run/dbus - dbus DBus messagebus user\n 	# udev user groups\n	- - render -1 * - - - DRI rendering nodes\n	- - sgx -1 * - - - SGX device nodes\n	# systemd user groups\n	- - systemd-journal -1 * - - - Journal\n	\n	\n	\n	systemd-network -1 systemd-network -1 * - - - systemd Network Management\n	systemd-resolve -1 systemd-resolve -1 * - - - systemd Resolver\n	systemd-timesync -1 systemd-timesync -1 * - - - systemd Time Synchronization\n 	- - input -1 * - - - Input device group\n	- - kvm -1 * - - - kvm nodes\n\n' >$IMAGES_DIR/users_table.txt
printf '/usr/libexec/dbus-daemon-launch-helper f 4750 0 dbus - - - - -\n 	/var/spool d 755 0 0 - - - - -\n	/var/lib d 755 0 0 - - - - -\n	/var/lib/private d 700 0 0 - - - - -\n	/var/log/private d 700 0 0 - - - - -\n	/var/cache/private d 700 0 0 - - - - -\n	\n	\n	\n	\n	/var/lib/systemd/pstore d 755 0 0 - - - - -\n	/var/lib/systemd/timesync d 755 systemd-timesync systemd-timesync - - - - -\n\n' >$IMAGES_DIR/devices_table.txt
cat $SUPPORT_DIR/makedevs/device_table.txt >>$IMAGES_DIR/devices_table.txt
echo '#!/bin/sh' >$IMAGES_DIR/fakeroot
echo "set -e" >>$IMAGES_DIR/fakeroot
echo "chown -h -R 0:0 $IMAGES_DIR/rootfs" >>$IMAGES_DIR/fakeroot
$SUPPORT_DIR/mkusers/mkusers $IMAGES_DIR/users_table.txt $IMAGES_DIR/rootfs >>$IMAGES_DIR/fakeroot
echo "$TOOLS_DIR/bin/makedevs -d $IMAGES_DIR/devices_table.txt $IMAGES_DIR/rootfs" >>$IMAGES_DIR/fakeroot
printf "$TOOLS_DIR/sbin/mkfs.ext2 -d $IMAGES_DIR/rootfs -r 1 -N 0 -m 5 -L \"rootfs\" -O ^64bit $IMAGES_DIR/rootfs.ext2 \"150M\"" >>$IMAGES_DIR/fakeroot
chmod a+x $IMAGES_DIR/fakeroot
FAKEROOTDONTTRYCHOWN=1 $TOOLS_DIR/bin/fakeroot -- $IMAGES_DIR/fakeroot
success "\nTotal image build time: $(timer $total_build_time)\n"
