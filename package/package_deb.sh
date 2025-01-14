#!/bin/bash

ARCH="amd64"
if [[ $# -ge 1 ]]
then
    ARCH="$1"
fi

# AUTHOR="Denys Holius"
# if [[ $# -ge 2 ]]
# then
#     AUTHOR="$2"
# else
#     AUTHOR=`git config --list | grep "user.name" | awk -F "=" '{print $2}' || cat ../.git/config | grep "name"  | awk -F "=" '{print $2}' | cut -c 2-`
#     `sed -i -e 's/Maintainer\:\ Denys\ Holius/Maintainer\:\ ${AUTHOR}/g' ${PACKDIR}/deb/control`
# fi

# Map to Debian architecture
if [[ "$ARCH" == "amd64" ]]; then
    DEB_ARCH=amd64
	EXENAME_SRC="victoria-metrics-linux-amd64-prod"
elif [[ "$ARCH" == "arm64" ]]; then
    DEB_ARCH=arm64
    EXENAME_SRC="victoria-metrics-linux-arm64-prod"
elif [[ "$ARCH" == "arm" ]]; then
    DEB_ARCH=armhf
    EXENAME_SRC="victoria-metrics-linux-arm-prod"
elif [[ "$ARCH" == "riscv64" ]]; then
    DEB_ARCH=riscv64
    EXENAME_SRC="victoria-metrics-linux-riscv64-prod"
elif [[ "$ARCH" == "i386" ]]; then
    DEB_ARCH=i386
    EXENAME_SRC="victoria-metrics-linux-i386-prod"
else
    echo "*** Unknown arch $ARCH"
    exit 1
fi

PACKDIR="./package"
TEMPDIR="${PACKDIR}/temp-deb-${DEB_ARCH}"
EXENAME_DST="victoria-metrics-prod"

# Pull in version info

#VERSION=`cat ${PACKDIR}/VAR_VERSION | perl -ne 'chomp and print'`
VERSION=`git describe --tags --abbrev=0 | sed 's/v//g'`
BUILD=`cat ${PACKDIR}/VAR_BUILD | perl -ne 'chomp and print'`

# Create directories

[[ -d "${TEMPDIR}" ]] && rm -rf "${TEMPDIR}"

mkdir -p "${TEMPDIR}" && echo "*** Created   : ${TEMPDIR}"

mkdir -p "${TEMPDIR}/usr/bin/"
mkdir -p "${TEMPDIR}/lib/systemd/system/"

echo "*** Version   : ${VERSION}-${BUILD}"
echo "*** Arch      : ${DEB_ARCH}"

OUT_DEB="victoria-metrics_${VERSION}-${BUILD}_$DEB_ARCH.deb"

echo "*** Out .deb  : ${OUT_DEB}"

# Copy the binary

cp "./bin/${EXENAME_SRC}" "${TEMPDIR}/usr/bin/${EXENAME_DST}"

# Copy supporting files

cp "${PACKDIR}/victoria-metrics.service" "${TEMPDIR}/lib/systemd/system/"

# Generate debian-binary

echo "2.0" > "${TEMPDIR}/debian-binary"

# Generate control

echo "Version: $VERSION-$BUILD" > "${TEMPDIR}/control"
echo "Installed-Size:" `du -sb "${TEMPDIR}" | awk '{print int($1/1024)}'` >> "${TEMPDIR}/control"
echo "Architecture: $DEB_ARCH" >> "${TEMPDIR}/control"
cat "${PACKDIR}/deb/control" >> "${TEMPDIR}/control"

# Copy conffile

cp "${PACKDIR}/deb/conffile" "${TEMPDIR}/conffile"

# Copy postinst and postrm

cp "${PACKDIR}/deb/postinst" "${TEMPDIR}/postinst"
cp "${PACKDIR}/deb/prerm" "${TEMPDIR}/prerm"
cp "${PACKDIR}/deb/postrm" "${TEMPDIR}/postrm"

(
    # Generate md5 sums

    cd "${TEMPDIR}"

    find ./usr ./lib -type f | while read i ; do
        md5sum "$i" | sed 's/\.\///g' >> md5sums
    done

    # Archive control

    chmod 644 control md5sums
    chmod 755 postinst postrm prerm
    fakeroot -- tar -c --xz -f ./control.tar.xz ./control ./md5sums ./postinst ./prerm ./postrm

    # Archive data

    fakeroot -- tar -c --xz -f ./data.tar.xz ./usr ./lib

    # Make final archive

    fakeroot -- ar -cr "${OUT_DEB}" debian-binary control.tar.xz data.tar.xz
)

ls -lh "${TEMPDIR}/${OUT_DEB}"

cp "${TEMPDIR}/${OUT_DEB}" "${PACKDIR}"

echo "*** Created   : ${PACKDIR}/${OUT_DEB}"
