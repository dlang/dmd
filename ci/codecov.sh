#!/usr/bin/env bash

# Uploads coverage reports to CodeCov

# CodeCov gets confused by lst files which it can't match
rm -rf test/runnable/extra-files test/*.lst

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
        # -C workaround proposed in https://github.com/codecov/codecov-bash/issues/287
        UPLOADER_ARGS="-C \"$BUILD_SOURCEVERSION\""

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

# Upload the sources
chmod +x "$UPLOADER"
"./$UPLOADER" -p . -Z $UPLOADER_ARGS

rm codecov*
