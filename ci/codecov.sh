#!/usr/bin/env bash
set -euox pipefail

# Uploads coverage reports to CodeCov

# Check whether this script was called on it's own
if [[ "${CURL_USER_AGENT:-}" == "" ]]
then
    CI_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
    source "$CI_DIR/../.azure-pipelines/lib.sh"
fi

# CodeCov gets confused by lst files which it can't match
rm -rf test/runnable/extra-files \
    test/*.lst \
    ./*test_results-runner.lst \
    __main.lst

# Save the file from URL passed as $1 to the location in $2
doCurl()
{
    curl -fsSL -A "$CURL_USER_AGENT" --connect-timeout 5 --speed-time 30 --speed-limit 1024 --retry 5 --retry-delay 5 "$1" -o "$2"
}

# Determine the correct uploader + url + arguments
UPLOADER="codecov"
UPLOADER_OS="$OS_NAME"
UPLOADER_ARGS=""

case "$UPLOADER_OS" in

    windows)
        UPLOADER="$UPLOADER.exe"
    ;;

    darwin | osx)
        UPLOADER_OS="macos"
    ;;

    # No FreeBSD support for the new uploader (yet?)
    freebsd)
        doCurl "https://codecov.io/bash" "codecov.sh"
        bash ./codecov.sh -p . -Z
        rm codecov.sh
        return 0
    ;;
esac

# Determine the host name
for file in "$UPLOADER" "$UPLOADER.SHA256SUM" "$UPLOADER.SHA256SUM.sig"
do
    doCurl "https://uploader.codecov.io/latest/$UPLOADER_OS/$file" "$file"
done

# Obtain the key if missing
if ! gpg --list-keys ED779869
then
    echo "Importing CodeCov key..."
    doCurl "https://keybase.io/codecovsecurity/pgp_keys.asc" "pgp_keys.asc"
    gpg --import pgp_keys.asc
    rm pgp_keys.asc
fi

# Verify the uploader
gpg --verify "$UPLOADER.SHA256SUM.sig" "$UPLOADER.SHA256SUM"
shasum -a 256 -c "$UPLOADER.SHA256SUM"

# Remove signature files as the uploader apparently includes them...
rm $UPLOADER.*

# Upload the sources
chmod +x "$UPLOADER"
"./$UPLOADER" -p . -Z $UPLOADER_ARGS

rm "$UPLOADER"
