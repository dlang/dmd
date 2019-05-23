# rm with retry
# Useful to workaround a race condition on windows when removing executables
# that were just running.
function rm_retry {
    local attempt=1
    for true; do
        rm $@ && break
        if [ $attempt -ge 4 ]; then
            return 1
        fi
        attempt+=1
        sleep 1
    done
    return 0
}
