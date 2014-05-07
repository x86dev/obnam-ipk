#/bin/sh -e

# Copyright 2013-2014 by x86dev.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

SCRIPT_DIR_BASE=$(readlink -f $0 | xargs dirname)

# Enable for debugging.
#set -x

SCIPRT_ARCH_MACHINE=`uname -m`
if [ -z "$SCIPRT_ARCH_MACHINE" ]; then
    echo "ERROR: Unable to retrieve CPU architecture - aborting" 1>&2
    exit 1
fi
case "$SCIPRT_ARCH_MACHINE" in
    x86*)
        SCRIPT_ARCH="intel"
        SCRIPT_CFG_IPK_ARCH="i686"
        ;;
    arm*) ## @todo Distinguish between arm/armv5tel?
        SCRIPT_ARCH="arm"
        SCRIPT_CFG_IPK_ARCH="arm"
        ;;
    ## @todo SCRIPT_CFG_IPK_ARCH="mipsel"?
    *)
        echo "ERROR: CPU architecture not supported - aborting" 1>&2
        exit 1
        ;;
esac

if [ "$SCRIPT_ARCH" = "arm" ]; then # e.g. Synology w/ Optware installed
    CAT=/bin/cat
    MKDIR=/bin/mkdir
    PATCH=/opt/bin/patch
    PYTHON=/opt/bin/python
    RM=/bin/rm
    TAR=/bin/tar
    UNZIP=/opt/bin/unzip
    WGET=/opt/bin/wget
else # Linux, e.g. Debian
    CAT=/bin/cat
    MKDIR=/bin/mkdir
    RM=/bin/rm
    PATCH=/usr/bin/patch
    PYTHON=/usr/bin/python
    TAR=/bin/tar
    UNZIP=/usr/bin/unzip
    WGET=/usr/bin/wget
fi

# Sensible defaults.
SCRIPT_CFG_OBNAM_VER="newest"

show_help()
{
    echo "Script for building, installing and packaging Obnam."
    echo ""
    echo "Currently, only Intel i686 and ARM architectures"
    echo "are supported. Feedback welcome!"
    echo ""
    echo "Usage: $0 [--help|-h|-?]"
    echo "       build | install | uninstall"
    echo "       [--obnam-version <VERSION>] [--obnam-deps]"
    echo "       [--no-cleanup] [--no-patching]"
    echo ""
    exit 1
}

if [ $# -lt 1 ]; then
    echo "ERROR: No main command given" 1>&2
    echo "" 1>&2
    show_help
fi

SCRIPT_CMD="$1"
shift
case "$SCRIPT_CMD" in
    build)
        # Building can be performed by regular users.
        ;;
    install)
        if [ "$(id -u)" != "0" ]; then
            echo "Installation only can be done as root - aborting" 1>&2
            exit 2
        fi
        ;;
    uninstall)
        if [ "$(id -u)" != "0" ]; then
            echo "Uninstallation only can be done as root - aborting" 1>&2
            exit 2
        fi
        ;;
    --help|-h|-?)
        show_help
        ;;
    *)
        echo "ERROR: Unknown main command \"$SCRIPT_CMD\"" 1>&2
        echo "" 1>&2
        show_help
        ;;
esac

while [ $# != 0 ]; do
    CUR_PARM="$1"
    shift
    ## @todo Implement stage caching.
    case "$CUR_PARM" in
        --help|-h|-?)
            show_help
            ;;
        --obnam-version|--obnam-ver)
            SCRIPT_CFG_OBNAM_VER="$1"
            shift
            ;;
        --obnam-deps)
            SCRIPT_CFG_OBNAM_DEPS="1"
            ;;
        --no-cleanup)
            SCRIPT_CFG_NO_CLEANUP="1"
            ;;
        --no-patching)
            SCRIPT_CFG_NO_PATCHING="1"
            ;;
        ## @todo Add RPM support (--pkg-format=rpm).
        ## @todo Add proxy support.
        *)
            echo "ERROR: Unknown option \"$CUR_PARM\"" 1>&2
            echo ""
            show_help
            ;;
    esac
done

SCRIPT_DIR_STAGING=${SCRIPT_DIR_BASE}/staging
SCRIPT_DIR_DEPS=${SCRIPT_DIR_STAGING}/deps
SCRIPT_DIR_OBNAM=${SCRIPT_DIR_STAGING}/obnam
SCRIPT_DIR_IPKG=${SCRIPT_DIR_STAGING}/ipkg
SCRIPT_DIR_IPKG_CONTROL=${SCRIPT_DIR_IPKG}/CONTROL
SCRIPT_DIR_OUT=${SCRIPT_DIR_BASE}/out
SCRIPT_DIR_PATCHES=${SCRIPT_DIR_BASE}/patches
SCRIPT_DIR_IPK=${SCRIPT_DIR_BASE}/ipk

SCRIPT_FILE_INSTALLED=${SCRIPT_DIR_OUT}/installed_files.txt

if [ "$SCRIPT_CFG_OBNAM_VER" = "newest" ]; then
    SCRIPT_CFG_OBNAM_VER="1.7"
fi

case "$SCRIPT_CFG_OBNAM_VER" in
    1.7)
        OBNAM_LIW_DEPS="\
            http://code.liw.fi/debian/pool/main/p/python-cliapp/python-cliapp_1.20140315.orig.tar.gz \
            http://code.liw.fi/debian/pool/main/p/python-tracing/python-tracing_0.8.orig.tar.gz \
            http://code.liw.fi/debian/pool/main/p/python-larch/python-larch_1.20131130.orig.tar.gz \
            http://code.liw.fi/debian/pool/main/p/python-ttystatus/python-ttystatus_0.23.orig.tar.gz"

        OBNAM_LIW_SRC="http://code.liw.fi/debian/pool/main/o/obnam/obnam_1.7.orig.tar.gz"

        OBNAM_EXT_DEPS="\
            https://pypi.python.org/packages/source/p/paramiko/paramiko-1.13.0.tar.gz \
            https://pypi.python.org/packages/source/p/pycrypto/pycrypto-2.6.1.tar.gz"
        ;;
    1.6)
        OBNAM_LIW_DEPS="\
            http://code.liw.fi/debian/pool/main/p/python-cliapp/python-cliapp_1.20130808.orig.tar.gz \
            http://code.liw.fi/debian/pool/main/p/python-tracing/python-tracing_0.8.orig.tar.gz \
            http://code.liw.fi/debian/pool/main/p/python-larch/python-larch_1.20131130.orig.tar.gz \
            http://code.liw.fi/debian/pool/main/p/python-ttystatus/python-ttystatus_0.23.orig.tar.gz"

        OBNAM_LIW_SRC="http://code.liw.fi/debian/pool/main/o/obnam/obnam_1.6.1.orig.tar.gz"

        OBNAM_EXT_DEPS="\
            https://pypi.python.org/packages/source/p/paramiko/paramiko-1.12.2.tar.gz \
            https://pypi.python.org/packages/source/p/pycrypto/pycrypto-2.6.1.tar.gz"
        ;;
    1.5)
        OBNAM_LIW_DEPS="\
            http://code.liw.fi/debian/pool/main/p/python-cliapp/python-cliapp_1.20130808.orig.tar.gz \
            http://code.liw.fi/debian/pool/main/p/python-tracing/python-tracing_0.8.orig.tar.gz \
            http://code.liw.fi/debian/pool/main/p/python-larch/python-larch_1.20130808.orig.tar.gz \
            http://code.liw.fi/debian/pool/main/p/python-ttystatus/python-ttystatus_0.23.orig.tar.gz"

        OBNAM_LIW_SRC="http://code.liw.fi/debian/pool/main/o/obnam/obnam_1.5.orig.tar.gz"

        OBNAM_EXT_DEPS="\
            https://pypi.python.org/packages/source/p/paramiko/paramiko-1.11.0.tar.gz#md5=a2c55dc04904bd08d984533703177084 \
            https://pypi.python.org/packages/source/p/pycrypto/pycrypto-2.6.tar.gz#md5=88dad0a270d1fe83a39e0467a66a22bb"
        ;;
    1.4)
        OBNAM_LIW_DEPS="\
            http://code.liw.fi/debian/pool/main/p/python-cliapp/python-cliapp_1.20130313.orig.tar.gz \
            http://code.liw.fi/debian/pool/main/p/python-tracing/python-tracing_0.7.orig.tar.gz \
            http://code.liw.fi/debian/pool/main/p/python-larch/python-larch_1.20130316.orig.tar.gz \
            http://code.liw.fi/debian/pool/main/p/python-ttystatus/python-ttystatus_0.22.orig.tar.gz"

        OBNAM_LIW_SRC="http://code.liw.fi/debian/pool/main/o/obnam/obnam_1.4.orig.tar.gz"

        OBNAM_EXT_DEPS="\
            http://www.lag.net/paramiko/download/paramiko-1.7.7.1.zip \
            http://ftp.dlitz.net/pub/dlitz/crypto/pycrypto/pycrypto-2.6.tar.gz"
        ;;
    1.3)
        OBNAM_LIW_DEPS="\
            http://code.liw.fi/debian/pool/main/p/python-cliapp/python-cliapp_1.20120630.orig.tar.gz \
            http://code.liw.fi/debian/pool/main/p/python-tracing/python-tracing_0.6.orig.tar.gz \
            http://code.liw.fi/debian/pool/main/p/python-larch/python-larch_1.20120527.orig.tar.gz \
            http://code.liw.fi/debian/pool/main/p/python-ttystatus/python-ttystatus_0.19.orig.tar.gz"

        OBNAM_LIW_SRC="http://code.liw.fi/debian/pool/main/o/obnam/obnam_1.3.orig.tar.gz"

        OBNAM_EXT_DEPS="\
            http://www.lag.net/paramiko/download/paramiko-1.7.7.1.zip \
            http://ftp.dlitz.net/pub/dlitz/crypto/pycrypto/pycrypto-2.6.tar.gz"
        ;;
    *)
        echo "Obnam version \"$SCRIPT_CFG_OBNAM_VER\" not supported - aborting" 1>&2
        exit 1
        ;;
esac

obnam_get_deps()
{
    PKG_URL=$1
    PKG_BASENAME=$(basename ${PKG_URL})
    PKG_EXT=$(echo $PKG_BASENAME | awk -F . '{print $NF}')

    ${WGET} "$PKG_URL" -O "$SCRIPT_DIR_DEPS/$PKG_BASENAME" || exit 1
    case "$PKG_EXT" in
        gz)
            ${TAR} xvf "$SCRIPT_DIR_DEPS/$PKG_BASENAME" -C "$SCRIPT_DIR_DEPS" || exit 1
            ;;
        zip)
            ${UNZIP} "$SCRIPT_DIR_DEPS/$PKG_BASENAME" -d "$SCRIPT_DIR_DEPS" || exit 1
            ;;
        *)
            exit 1
            ;;
    esac

    for CUR_SETUP in $(find $SCRIPT_DIR_DEPS -name setup.py); do
        CUR_OLD_PWD="$PWD"
        CUR_SETUP_DIR=$(dirname $CUR_SETUP)
        CUR_SETUP_FILE=$(basename $CUR_SETUP)
        CUR_SETUP_FILE_LIST=${CUR_SETUP_DIR}/files.txt
        cd "$CUR_SETUP_DIR"
        ${PYTHON} ${CUR_SETUP_FILE} install --record ${CUR_SETUP_FILE_LIST} || exit 1
        cat ${CUR_SETUP_FILE_LIST} >> ${SCRIPT_FILE_INSTALLED}
        cd "$CUR_OLD_PWD"
    done
}

obnam_build()
{
    echo "Building Obnam $SCRIPT_CFG_OBNAM_VER"
    echo "Architecture: $SCRIPT_ARCH ($SCIPRT_ARCH_MACHINE)"

    ${MKDIR} -p ${SCRIPT_DIR_DEPS} || exit 1
    ${MKDIR} -p ${SCRIPT_DIR_OBNAM} || exit 1
    ${MKDIR} -p ${SCRIPT_DIR_IPKG_CONTROL} || exit 1
    ${MKDIR} -p ${SCRIPT_DIR_OUT} || exit 1

    if [ "$SCRIPT_CMD" = "install" -a -n "$SCRIPT_CFG_OBNAM_DEPS" ]; then
        
        # Remove old file list.
        rm ${SCRIPT_FILE_INSTALLED}
        
        echo "Installing dependencies ..."
        for CUR_FILE in ${OBNAM_LIW_DEPS}; do
            obnam_get_deps "$CUR_FILE"
        done

        echo "Installing external dependencies ..."
        for CUR_FILE in ${OBNAM_EXT_DEPS}; do
            obnam_get_deps "$CUR_FILE"
        done
    fi

    #
    # Get Obnam.
    #
    ${WGET} "$OBNAM_LIW_SRC" -O "$SCRIPT_DIR_OBNAM/$(basename $OBNAM_LIW_SRC)" || exit 1
    ${TAR} -C "$SCRIPT_DIR_OBNAM" -xvf "$SCRIPT_DIR_OBNAM/$(basename $OBNAM_LIW_SRC)" || exit 1
    OBNAM_FILE_SETUP=$(find $SCRIPT_DIR_OBNAM -name setup.py | head -n 1) || exit 1
    SCRIPT_DIR_OBNAM=$(dirname $OBNAM_FILE_SETUP) || exit 1

    #
    # Install pYAML -- not needed with Obnam 1.7+ anymore.
    #
    obnam_get_deps "https://pypi.python.org/packages/source/p/pyaml/pyaml-14.05.2.tar.gz"

    #
    # Apply patches.
    #
    if [ -z "$SCRIPT_CFG_NO_PATCHING" ]; then
        if [ -d "$SCRIPT_DIR_PATCHES/$SCRIPT_CFG_OBNAM_VER" ]; then
            echo "Applying patches ..."
            SCRIPT_PATCHES=$(find "$SCRIPT_DIR_PATCHES/$SCRIPT_CFG_OBNAM_VER" -name "*.patch") || exit 1
            for CUR_PATCH in "$SCRIPT_PATCHES"; do
                CUR_FILE="$SCRIPT_DIR_OBNAM/$(basename $CUR_PATCH .patch)"
                ${PATCH} "$CUR_FILE" "$CUR_PATCH" || exit 1
            done
        else
            echo "No patches for Obnam $SCRIPT_CFG_OBNAM_VER found, skipping ..."
        fi
    else
        echo "Patching skipped"
    fi

    #
    # Build Obnam.
    #
    echo "Building Obnam ..."

    CUR_DIR="$PWD"
    cd "$SCRIPT_DIR_OBNAM"
    CUR_SETUP_FILE_LIST=${SCRIPT_DIR_OBNAM}/file.txt
    ${PYTHON} setup.py bdist_dumb --keep-temp --bdist-dir "dist" --format=tar || exit 1
    cat ${CUR_SETUP_FILE_LIST} >> ${SCRIPT_FILE_INSTALLED}
    cd "$CUR_DIR"

    #
    # Build .ipk file.
    #
    SCRIPT_DIR_OBNAM_DIST=${SCRIPT_DIR_OBNAM}/dist
    ${RM} ${SCRIPT_DIR_OBNAM_DIST}/*.tar  || exit 1
    IPKG_FILE_DATA="$SCRIPT_DIR_IPKG/data.tar.gz"
    ${TAR} -C "$SCRIPT_DIR_OBNAM_DIST" -czf "$IPKG_FILE_DATA" . || exit 1

    echo "Obnam version: $SCRIPT_CFG_OBNAM_VER"

    IPKG_FLE_CONTROL_CONTENT="Package: obnam
Source: http://code.liw.fi/debian/pool/main/o/obnam/
Priority: optional
Section: python
Version: $SCRIPT_CFG_OBNAM_VER
Architecture: $SCRIPT_CFG_IPK_ARCH
Maintainer: Andreas Loeffler <andy@x86dev.com>
Homepage: http://liw.fi/obnam/
Depends: python27
Description: online and disk-based backup application
 Obnam makes backups. Backups can be stored on local hard disks, or online
 via the SSH SFTP protocol. The backup server, if used, does not require any
 special software, on top of SSH.

  * Snapshot backups. Every generation looks like a complete snapshot, so you
    don't need to care about full versus incremental backups, or rotate real
    or virtual tapes.
  * Data de-duplication, across files, and backup generations. If the backup
    repository already contains a particular chunk of data, it will be re-used,
    even if it was in another file in an older backup generation. This way, you
    don't need to worry about moving around large files, or modifying them.
  * Encrypted backups, using GnuPG.
  * Push or pull operation, depending on what you need. You can run Obnam on
    the client, and push backups to the server, or on the server, and pull
    from the client over SFTP.

 Obnam was developed by Lars Wirzenius (http://liw.fi/)
Suggests:
Conflicts:"

    ${CAT} > "$SCRIPT_DIR_IPKG_CONTROL/control" <<EOF
$IPKG_FLE_CONTROL_CONTENT
EOF

    # Create conffiles (not used yet).
    IPKG_FILE_CONFFILES="$SCRIPT_DIR_IPKG_CONTROL/conffiles"
    echo "" > "$IPKG_FILE_CONFFILES" || exit 1

    IPKG_FILE_CONTROL="$SCRIPT_DIR_IPKG/control.tar.gz"
    ${TAR} -C "$SCRIPT_DIR_IPKG_CONTROL" -czf "$IPKG_FILE_CONTROL" . || exit 1

    IPKG_FILE_DEBIAN_BINARY="$SCRIPT_DIR_IPKG/debian-binary"
    echo "2.0" > "$IPKG_FILE_DEBIAN_BINARY" || exit 1

    IPKG_OUTPUT="$SCRIPT_DIR_OUT/obnam-$SCRIPT_CFG_OBNAM_VER-$SCIPRT_ARCH_MACHINE.ipk"
    ${TAR} -C "$SCRIPT_DIR_IPKG" -czf "$IPKG_OUTPUT" \
        $(basename $IPKG_FILE_DEBIAN_BINARY) $(basename $IPKG_FILE_DATA) \
        $(basename $IPKG_FILE_CONTROL) \
        || exit 1

    if [ -z "$SCRIPT_CFG_NO_CLEANUP" ]; then
        ${RM} -rf "$SCRIPT_DIR_STAGING" || exit 1
    else
        echo "Skipping cleanup"
    fi

    echo "IPK package created: $IPKG_OUTPUT"
    return 0
}

obnam_remove()
{
    echo "Removing Obnam ..."
    CUR_FILE_LIST=${SCRIPT_FILE_INSTALLED}
    cat ${CUR_FILE_LIST} # | xargs rm -rf
}

## @todo Install cleanup trap handler.

case "$SCRIPT_CMD" in
    build|install)
        obnam_build
        ;;
    uninstall)
        obnam_remove
        ;;
    *)
        ;;
esac
