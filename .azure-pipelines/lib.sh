# Shared functions between individual scripts

CURL_USER_AGENT="DMD-CI $(curl --version | head -n 1)"
DMD_DIR="$PWD"
N=$(nproc)

clone() {
    local url="$1"
    local path="$2"
    local branch="$3"
    if [ ! -d $path ]; then
        for i in {0..4}; do
            if git clone --depth 1 --branch "$branch" "$url" "$path" "${@:4}" --quiet; then
                break
            elif [ $i -lt 4 ]; then
                sleep $((1 << $i))
            else
                echo "Failed to clone: ${url}"
                exit 1
            fi
        done
    fi
}

download() {
    local url="$1"
    local path="$2"
    curl -fsSL -A "$CURL_USER_AGENT" --retry 5 --retry-max-time 120  --connect-timeout 5 --speed-time 30 --speed-limit 1024 "$url" -o "$path"
}

################################################################################
# Download dmd
################################################################################

install_host_dmd() {
    if [ ! -f dmd2/README.TXT ]; then
        download "https://downloads.dlang.org/releases/2.x/${HOST_DMD_VERSION}/dmd.${HOST_DMD_VERSION}.windows.7z" dmd2.7z
        7z x dmd2.7z > /dev/null
        download "https://downloads.dlang.org/other/libcurl-7.65.3-2-WinSSL-zlib-x86-x64.zip" libcurl.zip
        7z -y x libcurl.zip > /dev/null
    fi
    export PATH="$PWD/dmd2/windows/bin/:$PATH"
    export HOST_DC="$PWD/dmd2/windows/bin/dmd.exe"
    dmd --version
}

################################################################################
# Download dmc
################################################################################

install_host_dmc() {
    if [ ! -f dm/README.TXT ]; then
        download "https://downloads.dlang.org/other/dm857c.zip" dmc.zip
        7z x dmc.zip > /dev/null
        download "http://ftp.digitalmars.com/sppn.zip" sppn.zip
        7z x -odm/bin sppn.zip > /dev/null
    fi
    dm/bin/dmc | head -n 1 || true
}

################################################################################
# Download Grep
################################################################################

install_grep() {
    local tools_dir="${DMD_DIR}/tools"
    mkdir -p "$tools_dir"
    cd "$tools_dir"
    if [ ! -f grep.exe ]; then
        download "https://downloads.dlang.org/other/grep-3.1.zip" "grep-3.1.zip"
        unzip "grep-3.1.zip" # contains grep.exe
    fi
    export PATH="${tools_dir}:$PATH"
}

################################################################################
# Checkout other repositories
################################################################################

clone_repos() {
    if [ -z ${SYSTEM_PULLREQUEST_TARGETBRANCH+x} ]; then
        # no PR
        local REPO_BRANCH="$BUILD_SOURCEBRANCHNAME"
    elif [ ${SYSTEM_PULLREQUEST_ISFORK} == False ]; then
        # PR originating from the official dlang repo
        local REPO_BRANCH="$SYSTEM_PULLREQUEST_SOURCEBRANCH"
    else
        # PR from a fork
        local REPO_BRANCH="$SYSTEM_PULLREQUEST_TARGETBRANCH"
    fi

    for proj in phobos; do
        if [ "$REPO_BRANCH" != master ] && [ "$REPO_BRANCH" != stable ] &&
                ! git ls-remote --exit-code --heads "https://github.com/dlang/$proj.git" "$REPO_BRANCH" > /dev/null; then
            # use master as fallback for other repos to test feature branches
            clone "https://github.com/dlang/$proj.git" "${DMD_DIR}/../$proj" master
            echo "[GIT_CLONE] Switched $proj to branch master \$(REPO_BRANCH=$REPO_BRANCH)"
        else
            clone "https://github.com/dlang/$proj.git" "${DMD_DIR}/../$proj" "$REPO_BRANCH"
            echo "[GIT_CLONE] Switched $proj to branch $REPO_BRANCH"
        fi
    done
}
