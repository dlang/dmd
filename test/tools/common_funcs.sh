# rm with retry
# Useful to workaround a race condition on windows when removing executables
# that were just running.
function rm_retry {
    local attempt=1
    for true; do
        rm -f $@ && break
        if [ $attempt -ge 4 ]; then
            return 1
        fi
        let attempt=attempt+=1
        sleep 1
    done
    return 0
}
