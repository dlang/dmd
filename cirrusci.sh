#!/usr/bin/env bash

# Installs the OS-specific prerequisites for Cirrus CI jobs.
# This file is invoked by DMD, druntime and Phobos' .cirrus.yml
# and sets up the machine for the later steps with ci.sh.

set -uexo pipefail

# OS_NAME: linux|darwin|freebsd
if [ -z ${OS_NAME+x} ] ; then echo "Variable 'OS_NAME' needs to be set."; exit 1; fi
# MODEL: 32|64
if [ -z ${MODEL+x} ] ; then echo "Variable 'MODEL' needs to be set."; exit 1; fi
# HOST_DC: dmd[-<version>]|ldc[-<version>]|gdmd-<version>
if [ -z ${HOST_DC+x} ] ; then echo "Variable 'HOST_DC' needs to be set."; exit 1; fi

if [ "$OS_NAME" == "linux" ]; then
  packages="git-core make g++ gdb curl libcurl3 tzdata zip unzip xz-utils"
  if [ "$MODEL" == "32" ]; then
    dpkg --add-architecture i386
    packages="$packages g++-multilib libcurl3-gnutls:i386"
  fi
  if [ "${HOST_DC:0:4}" == "gdmd" ]; then
    # ci.sh uses `sudo add-apt-repository ...` to add a PPA repo
    packages="$packages sudo software-properties-common"
  fi
  apt-get -q update
  apt-get install -yq $packages
elif [ "$OS_NAME" == "darwin" ]; then
  # required for dlang install.sh
  brew install gnupg
elif [ "$OS_NAME" == "freebsd" ]; then
  packages="git gmake"
  if [ "$HOST_DC" == "dmd-2.079.0" ] ; then
    packages="$packages lang/gcc9"
  fi
  pkg install -y $packages
  # replace default make by GNU make
  rm /usr/bin/make
  ln -s /usr/local/bin/gmake /usr/bin/make
fi
