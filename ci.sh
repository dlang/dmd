#!/usr/bin/env bash

set -uexo pipefail

if [ -z ${N+x} ] ; then echo "Variable 'N' needs to be set."; exit 1; fi
if [ -z ${OS_NAME+x} ] ; then echo "Variable 'OS_NAME' needs to be set."; exit 1; fi
if [ -z ${FULL_BUILD+x} ] ; then echo "Variable 'FULL_BUILD' needs to be set."; exit 1; fi
if [ -z ${MODEL+x} ] ; then echo "Variable 'MODEL' needs to be set."; exit 1; fi
if [ -z ${DMD+x} ] ; then echo "Variable 'DMD' needs to be set."; exit 1; fi

CURL_USER_AGENT="DMD-CI $(curl --version | head -n 1)"
build_path=generated/$OS_NAME/release/$MODEL

# use faster ld.gold linker on linux
if [ "$OS_NAME" == "linux" ]; then
    mkdir -p linker
    rm -f linker/ld
    ln -s /usr/bin/ld.gold linker/ld
    NM="nm --print-size"
    export PATH="$PWD/linker:$PATH"
else
    NM=nm
fi

# clone a repo
clone() {
    local url="$1"
    local path="$2"
    local branch="$3"
    for i in {0..4}; do
        if git clone --depth=1 --branch "$branch" "$url" "$path" --quiet; then
            break
        elif [ $i -lt 4 ]; then
            sleep $((1 << $i))
        else
            echo "Failed to clone: ${url}"
            exit 1
        fi
    done
}

# build dmd, druntime, phobos
build() {
    source ~/dlang/*/activate # activate host compiler
    make -j$N -C src -f posix.mak MODEL=$MODEL HOST_DMD=$DMD ENABLE_RELEASE=1 ENABLE_WARNINGS=1 all
    make -j$N -C ../druntime -f posix.mak MODEL=$MODEL
    make -j$N -C ../phobos -f posix.mak MODEL=$MODEL
    deactivate # deactivate host compiler
}

# self-compile dmd
rebuild() {
    local compare=${1:-0}
    # `generated` gets cleaned in the next step, so we create another _generated
    # The nested folder hierarchy is needed to conform to those specified in
    # the generated dmd.conf
    mkdir -p _${build_path}
    cp $build_path/dmd _${build_path}/host_dmd
    cp $build_path/dmd.conf _${build_path}
    make -j$N -C src -f posix.mak MODEL=$MODEL HOST_DMD=../_${build_path}/host_dmd clean
    make -j$N -C src -f posix.mak MODEL=$MODEL HOST_DMD=../_${build_path}/host_dmd ENABLE_RELEASE=1 ENABLE_WARNINGS=1 all

    # compare binaries to test reproducible build
    if [ $compare -eq 1 ]; then
        if ! diff _${build_path}/host_dmd $build_path/dmd; then
            $NM _${build_path}/host_dmd > a
            $NM $build_path/dmd > b
            diff -u a b
            echo "Self-compilation failed: generated dmd created a different binary than host dmd!"
            exit 1
        fi
    fi
}

# test druntime, phobos, dmd
test() {
    test_dub_package
    test_druntime
    test_phobos
    test_dmd
}

# test dmd
test_dmd() {
    # test fewer compiler argument permutations for PRs to reduce CI load
    if [ "$FULL_BUILD" == "true" ] && [ "$OS_NAME" == "linux"  ]; then
        make -j1 -C test auto-tester-test MODEL=$MODEL N=$N # all ARGS by default
    else
        make -j1 -C test auto-tester-test MODEL=$MODEL N=$N ARGS="-O -inline -release"
    fi
}

test_druntime() {
    make -j$N -C ../druntime -f posix.mak MODEL=$MODEL unittest
}

test_phobos() {
    make -j$N -C ../phobos -f posix.mak MODEL=$MODEL unittest
}

# test dub package
test_dub_package() {
    source ~/dlang/*/activate # activate host compiler
    # GDC's standard library is too old for some example scripts
    if [[ "${DMD:-dmd}" =~ "gdmd" ]] ; then
        echo "Skipping DUB examples on GDC."
    else
        local abs_build_path="$PWD/$build_path"
        pushd test/dub_package
        for file in *.d ; do
            dubcmd=""
            # running impvisitor is failing right now
            if [ "$(basename "$file")" == "impvisitor.d" ]; then
                dubcmd="build"
            fi
            # build with host compiler
            dub $dubcmd --single "$file"
            # build with built compiler (~master)
            DFLAGS="-de" dub $dubcmd --single --compiler="${abs_build_path}/dmd" "$file"
        done
        popd
        # Test rdmd build
        "${build_path}/dmd" -version=NoBackend -version=GC -version=NoMain -Jgenerated/dub -Jsrc/dmd/res -Isrc -i -run test/dub_package/frontend.d
    fi
    deactivate
}

# clone druntime/phobos repos if not already available
setup_repos() {
    if [ -z ${BRANCH+x} ] ; then echo "Variable 'BRANCH' needs to be set."; exit 1; fi
    for proj in druntime phobos; do
        if [ ! -d ../$proj ]; then
            if [ $BRANCH != master ] && [ $BRANCH != stable ] &&
                   ! git ls-remote --exit-code --heads https://github.com/dlang/$proj.git $BRANCH > /dev/null; then
                # use master as fallback for other repos to test feature branches
                clone https://github.com/dlang/$proj.git ../$proj master
            else
                clone https://github.com/dlang/$proj.git ../$proj $BRANCH
            fi
        fi
    done
}

testsuite() {
    date
    for step in build test rebuild "rebuild 1" test_dmd; do
        $step
        date
    done
}

download_install_sh() {
  local mirrors location
  location="${1:-install.sh}"
  mirrors=(
    "https://dlang.org/install.sh"
    "https://downloads.dlang.org/other/install.sh"
    "https://nightlies.dlang.org/install.sh"
    "https://raw.githubusercontent.com/dlang/installer/master/script/install.sh"
  )
  if [ -f "$location" ] ; then
      return
  fi
  for i in {0..4}; do
    for mirror in "${mirrors[@]}" ; do
        if curl -fsS -A "$CURL_USER_AGENT" --connect-timeout 5 --speed-time 30 --speed-limit 1024 "$mirror" -o "$location" ; then
            break 2
        fi
    done
    sleep $((1 << i))
  done
}

install_d() {
  if [ "${DMD:-dmd}" == "gdc" ] || [ "${DMD:-dmd}" == "gdmd" ] ; then
    export DMD=gdmd-${GDC_VERSION}
    if [ ! -e ~/dlang/gdc-${GDC_VERSION}/activate ] ; then
        sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
        sudo apt-get update
        sudo apt-get install -y gdc-${GDC_VERSION}
        # fetch the dmd-like wrapper
        sudo wget https://raw.githubusercontent.com/D-Programming-GDC/GDMD/master/dmd-script -O /usr/bin/gdmd-${GDC_VERSION}
        sudo chmod +x /usr/bin/gdmd-${GDC_VERSION}
        # fake install script and create a fake 'activate' script
        mkdir -p ~/dlang/gdc-${GDC_VERSION}
        echo "deactivate(){ echo;}" > ~/dlang/gdc-${GDC_VERSION}/activate
    fi
  else
    local install_sh="install.sh"
    download_install_sh "$install_sh"
    CURL_USER_AGENT="$CURL_USER_AGENT" bash "$install_sh" "$1"
  fi
}

# Define commands

if [ "$#" -gt 0 ]; then
  case $1 in
    install_d) install_d "$2" ;;
    setup_repos) setup_repos ;;
    build) build ;;
    rebuild) rebuild "${2:-}" ;;
    test) test ;;
    test_dmd) test_dmd ;;
    test_druntime) test_druntime ;;
    test_phobos) test_phobos ;;
    test_dub_package) test_dub_package ;;
    testsuite) testsuite ;;
    *) echo "Unknown command: $1" >&2; exit 1 ;;
  esac
fi
