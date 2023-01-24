#!/bin/bash
#
# Toolchain build script
# Optional parameteres below:
set +h
set -o nounset
set -o errexit
umask 022

export LC_ALL=POSIX
export CONFIG_HOST=`echo ${MACHTYPE} | sed -e 's/-[^-]*/-cross/'`

export CFLAGS="-O2 -I$TOOLS_DIR/include"
export CPPFLAGS="-O2 -I$TOOLS_DIR/include"
export CXXFLAGS="-O2 -I$TOOLS_DIR/include"
export LDFLAGS="-L$TOOLS_DIR/lib -Wl,-rpath,$TOOLS_DIR/lib"

export PKG_CONFIG="$TOOLS_DIR/bin/pkg-config"
export PKG_CONFIG_SYSROOT_DIR="/"
export PKG_CONFIG_LIBDIR="$TOOLS_DIR/lib/pkgconfig:$TOOLS_DIR/share/pkgconfig"
export PKG_CONFIG_ALLOW_SYSTEM_CFLAGS=1
export PKG_CONFIG_ALLOW_SYSTEM_LIBS=1

CONFIG_PKG_VERSION="Systemd Minimal Linux for x86_64 2023.01"
CONFIG_BUG_URL="https://github.com/LeeKyuHyuk/systemd-minimal-linux"

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
        *.zip) unzip $1 -d $2 ;;
        *.tgz) tar -zxf $1 -C $2 ;;
        *.tar.gz) tar -zxf $1 -C $2 ;;
        *.tar.bz2) tar -jxf $1 -C $2 ;;
        *.tar.xz) tar -Jxf $1 -C $2 ;;
    esac
}

function check_environment_variable {
    if ! [[ -d $SOURCES_DIR ]] ; then
        error "Please download tarball files!"
        error "Run 'make download'."
        exit 1
    fi
}

function check_tarballs {
    LIST_OF_TARBALLS="
        Jinja2-3.1.2.tar.gz
        MarkupSafe-2.0.1.tar.gz
        Python-3.11.1.tar.xz
        acl-2.3.1.tar.xz
        attr-2.5.1.tar.xz
        autoconf-2.71.tar.xz
        automake-1.16.5.tar.xz
        binutils-2.38.tar.xz
        bison-3.8.2.tar.xz
        bzip2-1.0.8.tar.gz
        dtc-1.6.1.tar.xz
        e2fsprogs-1.46.5.tar.gz
        elfutils-0.188.tar.bz2
        expat-2.5.0.tar.xz
        fakeroot_1.30.1.orig.tar.gz
        flex-2.6.4.tar.gz
        gawk-5.2.1.tar.xz
        gcc-12.2.0.tar.xz
        gettext-0.21.1.tar.xz
        glib-2.72.3.tar.xz
        glibc-2.36.tar.xz
        gmp-6.2.1.tar.xz
        gperf-3.1.tar.gz
        kmod-30.tar.xz
        libcap-2.66.tar.xz
        libffi-3.4.4.tar.gz
        libtool-2.4.7.tar.xz
        linux-5.15.82.tar.xz
        m4-1.4.19.tar.xz
        meson-1.0.0.tar.gz
        mpc-1.2.1.tar.gz
        mpfr-4.1.0.tar.xz
        ncurses-6.3.tar.gz
        openssl-1.1.1s.tar.gz
        patchelf-0.17.0.tar.bz2
        pcre-8.45.tar.bz2
        pkgconf-1.8.0.tar.xz
        setuptools-65.5.0.tar.gz
        tzcode2022g.tar.gz
        tzdata2022g.tar.gz
        util-linux-2.38.1.tar.xz
        v1.11.1.tar.gz
        v252.tar.gz
        xz-5.4.0.tar.bz2
        zlib-1.2.13.tar.xz
    "

    for tarball in $LIST_OF_TARBALLS ; do
        if ! [[ -f $SOURCES_DIR/$tarball ]] ; then
            error "Can't find '$tarball'!"
            exit 1
        fi
    done
}

function do_strip {
    set +o errexit
    if [[ $CONFIG_STRIP_AND_DELETE_DOCS = 1 ]] ; then
        strip --strip-debug $TOOLS_DIR/lib/*
        strip --strip-unneeded $TOOLS_DIR/{,s}bin/*
        rm -rf $TOOLS_DIR/{,share}/{info,man,doc}
    fi
}

function timer {
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

check_environment_variable
check_tarballs
total_build_time=$(timer)

step "[1/50] Create toolchain directory."
rm -rf $BUILD_DIR $TOOLS_DIR
mkdir -pv $BUILD_DIR $TOOLS_DIR
ln -svf . $TOOLS_DIR/usr
if [[ "$CONFIG_LINUX_ARCH" = "x86" ]] ; then
      ln -snvf lib $TOOLS_DIR/lib32
fi
if [[ "$CONFIG_LINUX_ARCH" = "x86_64" ]] ; then
      ln -snvf lib $TOOLS_DIR/lib64
fi

step "[2/50] Create the sysroot directory"
mkdir -pv $SYSROOT_DIR
ln -svf . $SYSROOT_DIR/usr
mkdir -pv $SYSROOT_DIR/lib
if [[ "$CONFIG_LINUX_ARCH" = "x86" ]] ; then
    ln -snvf lib $SYSROOT_DIR/lib32
fi
if [[ "$CONFIG_LINUX_ARCH" = "x86_64" ]] ; then
    ln -snvf lib $SYSROOT_DIR/lib64
fi

step "[3/50] pkgconf 1.8.0"
extract $SOURCES_DIR/pkgconf-1.8.0.tar.xz $BUILD_DIR
( cd $BUILD_DIR/pkgconf-1.8.0 && \
    ./configure \
    --prefix=$TOOLS_DIR \
    --disable-static \
    --enable-shared \
    --disable-dependency-tracking )
make -j$PARALLEL_JOBS -C $BUILD_DIR/pkgconf-1.8.0
make -j$PARALLEL_JOBS install -C $BUILD_DIR/pkgconf-1.8.0
cat > $TOOLS_DIR/bin/pkg-config << "EOF"
#!/bin/sh
PKGCONFDIR=$(dirname $0)
DEFAULT_PKG_CONFIG_LIBDIR=${PKGCONFDIR}/../@STAGING_SUBDIR@/usr/lib/pkgconfig:${PKGCONFDIR}/../@STAGING_SUBDIR@/usr/share/pkgconfig
DEFAULT_PKG_CONFIG_SYSROOT_DIR=${PKGCONFDIR}/../@STAGING_SUBDIR@
DEFAULT_PKG_CONFIG_SYSTEM_INCLUDE_PATH=${PKGCONFDIR}/../@STAGING_SUBDIR@/usr/include
DEFAULT_PKG_CONFIG_SYSTEM_LIBRARY_PATH=${PKGCONFDIR}/../@STAGING_SUBDIR@/usr/lib
PKG_CONFIG_LIBDIR=${PKG_CONFIG_LIBDIR:-${DEFAULT_PKG_CONFIG_LIBDIR}} \
	PKG_CONFIG_SYSROOT_DIR=${PKG_CONFIG_SYSROOT_DIR:-${DEFAULT_PKG_CONFIG_SYSROOT_DIR}} \
	PKG_CONFIG_SYSTEM_INCLUDE_PATH=${PKG_CONFIG_SYSTEM_INCLUDE_PATH:-${DEFAULT_PKG_CONFIG_SYSTEM_INCLUDE_PATH}} \
	PKG_CONFIG_SYSTEM_LIBRARY_PATH=${PKG_CONFIG_SYSTEM_LIBRARY_PATH:-${DEFAULT_PKG_CONFIG_SYSTEM_LIBRARY_PATH}} \
	exec ${PKGCONFDIR}/pkgconf @STATIC@ "$@"
EOF
chmod 755 $TOOLS_DIR/bin/pkg-config
sed -i -e "s,@STAGING_SUBDIR@,$SYSROOT_DIR,g" $TOOLS_DIR/bin/pkg-config
sed -i -e "s,@STATIC@,," $TOOLS_DIR/bin/pkg-config
rm -rf $BUILD_DIR/pkgconf-1.8.0

step "[4/50] zlib 1.2.13"
extract $SOURCES_DIR/zlib-1.2.13.tar.xz $BUILD_DIR
( cd $BUILD_DIR/zlib-1.2.13 && ./configure --prefix=$TOOLS_DIR )
make -j1 -C $BUILD_DIR/zlib-1.2.13
make -j1 install -C $BUILD_DIR/zlib-1.2.13
rm -rf $BUILD_DIR/zlib-1.2.13

step "[5/50] util-linux 2.38.1"
extract $SOURCES_DIR/util-linux-2.38.1.tar.xz $BUILD_DIR
( cd $BUILD_DIR/util-linux-2.38.1 && \
    ./configure \
    --prefix=$TOOLS_DIR \
    --disable-static \
    --enable-shared \
    --without-systemd \
    --with-systemdsystemunitdir=no \
    --without-python \
    --enable-libblkid \
    --enable-libmount \
    --enable-libuuid \
    --without-libmagic \
    --without-ncurses \
    --without-ncursesw \
    --without-tinfo \
    --disable-raw \
    --disable-makeinstall-chown \
    --disable-agetty \
    --disable-chfn-chsh \
    --disable-chmem \
    --disable-ipcmk \
    --disable-login \
    --disable-lsfd \
    --disable-lslogins \
    --disable-mesg \
    --disable-more \
    --disable-newgrp \
    --disable-nologin \
    --disable-nsenter \
    --disable-pg \
    --disable-rfkill \
    --disable-runuser \
    --disable-schedutils \
    --disable-setpriv \
    --disable-setterm \
    --disable-su \
    --disable-sulogin \
    --disable-tunelp \
    --disable-ul \
    --disable-unshare \
    --disable-uuidd \
    --disable-vipw \
    --disable-wall \
    --disable-wdctl \
    --disable-write \
    --disable-zramctl )
make -j$PARALLEL_JOBS -C $BUILD_DIR/util-linux-2.38.1
make -j$PARALLEL_JOBS install -C $BUILD_DIR/util-linux-2.38.1
rm -rf $BUILD_DIR/util-linux-2.38.1

step "[6/50] e2fsprogs 1.46.5"
extract $SOURCES_DIR/e2fsprogs-1.46.5.tar.gz $BUILD_DIR
( cd $BUILD_DIR/e2fsprogs-1.46.5 && \
    ac_cv_path_LDCONFIG=true \
    ./configure \
    --prefix=$TOOLS_DIR \
    --disable-static \
    --enable-shared \
    --disable-defrag \
    --disable-e2initrd-helper \
    --disable-fuse2fs \
    --disable-fsck \
    --disable-libblkid \
    --disable-libuuid \
    --disable-testio-debug \
    --enable-symlink-install \
    --enable-elf-shlibs \
    --with-crond-dir=no \
    --with-udev-rules-dir=no \
    --with-systemd-unit-dir=no )
make -j$PARALLEL_JOBS -C $BUILD_DIR/e2fsprogs-1.46.5
make -j$PARALLEL_JOBS install -C $BUILD_DIR/e2fsprogs-1.46.5
rm -rf $BUILD_DIR/e2fsprogs-1.46.5

step "[7/50] attr 2.5.1"
extract $SOURCES_DIR/attr-2.5.1.tar.xz $BUILD_DIR
( cd $BUILD_DIR/attr-2.5.1 && \
    ./configure \
    --prefix=$TOOLS_DIR \
    --disable-static \
    --enable-shared )
make -j$PARALLEL_JOBS -C $BUILD_DIR/attr-2.5.1
make -j$PARALLEL_JOBS install -C $BUILD_DIR/attr-2.5.1
rm -rf $BUILD_DIR/attr-2.5.1

step "[8/50] acl 2.3.1"
extract $SOURCES_DIR/acl-2.3.1.tar.xz $BUILD_DIR
( cd $BUILD_DIR/acl-2.3.1 && \
    ./configure \
    --prefix=$TOOLS_DIR \
    --disable-static \
    --enable-shared )
make -j$PARALLEL_JOBS -C $BUILD_DIR/acl-2.3.1
make -j$PARALLEL_JOBS install -C $BUILD_DIR/acl-2.3.1
rm -rf $BUILD_DIR/acl-2.3.1

step "[9/50] fakeroot 1.30.1"
extract $SOURCES_DIR/fakeroot_1.30.1.orig.tar.gz $BUILD_DIR
( cd $BUILD_DIR/fakeroot-1.30.1 && \
    ac_cv_header_sys_capability_h=no \
    ac_cv_func_capset=no \
    ./configure \
    --prefix=$TOOLS_DIR \
    --disable-static \
    --enable-shared )
make -j$PARALLEL_JOBS -C $BUILD_DIR/fakeroot-1.30.1
make -j$PARALLEL_JOBS install -C $BUILD_DIR/fakeroot-1.30.1
rm -rf $BUILD_DIR/fakeroot-1.30.1

step "[10/50] makedevs"
gcc -O2 -I$TOOLS_DIR/include $SUPPORT_DIR/makedevs/makedevs.c -o $TOOLS_DIR/bin/makedevs -L$TOOLS_DIR/lib -Wl,-rpath,$TOOLS_DIR/lib

step "[11/50] mkpasswd"
gcc -O2 -I$TOOLS_DIR/include -L$TOOLS_DIR/lib -Wl,-rpath,$TOOLS_DIR/lib $SUPPORT_DIR/mkpasswd/mkpasswd.c $SUPPORT_DIR/mkpasswd/utils.c -o $TOOLS_DIR/bin/mkpasswd -lcrypt

step "[12/50] m4 1.4.19"
extract $SOURCES_DIR/m4-1.4.19.tar.xz $BUILD_DIR
( cd $BUILD_DIR/m4-1.4.19 && \
    ./configure \
    --prefix=$TOOLS_DIR \
    --disable-static \
    --enable-shared )
make -j$PARALLEL_JOBS -C $BUILD_DIR/m4-1.4.19
make -j$PARALLEL_JOBS install -C $BUILD_DIR/m4-1.4.19
rm -rf $BUILD_DIR/m4-1.4.19

step "[13/50] bison 3.8.2"
extract $SOURCES_DIR/bison-3.8.2.tar.xz $BUILD_DIR
( cd $BUILD_DIR/bison-3.8.2 && \
    ./configure \
    --prefix=$TOOLS_DIR \
    --disable-static \
    --enable-shared )
make -j$PARALLEL_JOBS -C $BUILD_DIR/bison-3.8.2
make -j$PARALLEL_JOBS install -C $BUILD_DIR/bison-3.8.2
rm -rf $BUILD_DIR/bison-3.8.2

step "[14/50] gawk 5.2.1"
extract $SOURCES_DIR/gawk-5.2.1.tar.xz $BUILD_DIR
( cd $BUILD_DIR/gawk-5.2.1 && \
    ./configure \
    --prefix=$TOOLS_DIR \
    --disable-static \
    --enable-shared \
    --without-readline \
    --without-mpfr )
make -j$PARALLEL_JOBS -C $BUILD_DIR/gawk-5.2.1
make -j$PARALLEL_JOBS install -C $BUILD_DIR/gawk-5.2.1
rm -rf $BUILD_DIR/gawk-5.2.1

step "[15/50] binutils 2.38"
extract $SOURCES_DIR/binutils-2.38.tar.xz $BUILD_DIR
mkdir -pv $BUILD_DIR/binutils-2.38/binutils-build
( cd $BUILD_DIR/binutils-2.38/binutils-build && \
    MAKEINFO=true \
    $BUILD_DIR/binutils-2.38/configure \
    --prefix=$TOOLS_DIR \
    --target=$CONFIG_TARGET \
    --build=$CONFIG_HOST \
    --host=$CONFIG_HOST \
    --disable-multilib \
    --disable-werror \
    --disable-shared \
    --enable-static \
    --with-sysroot=$SYSROOT_DIR \
    --enable-poison-system-directories \
    --without-debuginfod \
    --enable-plugins \
    --enable-lto \
    --disable-gprofng \
    --disable-sim \
    --disable-gdb )
make -j$PARALLEL_JOBS configure-host -C $BUILD_DIR/binutils-2.38/binutils-build
make -j$PARALLEL_JOBS -C $BUILD_DIR/binutils-2.38/binutils-build
make -j$PARALLEL_JOBS install -C $BUILD_DIR/binutils-2.38/binutils-build
rm -rf $BUILD_DIR/binutils-2.38

step "[16/50] gmp 6.2.1"
extract $SOURCES_DIR/gmp-6.2.1.tar.xz $BUILD_DIR
( cd $BUILD_DIR/gmp-6.2.1 && \
    ./configure \
    --prefix=$TOOLS_DIR \
    --disable-static \
    --enable-shared )
make -j$PARALLEL_JOBS -C $BUILD_DIR/gmp-6.2.1
make -j$PARALLEL_JOBS install -C $BUILD_DIR/gmp-6.2.1
rm -rf $BUILD_DIR/gmp-6.2.1

step "[17/50] mpfr 4.1.0"
extract $SOURCES_DIR/mpfr-4.1.0.tar.xz $BUILD_DIR
( cd $BUILD_DIR/mpfr-4.1.0 && \
    ./configure \
    --prefix=$TOOLS_DIR \
    --disable-static \
    --enable-shared )
make -j$PARALLEL_JOBS -C $BUILD_DIR/mpfr-4.1.0
make -j$PARALLEL_JOBS install -C $BUILD_DIR/mpfr-4.1.0
rm -rf $BUILD_DIR/mpfr-4.1.0

step "[18/50] mpc 1.2.1"
extract $SOURCES_DIR/mpc-1.2.1.tar.gz $BUILD_DIR
( cd $BUILD_DIR/mpc-1.2.1 && \
    ./configure \
    --prefix=$TOOLS_DIR \
    --disable-static \
    --enable-shared )
make -j$PARALLEL_JOBS -C $BUILD_DIR/mpc-1.2.1
make -j$PARALLEL_JOBS install -C $BUILD_DIR/mpc-1.2.1
rm -rf $BUILD_DIR/mpc-1.2.1

step "[19/50] gcc 12.2.0 - Static"
extract $SOURCES_DIR/gcc-12.2.0.tar.xz $BUILD_DIR
mkdir -pv $BUILD_DIR/gcc-12.2.0/gcc-build
( cd $BUILD_DIR/gcc-12.2.0/gcc-build && \
    MAKEINFO=true \
    CFLAGS_FOR_TARGET="-D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64 -Os" \
    CXXFLAGS_FOR_TARGET="-D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64 -Os" \
    $BUILD_DIR/gcc-12.2.0/configure \
    --prefix=$TOOLS_DIR \
    --target=$CONFIG_TARGET \
    --build=$CONFIG_HOST \
    --host=$CONFIG_HOST \
    --with-sysroot=$SYSROOT_DIR \
    --enable-__cxa_atexit \
    --with-gnu-ld \
    --disable-libssp \
    --disable-multilib \
    --disable-decimal-float \
    --enable-plugins \
    --enable-lto \
    --with-gmp=$TOOLS_DIR \
    --with-mpc=$TOOLS_DIR \
    --with-mpfr=$TOOLS_DIR \
    --without-zstd \
    --enable-libquadmath \
    --enable-libquadmath-support \
    --enable-tls \
    --enable-threads \
    --without-isl \
    --without-cloog \
    --with-arch="$CONFIG_GCC_ARCH" \
    --enable-languages=c \
    --disable-shared \
    --without-headers \
    --disable-threads \
    --with-newlib \
    --disable-largefile \
    --with-bugurl="$CONFIG_BUG_URL" \
    --with-pkgversion="$CONFIG_PKG_VERSION" )
make -j1 gcc_cv_libc_provides_ssp=yes all-gcc all-target-libgcc -C $BUILD_DIR/gcc-12.2.0/gcc-build
make -j$PARALLEL_JOBS install-gcc install-target-libgcc -C $BUILD_DIR/gcc-12.2.0/gcc-build
rm -rf $BUILD_DIR/gcc-12.2.0

step "[20/50] Linux 5.15.82 API Headers"
extract $SOURCES_DIR/linux-5.15.82.tar.xz $BUILD_DIR
make -j$PARALLEL_JOBS ARCH=$CONFIG_LINUX_ARCH mrproper -C $BUILD_DIR/linux-5.15.82
make -j$PARALLEL_JOBS ARCH=$CONFIG_LINUX_ARCH headers_check -C $BUILD_DIR/linux-5.15.82
make -j$PARALLEL_JOBS ARCH=$CONFIG_LINUX_ARCH INSTALL_HDR_PATH=$SYSROOT_DIR headers_install -C $BUILD_DIR/linux-5.15.82
rm -rf $BUILD_DIR/linux-5.15.82

step "[21/50] glibc 2.36"
extract $SOURCES_DIR/glibc-2.36.tar.xz $BUILD_DIR
mkdir $BUILD_DIR/glibc-2.36/glibc-build
( cd $BUILD_DIR/glibc-2.36/glibc-build && \
    CC="$TOOLS_DIR/bin/$CONFIG_TARGET-gcc" \
    CXX="$TOOLS_DIR/bin/$CONFIG_TARGET-g++" \
    AR="$TOOLS_DIR/bin/$CONFIG_TARGET-ar" \
    AS="$TOOLS_DIR/bin/$CONFIG_TARGET-as" \
    LD="$TOOLS_DIR/bin/$CONFIG_TARGET-ld" \
    RANLIB="$TOOLS_DIR/bin/$CONFIG_TARGET-ranlib" \
    READELF="$TOOLS_DIR/bin/$CONFIG_TARGET-readelf" \
    STRIP="$TOOLS_DIR/bin/$CONFIG_TARGET-strip" \
    CFLAGS="-O2 " CPPFLAGS="" CXXFLAGS="-O2 " LDFLAGS="" \
    ac_cv_path_BASH_SHELL=/bin/sh \
    libc_cv_forced_unwind=yes \
    libc_cv_ssp=no \
    $BUILD_DIR/glibc-2.36/configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST \
    --prefix=/usr \
    --enable-shared \
    --enable-lock-elision \
    --with-pkgversion="$CONFIG_PKG_VERSION" \
    --disable-profile \
    --disable-werror \
    --without-gd \
    --enable-kernel=5.15 \
    --with-headers=$SYSROOT_DIR/usr/include )
make -j$PARALLEL_JOBS -C $BUILD_DIR/glibc-2.36/glibc-build
make -j$PARALLEL_JOBS install_root=$SYSROOT_DIR install -C $BUILD_DIR/glibc-2.36/glibc-build
rm -rf $BUILD_DIR/glibc-2.36

step "[22/50] gcc 12.2.0 - Final"
extract $SOURCES_DIR/gcc-12.2.0.tar.xz $BUILD_DIR
mkdir -v $BUILD_DIR/gcc-12.2.0/gcc-build
( cd $BUILD_DIR/gcc-12.2.0/gcc-build && \
    MAKEINFO=true \
    CFLAGS_FOR_TARGET="-D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64 -Os" \
    CXXFLAGS_FOR_TARGET="-D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64 -Os" \
    $BUILD_DIR/gcc-12.2.0/configure \
    --prefix=$TOOLS_DIR \
    --build=$CONFIG_HOST \
    --host=$CONFIG_HOST \
    --target=$CONFIG_TARGET \
    --with-sysroot=$SYSROOT_DIR \
    --enable-static \
    --enable-__cxa_atexit \
    --with-gnu-ld \
    --disable-libssp \
    --disable-multilib \
    --disable-decimal-float \
    --enable-plugins \
    --enable-lto \
    --with-gmp=$TOOLS_DIR \
    --with-mpc=$TOOLS_DIR \
    --with-mpfr=$TOOLS_DIR \
    --with-bugurl="$CONFIG_BUG_URL" \
    --with-pkgversion="$CONFIG_PKG_VERSION" \
    --without-zstd \
    --enable-libquadmath \
    --enable-libquadmath-support \
    --enable-tls \
    --enable-threads \
    --without-isl \
    --without-cloog \
    --with-arch="$CONFIG_GCC_ARCH" \
    --enable-languages=c,c++ \
    --with-build-time-tools=$TOOLS_DIR/$CONFIG_TARGET/bin \
    --enable-shared \
    --disable-libgomp )
make -j$PARALLEL_JOBS gcc_cv_libc_provides_ssp=yes -C $BUILD_DIR/gcc-12.2.0/gcc-build
make -j$PARALLEL_JOBS install -C $BUILD_DIR/gcc-12.2.0/gcc-build
for libstdc in libstdc++ ; do
    cp -dpvf $TOOLS_DIR/$CONFIG_TARGET/lib*/$libstdc.a $SYSROOT_DIR/usr/lib/ ;
done
for libstdc in libstdc++ ; do
    cp -dpvf $TOOLS_DIR/$CONFIG_TARGET/lib*/$libstdc.so* $SYSROOT_DIR/usr/lib/ ;
done
if [ ! -e $TOOLS_DIR/bin/$CONFIG_TARGET-cc ]; then
    ln -vf $TOOLS_DIR/bin/$CONFIG_TARGET-gcc $TOOLS_DIR/bin/$CONFIG_TARGET-cc
fi
rm -rf $BUILD_DIR/gcc-12.2.0

step "[23/50] ncurses 6.3"
extract $SOURCES_DIR/ncurses-6.3.tar.gz $BUILD_DIR
( cd $BUILD_DIR/ncurses-6.3 && \
    ./configure \
    --prefix=$TOOLS_DIR \
    --disable-static \
    --enable-shared \
    --with-shared \
    --without-gpm \
    --without-manpages \
    --without-cxx \
    --without-cxx-binding \
    --without-ada \
    --with-default-terminfo-dir=/usr/share/terminfo \
    --disable-db-install \
    --without-normal )
make -j$PARALLEL_JOBS -C $BUILD_DIR/ncurses-6.3
make -j$PARALLEL_JOBS install -C $BUILD_DIR/ncurses-6.3
rm -rf $BUILD_DIR/ncurses-6.3

step "[24/50] libtool 2.4.7"
extract $SOURCES_DIR/libtool-2.4.7.tar.xz $BUILD_DIR
( cd $BUILD_DIR/libtool-2.4.7 && \
    ./configure \
    --prefix=$TOOLS_DIR \
    --disable-static \
    --enable-shared )
make -j$PARALLEL_JOBS -C $BUILD_DIR/libtool-2.4.7
make -j$PARALLEL_JOBS install -C $BUILD_DIR/libtool-2.4.7
rm -rf $BUILD_DIR/libtool-2.4.7

step "[25/50] autoconf 2.71"
extract $SOURCES_DIR/autoconf-2.71.tar.xz $BUILD_DIR
( cd $BUILD_DIR/autoconf-2.71 && \
    ./configure \
    --prefix=$TOOLS_DIR \
    --disable-static \
    --enable-shared )
make -j$PARALLEL_JOBS -C $BUILD_DIR/autoconf-2.71
make -j$PARALLEL_JOBS install -C $BUILD_DIR/autoconf-2.71
rm -rf $BUILD_DIR/autoconf-2.71

step "[26/50] gperf 3.1"
extract $SOURCES_DIR/gperf-3.1.tar.gz $BUILD_DIR
( cd $BUILD_DIR/gperf-3.1 && \
    ./configure \
    --prefix=$TOOLS_DIR \
    --disable-static \
    --enable-shared )
make -j$PARALLEL_JOBS -C $BUILD_DIR/gperf-3.1
make -j$PARALLEL_JOBS install -C $BUILD_DIR/gperf-3.1
rm -rf $BUILD_DIR/gperf-3.1

step "[27/50] ninja 1.11.1"
extract $SOURCES_DIR/v1.11.1.tar.gz $BUILD_DIR
( cd $BUILD_DIR/ninja-1.11.1 && \
cmake $BUILD_DIR/ninja-1.11.1 \
-G"Unix Makefiles" \
-DCMAKE_INSTALL_SO_NO_EXE=0 \
-DCMAKE_FIND_ROOT_PATH="$TOOLS_DIR" \
-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM="BOTH" \
-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY="BOTH" \
-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE="BOTH" \
-DCMAKE_INSTALL_PREFIX="$TOOLS_DIR" \
-DCMAKE_C_FLAGS="-O2 -I$TOOLS_DIR/include" \
-DCMAKE_CXX_FLAGS="-O2 -I$TOOLS_DIR/include" \
-DCMAKE_EXE_LINKER_FLAGS="-L$TOOLS_DIR/lib -Wl,-rpath,$TOOLS_DIR/lib" \
-DCMAKE_SHARED_LINKER_FLAGS="-L$TOOLS_DIR/lib -Wl,-rpath,$TOOLS_DIR/lib" \
-DCMAKE_ASM_COMPILER="/usr/bin/as" \
-DCMAKE_C_COMPILER="gcc" \
-DCMAKE_CXX_COMPILER="g++" \
-DCMAKE_C_COMPILER_LAUNCHER="" \
-DCMAKE_CXX_COMPILER_LAUNCHER="" \
-DCMAKE_COLOR_MAKEFILE=OFF \
-DBUILD_DOC=OFF \
-DBUILD_DOCS=OFF \
-DBUILD_EXAMPLE=OFF \
-DBUILD_EXAMPLES=OFF \
-DBUILD_TEST=OFF \
-DBUILD_TESTS=OFF \
-DBUILD_TESTING=OFF \
-DBUILD_SHARED_LIBS=ON )
make -j$PARALLEL_JOBS -C $BUILD_DIR/ninja-1.11.1
install -m 0755 -D $BUILD_DIR/ninja-1.11.1/ninja $TOOLS_DIR/bin/ninja
rm -rf $BUILD_DIR/ninja-1.11.1

step "[28/50] automake 1.16.5"
extract $SOURCES_DIR/automake-1.16.5.tar.xz $BUILD_DIR
( cd $BUILD_DIR/automake-1.16.5 && \
    ./configure \
    --prefix=$TOOLS_DIR \
    --disable-static \
    --enable-shared )
make -j$PARALLEL_JOBS -C $BUILD_DIR/automake-1.16.5
make -j$PARALLEL_JOBS install -C $BUILD_DIR/automake-1.16.5
mkdir -p $SYSROOT_DIR/usr/share/aclocal
rm -rf $BUILD_DIR/automake-1.16.5

step "[29/50] expat 2.5.0"
extract $SOURCES_DIR/expat-2.5.0.tar.xz $BUILD_DIR
( cd $BUILD_DIR/expat-2.5.0 && \
    ./configure \
    --prefix=$TOOLS_DIR \
    --disable-static \
    --enable-shared \
    --without-docbook \
    --without-examples \
    --without-tests )
make -j$PARALLEL_JOBS -C $BUILD_DIR/expat-2.5.0
make -j$PARALLEL_JOBS install -C $BUILD_DIR/expat-2.5.0
rm -rf $BUILD_DIR/expat-2.5.0

step "[30/50] libffi 3.4.4"
extract $SOURCES_DIR/libffi-3.4.4.tar.gz $BUILD_DIR
( cd $BUILD_DIR/libffi-3.4.4 && \
    ./configure \
    --prefix=$TOOLS_DIR \
    --disable-static \
    --enable-shared )
make -j$PARALLEL_JOBS -C $BUILD_DIR/libffi-3.4.4
make -j$PARALLEL_JOBS install -C $BUILD_DIR/libffi-3.4.4
rm -rf $BUILD_DIR/libffi-3.4.4

step "[31/50] Python 3.11.1"
extract $SOURCES_DIR/Python-3.11.1.tar.xz $BUILD_DIR
( cd $BUILD_DIR/Python-3.11.1 && \
    ./configure \
    --prefix=$TOOLS_DIR \
    --disable-static \
    --enable-shared \
    --without-ensurepip \
    --without-cxx-main \
    --disable-sqlite3 \
    --disable-tk \
    --with-system-expat \
    --with-system-ffi \
    --disable-curses \
    --disable-codecs-cjk \
    --disable-nis \
    --enable-unicodedata \
    --disable-test-modules \
    --disable-idle3 \
    --disable-ossaudiodev \
    --disable-bzip2 \
    --disable-openssl )
make -j$PARALLEL_JOBS -C $BUILD_DIR/Python-3.11.1
make -j$PARALLEL_JOBS install -C $BUILD_DIR/Python-3.11.1
ln -svf python3 $TOOLS_DIR/bin/python
rm -rf $BUILD_DIR/Python-3.11.1

step "[32/50] Python setuptools 65.5.0"
extract $SOURCES_DIR/setuptools-65.5.0.tar.gz $BUILD_DIR
( cd $BUILD_DIR/setuptools-65.5.0 && \
    PYTHONNOUSERSITE=1 \
    SETUPTOOLS_USE_DISTUTILS=stdlib \
    $TOOLS_DIR/bin/python \
    setup.py \
    build )
( cd $BUILD_DIR/setuptools-65.5.0 && \
    PYTHONNOUSERSITE=1 \
    SETUPTOOLS_USE_DISTUTILS=stdlib \
    $TOOLS_DIR/bin/python \
    setup.py \
    install \
    --prefix=$TOOLS_DIR \
    --root=/ \
    --single-version-externally-managed )
rm -rf $BUILD_DIR/setuptools-65.5.0

step "[33/50] meson 1.0.0"
extract $SOURCES_DIR/meson-1.0.0.tar.gz $BUILD_DIR
( cd $BUILD_DIR/meson-1.0.0 && \
    PYTHONNOUSERSITE=1 \
    SETUPTOOLS_USE_DISTUTILS=stdlib \
    $TOOLS_DIR/bin/python \
    setup.py \
    build )
( cd $BUILD_DIR/meson-1.0.0 && \
    PYTHONNOUSERSITE=1 \
    SETUPTOOLS_USE_DISTUTILS=stdlib \
    $TOOLS_DIR/bin/python \
    setup.py \
    install \
    --prefix=$TOOLS_DIR \
    --root=/ \
    --single-version-externally-managed )
rm -rf $BUILD_DIR/meson-1.0.0

step "[34/50] Python MarkupSafe 2.0.1"
extract $SOURCES_DIR/MarkupSafe-2.0.1.tar.gz $BUILD_DIR
( cd $BUILD_DIR/MarkupSafe-2.0.1 && \
    PYTHONNOUSERSITE=1 \
    SETUPTOOLS_USE_DISTUTILS=stdlib \
    $TOOLS_DIR/bin/python \
    setup.py \
    build )
( cd $BUILD_DIR/MarkupSafe-2.0.1 && \
    PYTHONNOUSERSITE=1 \
    SETUPTOOLS_USE_DISTUTILS=stdlib \
    $TOOLS_DIR/bin/python \
    setup.py \
    install \
    --prefix=$TOOLS_DIR \
    --root=/ \
    --single-version-externally-managed )
rm -rf $BUILD_DIR/MarkupSafe-2.0.1

step "[35/50] Python Jinja2 3.1.2"
extract $SOURCES_DIR/Jinja2-3.1.2.tar.gz $BUILD_DIR
( cd $BUILD_DIR/Jinja2-3.1.2 && \
    PYTHONNOUSERSITE=1 \
    SETUPTOOLS_USE_DISTUTILS=stdlib \
    $TOOLS_DIR/bin/python \
    setup.py \
    build )
( cd $BUILD_DIR/Jinja2-3.1.2 && \
    PYTHONNOUSERSITE=1 \
    SETUPTOOLS_USE_DISTUTILS=stdlib \
    $TOOLS_DIR/bin/python \
    setup.py \
    install \
    --prefix=$TOOLS_DIR \
    --root=/ \
    --single-version-externally-managed )
rm -rf $BUILD_DIR/Jinja2-3.1.2

step "[36/50] kmod 30"
extract $SOURCES_DIR/kmod-30.tar.xz $BUILD_DIR
( cd $BUILD_DIR/kmod-30 && \
    ./configure \
    --prefix=$TOOLS_DIR \
    --disable-static \
    --enable-shared \
    --disable-manpages \
    --without-zlib \
    --without-zstd \
    --without-xz )
make -j$PARALLEL_JOBS -C $BUILD_DIR/kmod-30
make -j$PARALLEL_JOBS install -C $BUILD_DIR/kmod-30
rm -rf $BUILD_DIR/kmod-30

step "[37/50] patchelf 0.17.0"
extract $SOURCES_DIR/patchelf-0.17.0.tar.bz2 $BUILD_DIR
( cd $BUILD_DIR/patchelf-0.17.0 && \
    ./configure \
    --prefix=$TOOLS_DIR \
    --disable-static \
    --enable-shared )
make -j$PARALLEL_JOBS -C $BUILD_DIR/patchelf-0.17.0
make -j$PARALLEL_JOBS install -C $BUILD_DIR/patchelf-0.17.0
rm -rf $BUILD_DIR/patchelf-0.17.0

step "[38/50] gettext 0.21.1"
extract $SOURCES_DIR/gettext-0.21.1.tar.xz $BUILD_DIR
( cd $BUILD_DIR/gettext-0.21.1 && \
    ./configure \
    --prefix=$TOOLS_DIR \
    --disable-static \
    --enable-shared )
make -j$PARALLEL_JOBS -C $BUILD_DIR/gettext-0.21.1
make -j$PARALLEL_JOBS install -C $BUILD_DIR/gettext-0.21.1
rm -rf $BUILD_DIR/gettext-0.21.1

step "[39/50] flex 2.6.4"
extract $SOURCES_DIR/flex-2.6.4.tar.gz $BUILD_DIR
( cd $BUILD_DIR/flex-2.6.4 && \
    ./configure \
    --prefix=$TOOLS_DIR \
    --disable-static \
    --enable-shared \
    --disable-doc )
make -j$PARALLEL_JOBS -C $BUILD_DIR/flex-2.6.4
make -j$PARALLEL_JOBS install -C $BUILD_DIR/flex-2.6.4
rm -rf $BUILD_DIR/flex-2.6.4

step "[40/50] dtc 1.6.1"
extract $SOURCES_DIR/dtc-1.6.1.tar.xz $BUILD_DIR
make -j$PARALLEL_JOBS EXTRA_CFLAGS="-O2 -I$TOOLS_DIR/include -fPIC" -C $BUILD_DIR/dtc-1.6.1 PREFIX=$TOOLS_DIR INCLUDEDIR=$TOOLS_DIR/include/libfdt NO_PYTHON=1 NO_VALGRIND=1 NO_YAML=1
make -j$PARALLEL_JOBS EXTRA_CFLAGS="-O2 -I$TOOLS_DIR/include -fPIC" -C $BUILD_DIR/dtc-1.6.1 PREFIX=$TOOLS_DIR INCLUDEDIR=$TOOLS_DIR/include/libfdt NO_PYTHON=1 NO_VALGRIND=1 NO_YAML=1 install
rm -rf $BUILD_DIR/dtc-1.6.1

step "[41/50] pcre 8.45"
extract $SOURCES_DIR/pcre-8.45.tar.bz2 $BUILD_DIR
( cd $BUILD_DIR/pcre-8.45 && \
    ./configure \
    --prefix=$TOOLS_DIR \
    --disable-static \
    --enable-shared \
    --enable-unicode-properties )
make -j$PARALLEL_JOBS -C $BUILD_DIR/pcre-8.45
make -j$PARALLEL_JOBS install -C $BUILD_DIR/pcre-8.45
rm -rf $BUILD_DIR/pcre-8.45

step "[42/50] glib 2.72.3"
extract $SOURCES_DIR/glib-2.72.3.tar.xz $BUILD_DIR
mkdir -pv $BUILD_DIR/glib-2.72.3/build
PYTHONNOUSERSITE=y \
$TOOLS_DIR/bin/meson \
--prefix=$TOOLS_DIR \
--libdir=lib \
--sysconfdir=$TOOLS_DIR/etc \
--localstatedir=$TOOLS_DIR/var \
--default-library=shared \
--buildtype=release \
--wrap-mode=nodownload \
-Dstrip=true \
-Ddtrace=false \
-Dfam=false \
-Dglib_debug=disabled \
-Dlibelf=disabled \
-Dselinux=disabled \
-Dsystemtap=false \
-Dxattr=false \
-Dtests=false \
-Doss_fuzz=disabled \
$BUILD_DIR/glib-2.72.3 $BUILD_DIR/glib-2.72.3/build
PYTHONNOUSERSITE=y $TOOLS_DIR/bin/ninja -C $BUILD_DIR/glib-2.72.3/build
PYTHONNOUSERSITE=y $TOOLS_DIR/bin/ninja -C $BUILD_DIR/glib-2.72.3/build install
rm -rf $BUILD_DIR/glib-2.72.3

step "[43/50] libcap 2.66"
extract $SOURCES_DIR/libcap-2.66.tar.xz $BUILD_DIR
make -j$PARALLEL_JOBS -C $BUILD_DIR/libcap-2.66
make -j$PARALLEL_JOBS prefix=$TOOLS_DIR RAISE_SETFCAP=no install -C $BUILD_DIR/libcap-2.66
rm -rf $BUILD_DIR/libcap-2.66

step "[44/50] systemd v252"
extract $SOURCES_DIR/v252.tar.gz $BUILD_DIR
mkdir -pv $BUILD_DIR/systemd-252/build
PYTHONNOUSERSITE=y \
$TOOLS_DIR/bin/meson \
--default-library=shared \
--buildtype=release \
--wrap-mode=nodownload \
-Dstrip=true \
-Dsplit-bin=true \
-Dsplit-usr=false \
--prefix=/usr \
--libdir=lib \
--sysconfdir=/etc \
--localstatedir=/var \
-Dmode=release \
-Dutmp=false \
-Dhibernate=false \
-Dldconfig=false \
-Dresolve=false \
-Defi=false \
-Dtpm=false \
-Denvironment-d=false \
-Dbinfmt=false \
-Drepart=false \
-Dcoredump=false \
-Dpstore=false \
-Doomd=false \
-Dlogind=false \
-Dhostnamed=false \
-Dlocaled=false \
-Dmachined=false \
-Dportabled=false \
-Dsysext=false \
-Duserdb=false \
-Dhomed=false \
-Dnetworkd=false \
-Dtimedated=false \
-Dtimesyncd=false \
-Dremote=false \
-Dcreate-log-dirs=false \
-Dnss-myhostname=false \
-Dnss-mymachines=false \
-Dnss-resolve=false \
-Dnss-systemd=false \
-Dfirstboot=false \
-Drandomseed=false \
-Dbacklight=false \
-Dvconsole=false \
-Dquotacheck=false \
-Dsysusers=false \
-Dtmpfiles=true \
-Dimportd=false \
-Dhwdb=true \
-Drfkill=false \
-Dman=false \
-Dhtml=false \
-Dsmack=false \
-Dpolkit=false \
-Dblkid=false \
-Didn=false \
-Dadm-group=false \
-Dwheel-group=false \
-Dzlib=false \
-Dgshadow=false \
-Dima=false \
-Dtests=false \
-Dglib=false \
-Dacl=false \
-Dsysvinit-path='' \
-Dinitrd=false \
-Dxdg-autostart=false \
-Dkernel-install=false \
-Danalyze=false \
-Dlibcryptsetup=false \
-Daudit=false \
-Dzstd=false \
$BUILD_DIR/systemd-252 $BUILD_DIR/systemd-252/build
PYTHONNOUSERSITE=y $TOOLS_DIR/bin/ninja -C $BUILD_DIR/systemd-252/build
DESTDIR=$TOOLS_DIR PYTHONNOUSERSITE=y $TOOLS_DIR/bin/ninja -C $BUILD_DIR/systemd-252/build install
ln -svf systemd/libsystemd-shared-252.so $TOOLS_DIR/lib/libsystemd-shared-252.so
rm -rf $BUILD_DIR/systemd-252

step "[45/50] zic 2022g"
mkdir -pv $BUILD_DIR/tzcode2022g
extract $SOURCES_DIR/tzcode2022g.tar.gz $BUILD_DIR/tzcode2022g
make -j$PARALLEL_JOBS VERSION_DEPS= -C $BUILD_DIR/tzcode2022g zic
install -D -m 755 $BUILD_DIR/tzcode2022g/zic $TOOLS_DIR/sbin/zic
install -D -m 644 $BUILD_DIR/tzcode2022g/tzfile.h $TOOLS_DIR/include/tzfile.h
rm -rf $BUILD_DIR/tzcode2022g

step "[46/50] tzdata 2022g"
mkdir -pv $BUILD_DIR/tzdata2022g
extract $SOURCES_DIR/tzdata2022g.tar.gz $BUILD_DIR/tzdata2022g
( cd $BUILD_DIR/tzdata2022g && \
    for zone in africa antarctica asia australasia europe northamerica southamerica etcetera backward factory; \
        do $TOOLS_DIR/sbin/zic -b fat -d _output/posix $zone || exit 1; \
        $TOOLS_DIR/sbin/zic -b fat -d _output/right -L leapseconds $zone || exit 1; \
    done; )
install -d -m 0755 $TOOLS_DIR/share/zoneinfo
cp -a $BUILD_DIR/tzdata2022g/_output/* $BUILD_DIR/tzdata2022g/*.tab $BUILD_DIR/tzdata2022g/leap-seconds.list $TOOLS_DIR/share/zoneinfo

step "[47/50] bzip2 1.0.8"
extract $SOURCES_DIR/bzip2-1.0.8.tar.gz $BUILD_DIR
make -j$PARALLEL_JOBS -C $BUILD_DIR/bzip2-1.0.8 -f Makefile-libbz2_so
make -j$PARALLEL_JOBS PREFIX=$TOOLS_DIR -C $BUILD_DIR/bzip2-1.0.8 install
rm -rf $BUILD_DIR/bzip2-1.0.8

step "[48/50] xz 5.4.0"
extract $SOURCES_DIR/xz-5.4.0.tar.bz2 $BUILD_DIR
( cd $BUILD_DIR/xz-5.4.0 && \
    ./configure \
    --prefix=$TOOLS_DIR \
    --disable-static \
    --enable-shared )
make -j$PARALLEL_JOBS -C $BUILD_DIR/xz-5.4.0
make -j$PARALLEL_JOBS install -C $BUILD_DIR/xz-5.4.0
rm -rf $BUILD_DIR/xz-5.4.0

step "[49/50] elfutils 0.188"
extract $SOURCES_DIR/elfutils-0.188.tar.bz2 $BUILD_DIR
( cd $BUILD_DIR/elfutils-0.188 && \
    ./configure \
    --prefix=$TOOLS_DIR \
    --disable-static \
    --enable-shared \
    --with-bzlib \
    --with-lzma \
    --without-zstd \
    --disable-progs \
    --disable-libdebuginfod \
    --disable-debuginfod )
make -j$PARALLEL_JOBS -C $BUILD_DIR/elfutils-0.188
make -j$PARALLEL_JOBS install -C $BUILD_DIR/elfutils-0.188
rm -rf $BUILD_DIR/elfutils-0.188

step "[50/50] openssl 1.1.1s"
extract $SOURCES_DIR/openssl-1.1.1s.tar.gz $BUILD_DIR
( cd $BUILD_DIR/openssl-1.1.1s && \
    ./config \
    --prefix=$TOOLS_DIR \
    --openssldir=$TOOLS_DIR/etc/ssl \
    --libdir=lib \
    no-tests \
    no-fuzz-libfuzzer \
    no-fuzz-afl \
    shared \
    zlib-dynamic )
make -j$PARALLEL_JOBS -C $BUILD_DIR/openssl-1.1.1s
make -j$PARALLEL_JOBS install -C $BUILD_DIR/openssl-1.1.1s
rm -rf $BUILD_DIR/openssl-1.1.1s

do_strip

success "\nTotal toolchain build time: $(timer $total_build_time)\n"