#!/bin/sh

set -e -v

clone() {
    local url="$1"
    local path="$2"
    local branch="$3"
    for i in {0..4}; do
        if git clone --branch "$branch" "$url" "$path" "${@:4}" --quiet; then
            break
        elif [ $i -lt 4 ]; then
            sleep $((1 << $i))
        else
            echo "Failed to clone: ${url}"
            exit 1
        fi
    done
}

echo "C_COMPILER: $C_COMPILER"
echo "D_COMPILER: $D_COMPILER"
echo "D_VERSION: $D_VERSION"

cd /c/projects/

if [ ! -f "gnumake/make.exe" ]; then
    mkdir gnumake
    cd gnumake

    appveyor DownloadFile "https://ftp.gnu.org/gnu/make/make-4.2.tar.gz" -FileName make.tar.gz

    7z x make.tar.gz -so | 7z x -si -ttar > /dev/null
    cd make-4.2

    # usr/bin/link overriding VS's link.exe, give priority to VS's in PATH
    export PATH="/c/Program Files (x86)/Microsoft Visual Studio 14.0/VC/bin/amd64/:$PATH"
    ./build_w32.bat > /dev/null

    cp WinRel/gnumake.exe ../make.exe
    cd ../..

    gnumake/make.exe --version
fi

if [ $D_COMPILER == "dmd" ]; then
    #appveyor DownloadFile "http://downloads.dlang.org/releases/2.x/${D_VERSION}/dmd.${D_VERSION}.windows.7z" -FileName dmd2.7z
    appveyor DownloadFile "http://nightlies.dlang.org/dmd-master-2017-12-22/dmd.master.windows.7z" -FileName dmd2.7z
    7z x dmd2.7z > /dev/null
    export PATH=$PWD/dmd2/windows/bin/:$PATH
    export DMD=/c/projects/dmd2/windows/bin/dmd.exe
    dmd --version
fi

for proj in druntime phobos; do
    if [ $APPVEYOR_REPO_BRANCH != master ] && [ $APPVEYOR_REPO_BRANCH != stable ] &&
            ! git ls-remote --exit-code --heads https://github.com/dlang/$proj.git $APPVEYOR_REPO_BRANCH > /dev/null; then
        # use master as fallback for other repos to test feature branches
        clone https://github.com/dlang/$proj.git $proj master
        echo "+++ Switched $proj to branch master (APPVEYOR_REPO_BRANCH=$APPVEYOR_REPO_BRANCH)"
    else
        clone https://github.com/dlang/$proj.git $proj $APPVEYOR_REPO_BRANCH
        echo "+++ Switched $proj to branch $APPVEYOR_REPO_BRANCH"
    fi
done

# build via makefile
cd /c/projects/dmd/src
make -f win64.mak reldmd DMD=../src/dmd

cd /c/projects/druntime
make -f win64.mak DMD=../dmd/src/dmd

cd /c/projects/phobos
make -f win64.mak DMD=../dmd/src/dmd

cp /c/projects/phobos/phobos64.lib /c/projects/dmd/

export OS="Win_64"
export CC='c:/"Program Files (x86)"/"Microsoft Visual Studio 14.0"/VC/bin/amd64/cl.exe'
export MODEL="64"
export MODEL_FLAG="-m64"

cd /c/projects/dmd/test
../../gnumake/make -j3 all MODEL=$MODEL ARGS="-O -inline -g" MODEL_FLAG=$MODEL_FLAG LIB="../../phobos;$LIB"
