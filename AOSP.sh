#!/bin/bash

BUILDTYPE="aosp_flo-userdebug"
AOSPBRANCH="android-6.0.1_r59"
BLOBFILES="https://dl.google.com/dl/android/aosp/asus-flo-mob30x-76f70c4a.tgz
https://dl.google.com/dl/android/aosp/broadcom-flo-mob30x-23c0a6c8.tgz
https://dl.google.com/dl/android/aosp/qcom-flo-mob30x-43963492.tgz"
BUILDDIR="/opt/AOSPBuild"
BUILDUSER="ololo"
BUILDMAIL="ololo@ololo.ololo"
ROOTTAR="http://ftp.iij.ad.jp/pub/openvz/template/precreated/ubuntu-14.04-x86_64-minimal.tar.gz"

if [ ! -d "$BUILDDIR" ]; then
echo "Downloading Ubuntu root to $BUILDDIR"
    if [ ! -f "/tmp/ubuntu.tar.gz" ]; then
	echo "Downloading template to /tmp"
	wget $ROOTTAR -O /tmp/ubuntu.tar.gz
    fi
mkdir -p $BUILDDIR || true
tar xf /tmp/ubuntu.tar.gz -C $BUILDDIR
fi

if [ ! -f "/tmp/vfs_mounted" ]; then
echo "Mounting VFS"
mount -o bind /dev $BUILDDIR/dev || true
mount -t devpts devpts $BUILDDIR/dev/pts || true
mount -t sysfs /sys $BUILDDIR/sys || true
mount -t proc proc $BUILDDIR/proc || true
echo "nameserver 8.8.8.8" > $BUILDDIR/etc/resolv.conf
fi
touch /tmp/vfs_mounted

if [ ! -f "$BUILDDIR/pkgs_installed" ]; then
echo "Installing packages"
chroot $BUILDDIR /bin/bash -c "cat /etc/*-release && apt -yyq update && apt -yyq upgrade && apt -yyq install openjdk-7-jdk git-core gnupg flex bison gperf build-essential zip curl zlib1g-dev gcc-multilib g++-multilib libc6-dev-i386 lib32ncurses5-dev x11proto-core-dev libx11-dev lib32z-dev ccache libgl1-mesa-dev libxml2-utils xsltproc unzip || true"
#chroot $BUILDDIR /bin/bash -c "curl https://storage.googleapis.com/git-repo-downloads/repo > /usr/bin/repo && chmod +x /usr/bin/repo"
fi
touch $BUILDDIR/pkgs_installed

if [ ! -d "$BUILDDIR/home/$BUILDUSER" ]; then
echo "Useradd, clone, sync"
chroot $BUILDDIR /bin/bash -c "useradd -m $BUILDUSER || true"
cat >$BUILDDIR/aosp_init.sh <<EOF
#!/bin/bash
git config --global user.name "$BUILDUSER"
git config --global user.email "$BUILDMAIL"
curl https://storage.googleapis.com/git-repo-downloads/repo > repo
chmod +x repo
yes | ./repo init --depth=1 -u https://android.googlesource.com/platform/manifest -b "$AOSPBRANCH"
./repo sync -c
echo "Repo synchronized"
EOF
chmod +x $BUILDDIR/aosp_init.sh
chroot $BUILDDIR /bin/bash -c "su - $BUILDUSER -c /aosp_init.sh"
fi

BLOBS=$(find "$BUILDDIR/home/$BUILDUSER" -maxdepth 1 -iname "*.sh")
if [ "$BLOBS" == "" ]; then
echo "Downloading blobs and do primary unpacking"
for BLOBFILE in $BLOBFILES
do
echo "Downloading blob: $BLOBFILE"
chroot $BUILDDIR /bin/bash -c "su - $BUILDUSER -c 'wget $BLOBFILE -O - | tar -xz'"
done
echo "Do secondary blobs unpacking"
cat >$BUILDDIR/unpacker.sh <<EOF
#!/bin/bash
SHBLOBS=\$(find . -maxdepth 1 -iname '*.sh')
for SHBLOB in \$SHBLOBS
do
OFFSET=\$(cat \$SHBLOB | grep --text 'tail -n +' | cut -d ' ' -f 3)
echo \$OFFSET
tail -n \$OFFSET \$SHBLOB | tar zxv
done
EOF
chmod +x $BUILDDIR/unpacker.sh
chroot $BUILDDIR /bin/bash -c "su - $BUILDUSER -c /unpacker.sh"
fi

echo "MY TWEAKS BEGIN HERE"
echo "==============================================="
echo "==============================================="
echo "MY TWEAKS END HERE"

echo "Starting AOSP build"
chroot $BUILDDIR /bin/bash -c "su - $BUILDUSER -c 'make clobber && source build/envsetup.sh && lunch $BUILDTYPE && make otapackage'"
