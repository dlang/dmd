#!/bin/bash

set -uexo pipefail

N=2

# use faster ld.gold linker on linux
if [ "$TRAVIS_OS_NAME" == "linux" ]; then
    mkdir linker
    ln -s /usr/bin/ld.gold linker/ld
    NM="nm --print-size"
    export PATH="$PWD/linker:$PATH"
else
    NM=nm
fi

# clone druntime and phobos
clone() {
    local url="$1"
    local path="$2"
    local branch="$3"
    for i in {0..4}; do
        if git clone --depth=1 --branch "$branch" "$url" "$path"; then
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
    make -j$N -C src -f posix.mak MODEL=$MODEL HOST_DMD=$DMD ENABLE_RELEASE=1 all
    make -j$N -C ../druntime -f posix.mak MODEL=$MODEL
    make -j$N -C ../phobos -f posix.mak MODEL=$MODEL
    deactivate # deactivate host compiler
}

# self-compile dmd
rebuild() {
    local build_path=generated/$TRAVIS_OS_NAME/release/$MODEL
    local compare=${1:-0}
    # `generated` gets cleaned in the next step, so we create another _generated
    # The nested folder hierarchy is needed to conform to those specified in
    # the generated dmd.conf
    mkdir -p _${build_path}
    cp $build_path/dmd _${build_path}/host_dmd
    cp $build_path/dmd.conf _${build_path}
    make -j$N -C src -f posix.mak MODEL=$MODEL HOST_DMD=../_${build_path}/host_dmd clean
    make -j$N -C src -f posix.mak MODEL=$MODEL HOST_DMD=../_${build_path}/host_dmd ENABLE_RELEASE=1 all

    # compare binaries to test reproducibile build
    if [ $compare -eq 1 ]; then
        if ! diff _${build_path}/host_dmd $build_path/dmd; then
            $NM _${build_path}/host_dmd > a
            $NM $build_path/dmd > b
            diff -u a b
            exit 1
        fi
    fi
}

# test druntime, phobos, dmd
test() {
    test_dub_package
    make -j$N -C ../druntime -f posix.mak MODEL=$MODEL unittest
    make -j$N -C ../phobos -f posix.mak MODEL=$MODEL unittest
    test_dmd
}

# test dmd
test_dmd() {
    # test fewer compiler argument permutations for PRs to reduce CI load
    if [ "$TRAVIS_PULL_REQUEST" == "false" ] && [ "$TRAVIS_OS_NAME" == "linux"  ]; then
        make -j$N -C test MODEL=$MODEL # all ARGS by default
    else
        make -j$N -C test MODEL=$MODEL ARGS="-O -inline -release"
    fi
}

# test dub package
test_dub_package() {
    source ~/dlang/*/activate # activate host compiler
    pushd test/dub_package
    dub --single --build=unittest parser.d
    popd
    deactivate
}

for proj in druntime phobos; do
    if [ $TRAVIS_BRANCH != master ] && [ $TRAVIS_BRANCH != stable ] &&
           ! git ls-remote --exit-code --heads https://github.com/dlang/$proj.git $TRAVIS_BRANCH > /dev/null; then
        # use master as fallback for other repos to test feature branches
        clone https://github.com/dlang/$proj.git ../$proj master
    else
        clone https://github.com/dlang/$proj.git ../$proj $TRAVIS_BRANCH
    fi
done

date
for step in build test rebuild "rebuild 1" test_dmd; do
    $step
    date
done
