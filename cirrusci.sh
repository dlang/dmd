#!/bin/bash
################################################################################
# Cirrus build script shared across DMD, DRuntime and Phobos
################################################################################
set -uexo pipefail

echo ">> Installing prerequisites"
if [ "$OS_NAME" == "linux" ]; then
  packages="git-core make g++ gdb curl libcurl3 tzdata zip unzip xz-utils"
  if [ "$MODEL" == "32" ]; then
    dpkg --add-architecture i386
    packages="$packages g++-multilib libcurl3-gnutls:i386"
  fi
  if [ "${DMD:0:4}" == "gdmd" ]; then
    packages="$packages sudo software-properties-common wget"
  fi
  apt-get -q update
  apt-get install -yq $packages
elif [ "$OS_NAME" == "darwin" ]; then
  # required for install.sh
  brew install gnupg
elif [ "$OS_NAME" == "freebsd" ]; then
  packages="git gmake bash"
  if [ "${D_VERSION:-x}" == "2.079.0" ] ; then
    packages="$packages lang/gcc9"
  fi
  pkg install -y $packages
  rm /usr/bin/make
  ln -s /usr/local/bin/gmake /usr/bin/make
fi
# create a `dmd` symlink to the repo dir, necessary for druntime/Phobos
ln -s "$CIRRUS_WORKING_DIR" ../dmd

################################################################################

echo ">> Install host compiler"
source ci.sh
# kludge
if [ "${DMD:0:4}" == "gdmd" ]; then export DMD="gdmd"; fi
if [ -z "${D_VERSION+x}" ]; then install_d "$DMD"; else install_d "$DMD-$D_VERSION"; fi

################################################################################

echo ">> Setup repositories"

export BRANCH=${CIRRUS_BASE_BRANCH:-$CIRRUS_BRANCH}
source ci.sh
setup_repos

################################################################################

echo ">> Build repositories"
build

################################################################################

echo ">> Test DMD"
test_dmd

################################################################################

echo ">> Test DRuntime"
make -j$N -C ../druntime -f posix.mak MODEL=$MODEL unittest

################################################################################

echo ">> Test Phobos"
make -j$N -C ../phobos -f posix.mak MODEL=$MODEL unittest
