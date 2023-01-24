#!/bin/bash
#
# Root file system build script
# Optional parameteres below:
set -o nounset
set -o errexit

export LC_ALL=POSIX
export CONFIG_HOST=$(echo ${MACHTYPE} | sed -e 's/-[^-]*/-cross/')

export CC="$TOOLS_DIR/bin/$CONFIG_TARGET-gcc"
export CXX="$TOOLS_DIR/bin/$CONFIG_TARGET-g++"
export AR="$TOOLS_DIR/bin/$CONFIG_TARGET-ar"
export AS="$TOOLS_DIR/bin/$CONFIG_TARGET-as"
export LD="$TOOLS_DIR/bin/$CONFIG_TARGET-ld"
export RANLIB="$TOOLS_DIR/bin/$CONFIG_TARGET-ranlib"
export READELF="$TOOLS_DIR/bin/$CONFIG_TARGET-readelf"
export STRIP="$TOOLS_DIR/bin/$CONFIG_TARGET-strip"
export PATH="$TOOLS_DIR/bin:$TOOLS_DIR/sbin:$PATH"

export PKG_CONFIG="$TOOLS_DIR/bin/pkg-config"
export PKG_CONFIG_SYSROOT_DIR="/"
export PKG_CONFIG_LIBDIR="$TOOLS_DIR/lib/pkgconfig:$TOOLS_DIR/share/pkgconfig"
export PKG_CONFIG_ALLOW_SYSTEM_CFLAGS=1
export PKG_CONFIG_ALLOW_SYSTEM_LIBS=1

CONFIG_PKG_VERSION="Systemd Minimal Linux for x86_64 2023.01"
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
		bash-5.2.15.tar.gz
		coreutils-9.1.tar.xz
		dbus-1.14.4.tar.xz
		expat-2.5.0.tar.xz
		glibc-2.36.tar.xz
		iana-etc-20221220.tar.gz
		kmod-30.tar.xz
		libcap-2.66.tar.xz
		ncurses-6.3.tar.gz
		readline-8.2.tar.gz
		util-linux-2.38.1.tar.xz
		v252.tar.gz
    "

	for tarball in $LIST_OF_TARBALLS; do
		if ! [[ -f $SOURCES_DIR/$tarball ]]; then
			error "Can't find '$tarball'!"
			exit 1
		fi
	done
}

function do_strip() {
	set +o errexit
	if [[ $CONFIG_STRIP_AND_DELETE_DOCS = 1 ]]; then
		$STRIP --strip-debug $ROOTFS_DIR/lib/*
		$STRIP --strip-unneeded $ROOTFS_DIR/{,s}bin/*
		rm -rf $ROOTFS_DIR/{,share}/{info,man,doc}
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
check_tarballs
total_build_time=$(timer)

step "[1/16] Create root file system directory."
rm -rf $BUILD_DIR $ROOTFS_DIR
mkdir -pv $BUILD_DIR $ROOTFS_DIR
mkdir -pv $ROOTFS_DIR/{dev,etc,home,media,mnt,opt,proc,root,run,srv,sys,tmp,usr,var}
ln -svnf ../proc/self/fd $ROOTFS_DIR/dev/fd
ln -svnf ../proc/self/fd/2 $ROOTFS_DIR/dev/stderr
ln -svnf ../proc/self/fd/0 $ROOTFS_DIR/dev/stdin
ln -svnf ../proc/self/fd/1 $ROOTFS_DIR/dev/stdout
echo "/dev/root / auto rw 0 1" >$ROOTFS_DIR/etc/fstab
echo "Welcome to Systemd Minimal Linux" >$ROOTFS_DIR/etc/issue
cat >$ROOTFS_DIR/etc/profile <<"EOF"
export PATH=@PATH@

if [ "$PS1" ]; then
	if [ "`id -u`" -eq 0 ]; then
		export PS1='# '
	else
		export PS1='$ '
	fi
fi

export EDITOR='/bin/vi'

# Source configuration files from /etc/profile.d
for i in /etc/profile.d/*.sh ; do
	if [ -r "$i" ]; then
		. $i
	fi
done
unset i
EOF
sed -i -e 's,@PATH@,"/bin:/sbin:/usr/bin:/usr/sbin",' $ROOTFS_DIR/etc/profile
mkdir -pv $ROOTFS_DIR/etc/profile.d
echo "umask 022" >$ROOTFS_DIR/etc/profile.d/umask.sh
echo "127.0.0.1	$CONFIG_HOSTNAME" >$ROOTFS_DIR/etc/hosts
echo "$CONFIG_HOSTNAME" >$ROOTFS_DIR/etc/hostname
ln -svnf ../proc/self/mounts $ROOTFS_DIR/etc/mtab
# Create /etc/passwd
cat >$ROOTFS_DIR/etc/passwd <<"EOF"
root:x:0:0:root:/root:/bin/sh
daemon:x:1:1:daemon:/usr/sbin:/bin/false
bin:x:2:2:bin:/bin:/bin/false
sys:x:3:3:sys:/dev:/bin/false
sync:x:4:100:sync:/bin:/bin/sync
mail:x:8:8:mail:/var/spool/mail:/bin/false
www-data:x:33:33:www-data:/var/www:/bin/false
operator:x:37:37:Operator:/var:/bin/false
nobody:x:65534:65534:nobody:/home:/bin/false
EOF
# Create /etc/shadow
cat >$ROOTFS_DIR/etc/shadow <<"EOF"
root::::::::
daemon:*:::::::
bin:*:::::::
sys:*:::::::
sync:*:::::::
mail:*:::::::
www-data:*:::::::
operator:*:::::::
nobody:*:::::::
EOF
sed -i -e s,^root:[^:]*:,root:"$($TOOLS_DIR/bin/mkpasswd -m "sha-512" "$CONFIG_ROOT_PASSWORD")":, $ROOTFS_DIR/etc/shadow
# Create /etc/group
cat >$ROOTFS_DIR/etc/group <<"EOF"
root:x:0:
daemon:x:1:
bin:x:2:
sys:x:3:
adm:x:4:
tty:x:5:
disk:x:6:
lp:x:7:
mail:x:8:
kmem:x:9:
wheel:x:10:root
cdrom:x:11:
dialout:x:18:
floppy:x:19:
video:x:28:
audio:x:29:
tape:x:32:
www-data:x:33:
operator:x:37:
utmp:x:43:
plugdev:x:46:
staff:x:50:
lock:x:54:
netdev:x:82:
users:x:100:
nobody:x:65534:
EOF
mkdir -pv $ROOTFS_DIR/run/lock
mkdir -pv $ROOTFS_DIR/usr/{bin,lib,sbin}
ln -svnf usr/bin $ROOTFS_DIR/bin
ln -svnf usr/sbin $ROOTFS_DIR/sbin
ln -svnf usr/lib $ROOTFS_DIR/lib
ln -svnf lib $ROOTFS_DIR/lib64
ln -svnf lib $ROOTFS_DIR/usr/lib64
ln -sv ../run $ROOTFS_DIR/var/run
ln -sv ../run/lock $ROOTFS_DIR/var/lock
# Prevent install scripts to create var/lock as directory
mkdir -pv $ROOTFS_DIR/usr/lib/tmpfiles.d
cat >$ROOTFS_DIR/usr/lib/tmpfiles.d/legacy.conf <<"EOF"
# This is a subset of systemd's legacy.conf

d /run/lock 0755 root root -
d /run/lock/subsys 0755 root root -

L /var/lock - - - - ../run/lock
EOF

step "[2/16] Iana-Etc 20221220"
extract $SOURCES_DIR/iana-etc-20221220.tar.gz $BUILD_DIR
cp -v $BUILD_DIR/iana-etc-20221220/services $ROOTFS_DIR/etc/services
cp -v $BUILD_DIR/iana-etc-20221220/protocols $ROOTFS_DIR/etc/protocols
rm -rf $BUILD_DIR/iana-etc-20221220

step "[3/16] Copy GCC 12.2.0 Library"
cp -v $TOOLS_DIR/$CONFIG_TARGET/lib64/libgcc_s* $ROOTFS_DIR/lib/
cp -v $TOOLS_DIR/$CONFIG_TARGET/lib64/libatomic* $ROOTFS_DIR/lib/

step "[4/16] glibc 2.36"
extract $SOURCES_DIR/glibc-2.36.tar.xz $BUILD_DIR
mkdir -pv $BUILD_DIR/glibc-2.36/glibc-build
(cd $BUILD_DIR/glibc-2.36/glibc-build &&
	CC="$TOOLS_DIR/bin/$CONFIG_TARGET-gcc" \
		CXX="$TOOLS_DIR/bin/$CONFIG_TARGET-g++" \
		AR="$TOOLS_DIR/bin/$CONFIG_TARGET-ar" \
		AS="$TOOLS_DIR/bin/$CONFIG_TARGET-as" \
		LD="$TOOLS_DIR/bin/$CONFIG_TARGET-ld" \
		RANLIB="$TOOLS_DIR/bin/$CONFIG_TARGET-ranlib" \
		READELF="$TOOLS_DIR/bin/$CONFIG_TARGET-readelf" \
		STRIP="$TOOLS_DIR/bin/$CONFIG_TARGET-strip" \
		CFLAGS="-O2 " CPPFLAGS="" CXXFLAGS="-O2 " LDFLAGS="" \
		ac_cv_path_BASH_SHELL=/bin/bash \
		libc_cv_forced_unwind=yes \
		libc_cv_ssp=no \
		$BUILD_DIR/glibc-2.36/configure \
		--target=$CONFIG_TARGET \
		--host=$CONFIG_TARGET \
		--build=$CONFIG_HOST \
		--prefix=/usr \
		--enable-shared \
		--without-cvs \
		--disable-profile \
		--without-gd \
		--enable-obsolete-rpc \
		--with-pkgversion="$CONFIG_PKG_VERSION" \
		--with-headers=$SYSROOT_DIR/usr/include \
		--enable-kernel=5.15)
make -j$PARALLEL_JOBS -C $BUILD_DIR/glibc-2.36/glibc-build
make -j$PARALLEL_JOBS install_root=$ROOTFS_DIR install -C $BUILD_DIR/glibc-2.36/glibc-build
cat >$ROOTFS_DIR/etc/nsswitch.conf <<"EOF"
# Begin /etc/nsswitch.conf

passwd: files
group: files
shadow: files

hosts: files dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

# End /etc/nsswitch.conf
EOF
rm -rf $BUILD_DIR/glibc-2.36

step "[5/16] ncurses 6.3"
extract $SOURCES_DIR/ncurses-6.3.tar.gz $BUILD_DIR
(cd $BUILD_DIR/ncurses-6.3 &&
	./configure \
		--target=$CONFIG_TARGET \
		--host=$CONFIG_TARGET \
		--build=$CONFIG_HOST \
		--prefix=/usr \
		--disable-static \
		--enable-shared \
		--without-cxx \
		--without-cxx-binding \
		--without-ada \
		--without-tests \
		--disable-big-core \
		--without-profile \
		--disable-rpath \
		--disable-rpath-hack \
		--enable-echo \
		--enable-const \
		--enable-overwrite \
		--enable-pc-files \
		--disable-stripping \
		--with-pkg-config-libdir="/usr/lib/pkgconfig" \
		--without-progs \
		--without-manpages \
		--with-shared \
		--without-normal \
		--without-gpm \
		--without-debug)
make -j$PARALLEL_JOBS -C $BUILD_DIR/ncurses-6.3
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/ncurses-6.3
make -j$PARALLEL_JOBS DESTDIR=$ROOTFS_DIR install -C $BUILD_DIR/ncurses-6.3
rm -rf $BUILD_DIR/ncurses-6.3

step "[6/16] readline 8.2"
extract $SOURCES_DIR/readline-8.2.tar.gz $BUILD_DIR
(cd $BUILD_DIR/readline-8.2 &&
	./configure \
		--target=$CONFIG_TARGET \
		--host=$CONFIG_TARGET \
		--build=$CONFIG_HOST \
		--prefix=/usr \
		--disable-static \
		--enable-shared \
		--disable-install-examples \
		--disable-bracketed-paste-default)
make -j$PARALLEL_JOBS -C $BUILD_DIR/readline-8.2
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/readline-8.2
make -j$PARALLEL_JOBS DESTDIR=$ROOTFS_DIR install -C $BUILD_DIR/readline-8.2
# Create /etc/inputrc
cat >$ROOTFS_DIR/etc/inputrc <<"EOF"
# /etc/inputrc - global inputrc for libreadline
# See readline(3readline) and `info readline' for more information.

# Be 8 bit clean.
set input-meta on
set output-meta on
set bell-style visible

# To allow the use of 8bit-characters like the german umlauts, comment out
# the line below. However this makes the meta key not work as a meta key,
# which is annoying to those which don't need to type in 8-bit characters.

# set convert-meta off

"\e0d": backward-word
"\e0c": forward-word
"\e[h": beginning-of-line
"\e[f": end-of-line
"\e[1~": beginning-of-line
"\e[4~": end-of-line
#"\e[5~": beginning-of-history
#"\e[6~": end-of-history
"\e[3~": delete-char
"\e[2~": quoted-insert

# Common standard keypad and cursor
# (codes courtsey Werner Fink, <werner@suse.de>)
#"\e[1~": history-search-backward
"\e[2~": yank
"\e[3~": delete-char
#"\e[4~": set-mark
"\e[5~": history-search-backward
"\e[6~": history-search-forward
# Normal keypad and cursor of xterm
"\e[F": end-of-line
"\e[H": beginning-of-line
# Application keypad and cursor of xterm
"\eOA": previous-history
"\eOC": forward-char
"\eOB": next-history
"\eOD": backward-char
"\eOF": end-of-line
"\eOH": beginning-of-line
EOF
rm -rf $BUILD_DIR/readline-8.2

step "[7/16] bash 5.2.15"
extract $SOURCES_DIR/bash-5.2.15.tar.gz $BUILD_DIR
(cd $BUILD_DIR/bash-5.2.15 &&
	./configure \
		--target=$CONFIG_TARGET \
		--host=$CONFIG_TARGET \
		--build=$CONFIG_HOST \
		--prefix=/usr \
		--bindir=/bin \
		--disable-static \
		--enable-shared \
		--with-installed-readline \
		--without-bash-malloc)
make -j$PARALLEL_JOBS -C $BUILD_DIR/bash-5.2.15
make -j$PARALLEL_JOBS DESTDIR=$ROOTFS_DIR install -C $BUILD_DIR/bash-5.2.15
rm -f $ROOTFS_DIR/bin/bashbug
rm -rf $ROOTFS_DIR/usr/lib/bash
echo "/bin/bash" >>$ROOTFS_DIR/etc/shells
sed -i -e '/^root:/s,[^/]*$,bash,' $ROOTFS_DIR/etc/passwd
ln -svf bash $ROOTFS_DIR/bin/sh
rm -rf $BUILD_DIR/bash-5.2.15

step "[8/16] expat 2.5.0"
extract $SOURCES_DIR/expat-2.5.0.tar.xz $BUILD_DIR
(cd $BUILD_DIR/expat-2.5.0 &&
	./configure \
		--target=$CONFIG_TARGET \
		--host=$CONFIG_TARGET \
		--build=$CONFIG_HOST \
		--prefix=/usr \
		--disable-static \
		--enable-shared \
		--without-docbook \
		--without-examples \
		--without-tests)
make -j$PARALLEL_JOBS -C $BUILD_DIR/expat-2.5.0
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/expat-2.5.0
make -j$PARALLEL_JOBS DESTDIR=$ROOTFS_DIR install -C $BUILD_DIR/expat-2.5.0
rm -rf $BUILD_DIR/expat-2.5.0

step "[9/16] kmod 30"
extract $SOURCES_DIR/kmod-30.tar.xz $BUILD_DIR
(cd $BUILD_DIR/kmod-30 &&
	./configure \
		--target=$CONFIG_TARGET \
		--host=$CONFIG_TARGET \
		--build=$CONFIG_HOST \
		--prefix=/usr \
		--disable-static \
		--enable-shared \
		--disable-manpages \
		--without-zlib \
		--without-zstd \
		--without-xz \
		--without-openssl)
make -j$PARALLEL_JOBS -C $BUILD_DIR/kmod-30
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/kmod-30
make -j$PARALLEL_JOBS DESTDIR=$ROOTFS_DIR install -C $BUILD_DIR/kmod-30
rm -rf $BUILD_DIR/kmod-30

step "[10/16] libcap 2.66"
extract $SOURCES_DIR/libcap-2.66.tar.xz $BUILD_DIR
sed -i '/install -m.*STA/d' $BUILD_DIR/libcap-2.66/libcap/Makefile
make -j1 BUILD_CC="gcc" CROSS_COMPILE="$TOOLS_DIR/bin/$CONFIG_TARGET-" RAISE_SETFCAP=no lib=lib prefix=/usr SHARED=yes all -C $BUILD_DIR/libcap-2.66/libcap
make -j$PARALLEL_JOBS CROSS_COMPILE="$TOOLS_DIR/bin/$CONFIG_TARGET-" RAISE_SETFCAP=no lib=lib prefix=/usr SHARED=yes PTHREADS=yes DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/libcap-2.66
make -j$PARALLEL_JOBS CROSS_COMPILE="$TOOLS_DIR/bin/$CONFIG_TARGET-" RAISE_SETFCAP=no lib=lib prefix=/usr SHARED=yes PTHREADS=yes DESTDIR=$ROOTFS_DIR install -C $BUILD_DIR/libcap-2.66
rm -rf $BUILD_DIR/libcap-2.66

step "[11/16] coreutils 9.1"
extract $SOURCES_DIR/coreutils-9.1.tar.xz $BUILD_DIR
(cd $BUILD_DIR/coreutils-9.1 &&
	./configure \
		--target=$CONFIG_TARGET \
		--host=$CONFIG_TARGET \
		--build=$CONFIG_HOST \
		--prefix=/usr \
		--disable-static \
		--enable-shared)
make -j$PARALLEL_JOBS -C $BUILD_DIR/coreutils-9.1
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/coreutils-9.1
make -j$PARALLEL_JOBS DESTDIR=$ROOTFS_DIR install -C $BUILD_DIR/coreutils-9.1
rm -rf $BUILD_DIR/coreutils-9.1

step "[12/16] util-linux 2.38.1 (libs)"
extract $SOURCES_DIR/util-linux-2.38.1.tar.xz $BUILD_DIR
for file in config.guess config.sub; do
	for i in $(find $BUILD_DIR/util-linux-2.38.1 -name $file); do
		cp -v $SUPPORT_DIR/gnuconfig/$file $i
	done
done
for i in $(find $BUILD_DIR/util-linux-2.38.1 -name ltmain.sh); do
	patch -i $SUPPORT_DIR/libtool/libtool-v2.4.4.patch $i
done
(cd $BUILD_DIR/util-linux-2.38.1 &&
	./configure \
		--target=$CONFIG_TARGET \
		--host=$CONFIG_TARGET \
		--build=$CONFIG_HOST \
		--prefix=/usr \
		--bindir=/usr/bin \
		--sbindir=/usr/sbin \
		--libdir=/usr/lib \
		--disable-static \
		--enable-shared \
		--disable-rpath \
		--disable-makeinstall-chown \
		--without-systemd \
		--with-systemdsystemunitdir=no \
		--without-udev \
		--disable-widechar \
		--without-ncursesw \
		--without-ncurses \
		--without-selinux \
		--disable-all-programs \
		--enable-libblkid \
		--disable-libfdisk \
		--enable-libmount \
		--disable-libsmartcols \
		--enable-libuuid \
		--without-python \
		--disable-pylibmount \
		--without-readline \
		--without-audit \
		--without-libmagic)
make -j$PARALLEL_JOBS -C $BUILD_DIR/util-linux-2.38.1
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/util-linux-2.38.1
make -j$PARALLEL_JOBS DESTDIR=$ROOTFS_DIR install -C $BUILD_DIR/util-linux-2.38.1
rm -rf $BUILD_DIR/util-linux-2.38.1

step "[13/16] systemd v252"
extract $SOURCES_DIR/v252.tar.gz $BUILD_DIR
rm -rf $BUILD_DIR/systemd-252/build
mkdir -pv $BUILD_DIR/systemd-252/build
sed -e "/^\[binaries\]$/s:$::" \
	-e "/^\[properties\]$/s:$::" \
	-e "s%@TARGET_CC@%$TOOLS_DIR/bin/$CONFIG_TARGET-gcc%g" \
	-e "s%@TARGET_CXX@%$TOOLS_DIR/bin/$CONFIG_TARGET-g++%g" \
	-e "s%@TARGET_AR@%$TOOLS_DIR/bin/$CONFIG_TARGET-gcc-ar%g" \
	-e "s%@TARGET_FC@%/bin/false%g" \
	-e "s%@TARGET_STRIP@%$TOOLS_DIR/bin/$CONFIG_TARGET-strip%g" \
	-e "s%@TARGET_ARCH@%$CONFIG_LINUX_ARCH%g" \
	-e "s%@TARGET_CPU@%%g" \
	-e "s%@TARGET_ENDIAN@%little%g" \
	-e "s%@TARGET_FCFLAGS@%%g" \
	-e "s%@TARGET_CFLAGS@%'-D_LARGEFILE_SOURCE', '-D_LARGEFILE64_SOURCE', '-D_FILE_OFFSET_BITS=64', '-Os', '-g0', '-D_FORTIFY_SOURCE=1'%g" \
	-e "s%@TARGET_LDFLAGS@%%g" \
	-e "s%@TARGET_CXXFLAGS@%'-D_LARGEFILE_SOURCE', '-D_LARGEFILE64_SOURCE', '-D_FILE_OFFSET_BITS=64', '-Os', '-g0', '-D_FORTIFY_SOURCE=1'%g" \
	-e "s%@BR2_CMAKE@%cmake%g" \
	-e "s%@PKGCONF_HOST_BINARY@%$TOOLS_DIR/bin/pkgconf%g" \
	-e "s%@HOST_DIR@%$TOOLS_DIR%g" \
	-e "s%@STAGING_DIR@%$TOOLS_DIR/$CONFIG_TARGET/sysroot%g" \
	-e "s%@STATIC@%false%g" \
	$SUPPORT_DIR/meson/cross-compilation.conf >$BUILD_DIR/systemd-252/build/cross-compilation.conf
PYTHONNOUSERSITE=y \
	$TOOLS_DIR/bin/meson \
	--prefix=/usr \
	--libdir=lib \
	--default-library=shared \
	--buildtype=release \
	--cross-file=$BUILD_DIR/systemd-252/build/cross-compilation.conf \
	-Db_pie=false \
	-Dstrip=false \
	-Dbuild.pkg_config_path=$TOOLS_DIR/lib/pkgconfig \
	-Dbuild.cmake_prefix_path=$TOOLS_DIR/lib/cmake \
	-Ddefault-hierarchy=unified \
	-Didn=true \
	-Dima=false \
	-Dkexec-path=/usr/sbin/kexec \
	-Dkmod-path=/usr/bin/kmod \
	-Dldconfig=false \
	-Dlink-boot-shared=true \
	-Dloadkeys-path=/usr/bin/loadkeys \
	-Dman=false \
	-Dmount-path=/usr/bin/mount \
	-Dmode=release \
	-Dnss-systemd=true \
	-Dquotacheck-path=/usr/sbin/quotacheck \
	-Dquotaon-path=/usr/sbin/quotaon \
	-Drootlibdir='/usr/lib' \
	-Dsetfont-path=/usr/bin/setfont \
	-Dsplit-bin=true \
	-Dsplit-usr=false \
	-Dsulogin-path=/usr/sbin/sulogin \
	-Dsystem-gid-max=999 \
	-Dsystem-uid-max=999 \
	-Dsysvinit-path= \
	-Dsysvrcnd-path= \
	-Dtelinit-path= \
	-Dtests=false \
	-Dtmpfiles=true \
	-Dumount-path=/usr/bin/umount \
	-Dutmp=false \
	-Dacl=false \
	-Durlify=false \
	-Dapparmor=false \
	-Daudit=false \
	-Dlibcryptsetup=false \
	-Dlibcryptsetup-plugins=false \
	-Delfutils=false \
	-Dlibiptc=false \
	-Dlibidn=false \
	-Dlibidn2=false \
	-Dseccomp=false \
	-Dxkbcommon=false \
	-Dbzip2=false \
	-Dzstd=false \
	-Dlz4=false \
	-Dpam=false \
	-Dfdisk=false \
	-Dvalgrind=false \
	-Dxz=false \
	-Dzlib=false \
	-Dlibcurl=false \
	-Ddefault-dnssec=no \
	-Dgcrypt=false \
	-Dp11kit=false \
	-Dpcre2=false \
	-Dblkid=true \
	-Dnologin-path=/bin/false \
	-Dinitrd=false \
	-Dkernel-install=false \
	-Danalyze=false \
	-Dremote=false \
	-Dmicrohttpd=false \
	-Dqrencode=false \
	-Dselinux=false \
	-Dhwdb=true \
	-Dbinfmt=false \
	-Dvconsole=true \
	-Dquotacheck=false \
	-Dsysusers=false \
	-Dfirstboot=false \
	-Drandomseed=false \
	-Dbacklight=false \
	-Drfkill=false \
	-Dlogind=false \
	-Dmachined=false \
	-Dnss-mymachines=false \
	-Dimportd=false \
	-Dhomed=false \
	-Dhostnamed=true \
	-Dnss-myhostname=true \
	-Dtimedated=true \
	-Dlocaled=false \
	-Drepart=false \
	-Duserdb=false \
	-Dcoredump=false \
	-Dpstore=true \
	-Doomd=false \
	-Dpolkit=false \
	-Dportabled=false \
	-Dsysext=false \
	-Dnetworkd=true \
	-Dnss-resolve=true \
	-Dresolve=true \
	-Dgnutls=false \
	-Dopenssl=false \
	-Ddns-over-tls=false \
	-Ddefault-dns-over-tls=no \
	-Dtimesyncd=true \
	-Dsmack=false \
	-Dhibernate=false \
	-Defi=false \
	-Dgnu-efi=false \
	-Dfallback-hostname=$CONFIG_HOSTNAME \
	$BUILD_DIR/systemd-252 \
	$BUILD_DIR/systemd-252/build
PYTHONNOUSERSITE=y $TOOLS_DIR/bin/ninja -C $BUILD_DIR/systemd-252/build
DESTDIR=$SYSROOT_DIR PYTHONNOUSERSITE=y $TOOLS_DIR/bin/ninja -C $BUILD_DIR/systemd-252/build install
DESTDIR=$ROOTFS_DIR PYTHONNOUSERSITE=y $TOOLS_DIR/bin/ninja -C $BUILD_DIR/systemd-252/build install
mkdir -pv $ROOTFS_DIR/usr/lib/systemd/system/getty@tty1.service.d
cat >$ROOTFS_DIR/usr/lib/systemd/system/getty@tty1.service.d/override.conf <<"EOF"
[Service]
ExecStart=
ExecStart=-/sbin/sulogin
Type=idle
EOF
mkdir -pv $ROOTFS_DIR/usr/lib/systemd/system/getty.target.wants
ln -sfv /usr/lib/systemd/system/getty@.service $ROOTFS_DIR/usr/lib/systemd/system/getty.target.wants/getty@tty1.service
rm -rf $ROOTFS_DIR/usr/lib/systemd/system/systemd-hwdb-update.service $ROOTFS_DIR/usr/lib/systemd/system/*/systemd-hwdb-update.service $ROOTFS_DIR/usr/bin/systemd-hwdb
ln -fs "multi-user.target" $ROOTFS_DIR/usr/lib/systemd/system/default.target
touch $ROOTFS_DIR/etc/machine-id
$TOOLS_DIR/bin/systemd-hwdb update --root $ROOTFS_DIR --strict --usr
sed -i -e '/^passwd:/ {/systemd/! s/$/ systemd/}' \
	-e '/^group:/ {/systemd/! s/$/ [SUCCESS=merge] systemd/}' \
	-e '/^shadow:/ {/systemd/! s/$/ systemd/}' \
	-e '/^gshadow:/ {/systemd/! s/$/ systemd/}' \
	-e '/^hosts:/ s/[[:space:]]*mymachines//' \
	-e '/^hosts:/ {/resolve/! s/files/resolve [!UNAVAIL=return] files/}' \
	-e '/^hosts:/ {/myhostname/! s/files/files myhostname/}' \
	$ROOTFS_DIR/etc/nsswitch.conf
ln -sf ../run/systemd/resolve/resolv.conf $ROOTFS_DIR/etc/resolv.conf
rm -rf $BUILD_DIR/systemd-252

step "[14/16] dbus 1.14.4"
extract $SOURCES_DIR/dbus-1.14.4.tar.xz $BUILD_DIR
(cd $BUILD_DIR/dbus-1.14.4 &&
	./configure \
		--target=$CONFIG_TARGET \
		--host=$CONFIG_TARGET \
		--build=$CONFIG_HOST \
		--prefix=/usr \
		--disable-static \
		--enable-shared \
		--with-dbus-user=dbus \
		--disable-tests \
		--disable-asserts \
		--disable-xml-docs \
		--disable-doxygen-docs \
		--with-system-socket=/run/dbus/system_bus_socket \
		--with-system-pid-file=/run/messagebus.pid \
		--disable-selinux \
		--disable-libaudit \
		--without-x \
		--enable-systemd \
		--with-systemdsystemunitdir=/usr/lib/systemd/system)
make -j$PARALLEL_JOBS LDFLAGS="-L$SYSROOT_DIR/lib" -C $BUILD_DIR/dbus-1.14.4
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/dbus-1.14.4
make -j$PARALLEL_JOBS DESTDIR=$ROOTFS_DIR install -C $BUILD_DIR/dbus-1.14.4
mkdir -p $ROOTFS_DIR/var/lib/dbus
ln -svf /etc/machine-id $ROOTFS_DIR/var/lib/dbus/machine-id
rm -rf $ROOTFS_DIR/usr/lib/dbus-1.0
rm -rf $BUILD_DIR/dbus-1.14.4

step "[15/16] tzdata 2022g"
install -d -m 0755 $ROOTFS_DIR/usr/share/zoneinfo
cp -a $TOOLS_DIR/share/zoneinfo/* $ROOTFS_DIR/usr/share/zoneinfo
(cd $ROOTFS_DIR/usr/share/zoneinfo && for zone in posix/*; do ln -sfn "${zone}" "${zone##*/}"; done)
ln -svf ../usr/share/zoneinfo/Asia/Seoul $ROOTFS_DIR/etc/localtime
echo "Asia/Seoul" >$ROOTFS_DIR/etc/timezone

step "[16/16] util-linux 2.38.1"
extract $SOURCES_DIR/util-linux-2.38.1.tar.xz $BUILD_DIR
for file in config.guess config.sub; do
	for i in $(find $BUILD_DIR/util-linux-2.38.1 -name $file); do
		cp -v $SUPPORT_DIR/gnuconfig/$file $i
	done
done
for i in $(find $BUILD_DIR/util-linux-2.38.1 -name ltmain.sh); do
	patch -i $SUPPORT_DIR/libtool/libtool-v2.4.4.patch $i
done
(cd $BUILD_DIR/util-linux-2.38.1 &&
	NCURSES6_CONFIG=$SYSROOT_DIR/usr/bin/ncurses6-config \
		LIBS="" \
		./configure \
		--target=$CONFIG_TARGET \
		--host=$CONFIG_TARGET \
		--build=$CONFIG_HOST \
		--prefix=/usr \
		--bindir=/usr/bin \
		--sbindir=/usr/sbin \
		--libdir=/usr/lib \
		--disable-static \
		--enable-shared \
		--disable-rpath \
		--disable-makeinstall-chown \
		--with-systemd \
		--with-systemdsystemunitdir=/usr/lib/systemd/system \
		--with-udev \
		--without-ncursesw \
		--with-ncurses \
		--disable-widechar \
		--without-selinux \
		--disable-all-programs \
		--enable-agetty \
		--disable-bfs \
		--disable-cal \
		--disable-chfn-chsh \
		--disable-chmem \
		--disable-cramfs \
		--disable-eject \
		--disable-fallocate \
		--disable-fdformat \
		--enable-fsck \
		--disable-hardlink \
		--disable-hwclock \
		--disable-ipcmk \
		--disable-ipcrm \
		--disable-ipcs \
		--disable-kill \
		--disable-last \
		--enable-libblkid \
		--disable-libfdisk \
		--enable-libmount \
		--disable-libsmartcols \
		--enable-libuuid \
		--disable-line \
		--disable-logger \
		--disable-login \
		--disable-losetup \
		--disable-lsfd \
		--disable-lslogins \
		--disable-lsmem \
		--disable-mesg \
		--disable-minix \
		--disable-more \
		--enable-mount \
		--disable-mountpoint \
		--disable-newgrp \
		--disable-nologin \
		--disable-nsenter \
		--disable-partx \
		--disable-pg \
		--disable-pivot_root \
		--disable-raw \
		--disable-rename \
		--disable-rfkill \
		--disable-runuser \
		--disable-schedutils \
		--disable-setpriv \
		--disable-setterm \
		--disable-su \
		--enable-sulogin \
		--disable-switch_root \
		--disable-tunelp \
		--disable-ul \
		--disable-unshare \
		--disable-utmpdump \
		--disable-uuidd \
		--disable-vipw \
		--disable-wall \
		--disable-wdctl \
		--disable-wipefs \
		--disable-write \
		--disable-zramctl \
		--without-python \
		--without-readline \
		--without-audit \
		--without-libmagic)
make -j$PARALLEL_JOBS LIBS="" -C $BUILD_DIR/util-linux-2.38.1
make -j$PARALLEL_JOBS LIBS="" DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/util-linux-2.38.1
make -j$PARALLEL_JOBS LIBS="" DESTDIR=$ROOTFS_DIR install -C $BUILD_DIR/util-linux-2.38.1
ln -sf agetty $ROOTFS_DIR/sbin/getty
rm -rf $BUILD_DIR/util-linux-2.38.1

do_strip

success "\nTotal root file system build time: $(timer $total_build_time)\n"
