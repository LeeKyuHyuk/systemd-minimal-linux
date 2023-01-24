#!/bin/bash
#
# Kernel build script
# Optional parameteres below:
set -o nounset
set -o errexit

export LC_ALL=POSIX
export CONFIG_HOST=$(echo ${MACHTYPE} | sed -e 's/-[^-]*/-cross/')

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
    error "Run 'make download'"
    exit 1
  fi
}

function check_tarballs() {
  LIST_OF_TARBALLS="
      linux-5.15.82.tar.xz
    "

  for tarball in $LIST_OF_TARBALLS; do
    if ! [[ -f $SOURCES_DIR/$tarball ]]; then
      error "Can't find '$tarball'!"
      exit 1
    fi
  done
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
check_tarballs
total_build_time=$(timer)

rm -rf $BUILD_DIR $KERNEL_DIR
mkdir -pv $BUILD_DIR $KERNEL_DIR

step "[1/1] Linux 5.15.82"
extract $SOURCES_DIR/linux-5.15.82.tar.xz $BUILD_DIR
make -j$PARALLEL_JOBS ARCH=$CONFIG_LINUX_ARCH mrproper -C $BUILD_DIR/linux-5.15.82
make -j$PARALLEL_JOBS ARCH=$CONFIG_LINUX_ARCH $CONFIG_LINUX_KERNEL_DEFCONFIG -C $BUILD_DIR/linux-5.15.82
# Setup Linux Kernel Configs
echo "CONFIG_RETHUNK=n" >>$BUILD_DIR/linux-5.15.82/.config
echo "CONFIG_STACKPROTECTOR=n" >>$BUILD_DIR/linux-5.15.82/.config
echo "CONFIG_GCC_PLUGINS=n" >>$BUILD_DIR/linux-5.15.82/.config
echo "CONFIG_INIT_STACK_NONE=y" >>$BUILD_DIR/linux-5.15.82/.config
echo "CONFIG_INIT_STACK_ALL_PATTERN=n" >>$BUILD_DIR/linux-5.15.82/.config
echo "CONFIG_INIT_STACK_ALL_ZERO=n" >>$BUILD_DIR/linux-5.15.82/.config
echo "CONFIG_INIT_ON_ALLOC_DEFAULT_ON=n" >>$BUILD_DIR/linux-5.15.82/.config
echo "CONFIG_INIT_ON_FREE_DEFAULT_ON=n" >>$BUILD_DIR/linux-5.15.82/.config
echo "CONFIG_ZERO_CALL_USED_REGS=n" >>$BUILD_DIR/linux-5.15.82/.config
make -j$PARALLEL_JOBS ARCH=$CONFIG_LINUX_ARCH HOSTCC="gcc -O2 -I$TOOLS_DIR/include -L$TOOLS_DIR/lib -Wl,-rpath,$TOOLS_DIR/lib" CROSS_COMPILE="$TOOLS_DIR/bin/$CONFIG_TARGET-" bzImage -C $BUILD_DIR/linux-5.15.82
cp -v $BUILD_DIR/linux-5.15.82/arch/x86/boot/bzImage $KERNEL_DIR/vmlinuz
rm -rf $BUILD_DIR/linux-5.15.82

success "\nTotal kernel build time: $(timer $total_build_time)\n"
