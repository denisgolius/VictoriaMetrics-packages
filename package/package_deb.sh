#!/bin/bash

# Install the following packages on your system if you want to build the deb package for the riscv64 architectures 
# sudo apt install g++-riscv64-linux-gnu gcc-riscv64-linux-gnu build-essential -y 

# ARCH="amd64"
# if [[ $# -ge 1 ]]
# then
#     ARCH="$1"
# fi

AUTHOR="Denys Holius"
if [[ $# -ge 2 ]]
then
    AUTHOR="$2"
else
    AUTHOR=`git config --list | grep "user.name" | awk -F "=" '{print $2}' || cat ../.git/config | grep "name"  | awk -F "=" '{print $2}' | cut -c 2-`
    `sed -i -e 's/Maintainer\:.*/Maintainer\:\ $AUTHOR/g' package/deb/control`
fi

ARCHS=("amd64" "arm64" "arm" "riscv64" "386" "ppc64le" "s390x" "loong64")

for ARCH in "${ARCHS[@]}" ; do
    DEB_ARCH="${ARCH}"
	EXENAME_SRC="victoria-metrics-linux-${ARCH}"

    # Map to Debian architecture
    if [[ "$ARCH" == "amd64" ]]; then
        DEB_ARCH=amd64
        EXENAME_SRC="victoria-metrics-linux-amd64"
    elif [[ "$ARCH" == "arm64" ]]; then
        DEB_ARCH=arm64
        EXENAME_SRC="victoria-metrics-linux-arm64"
    elif [[ "$ARCH" == "arm" ]]; then
        DEB_ARCH=armhf
        EXENAME_SRC="victoria-metrics-linux-arm"
    elif [[ "$ARCH" == "riscv64" ]]; then
        DEB_ARCH=riscv64
        EXENAME_SRC="victoria-metrics-linux-riscv64"
    elif [[ "$ARCH" == "386" ]]; then
        DEB_ARCH=386
        EXENAME_SRC="victoria-metrics-linux-386"
    elif [[ "$ARCH" == "ppc64le" ]]; then
        DEB_ARCH=ppc64le
        EXENAME_SRC="victoria-metrics-linux-ppc64le"
    elif [[ "$ARCH" == "s390x" ]]; then
        DEB_ARCH=s390x
        EXENAME_SRC="victoria-metrics-linux-s390x"
    elif [[ "$ARCH" == "loong64" ]]; then
        DEB_ARCH=loong64
        EXENAME_SRC="victoria-metrics-linux-loong64"
    else
        echo "*** Unknown arch $ARCH"
        exit 1
    fi

    PACKDIR="./package"
    TEMPDIR="${PACKDIR}/temp-deb-${DEB_ARCH}"
    EXENAME_DST="victoria-metrics"

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
done