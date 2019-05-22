# rm with retry
function rm_retry {
    local attempt=1
    for true; do
        rm $@ && break
        attempt+=1
        if [ $attempt -ge 4 ]; then
            return 1
        fi
        sleep 1
    done
}
