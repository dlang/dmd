# Shared functions between individual scripts

CURL_USER_AGENT="DMD-CI $(curl --version | head -n 1)"
DMD_DIR="$PWD"
N=$(($(nproc)+1))

clone() {
    local url="$1"
    local path="$2"
    local branch="$3"
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
}

download() {
    local url="$1"
    local path="$2"
    curl -fsSL -A "$CURL_USER_AGENT" --connect-timeout 5 --speed-time 30 --speed-limit 1024 --retry 5 --retry-delay 5 "$url" -o "$path"
}

install_grep() {
    local tools_dir="${DMD_DIR}/tools"
    mkdir -p "$tools_dir"
    cd "$tools_dir"
    download "http://downloads.dlang.org/other/grep-3.1.zip" "grep-3.1.zip"
    unzip "grep-3.1.zip" # contains grep.exe
    export PATH="${tools_dir}:$PATH"
}

################################################################################
# Download Grep
################################################################################

install_grep() {
    local tools_dir="${DMD_DIR}/tools"
    mkdir -p "$tools_dir"
    cd "$tools_dir"
    download "http://downloads.dlang.org/other/grep-3.1.zip" "grep-3.1.zip"
    unzip "grep-3.1.zip" # contains grep.exe
    export PATH="${tools_dir}:$PATH"
}

################################################################################
# Checkout other repositories
################################################################################

clone_repos() {
    local REPO_BRANCH="$SYSTEM_PULLREQUEST_TARGETBRANCH"

    for proj in druntime phobos; do
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

