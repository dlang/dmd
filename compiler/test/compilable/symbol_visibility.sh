#!/usr/bin/env bash
set -euo pipefail

case "$OS" in
    linux|freebsd|openbsd|dragonflybsd|solaris) command -v readelf >/dev/null || exit 0 ;;
    osx) ;;
    *) exit 0 ;;
esac

objfile="${OUTPUT_BASE}${OBJ}"
symbols="${OUTPUT_BASE}.symbols"

check_symbol()
{
    local name="$1" visibility="$2"
    if [[ "$OS" == osx ]]; then
        if [[ "$visibility" == HIDDEN ]]; then
            grep -E "private external .*_?${name}$" "$symbols" >/dev/null
        else
            grep -E " external .*_?${name}$" "$symbols" | grep -v 'private external' >/dev/null
        fi
    else
        awk -v name="$name" -v visibility="$visibility" '
            $NF ~ name "$" && $6 == visibility { found = 1 }
            END { exit !found }
        ' "$symbols"
    fi || { echo "Expected $visibility visibility for $name"; cat "$symbols"; exit 1; }
}

for mode in implicit default public hidden; do
    flags=()
    [[ "$mode" == implicit ]] || flags+=("-visibility=$mode")
    $DMD -c -fPIC -I"${EXTRA_FILES}" -m${MODEL} "${flags[@]}" -of"$objfile" "${EXTRA_FILES}/${TEST_NAME}.d"
    if [[ "$OS" == osx ]]; then
        nm -m "$objfile" > "$symbols"
    else
        readelf -Ws "$objfile" > "$symbols"
    fi
    ordinary=DEFAULT
    [[ "$mode" != hidden ]] || ordinary=HIDDEN
    for name in ordinaryFunction ordinaryData ordinaryBSS ordinaryTLS ordinaryHiddenName; do
        check_symbol "$name" "$ordinary"
    done
    for name in exportedFunction exportedData exportedBSS exportedTLS hiddenExportedFunction hiddenExportedData ordinaryExternal; do
        check_symbol "$name" DEFAULT
    done
    for name in hiddenFunction hiddenData hiddenBSS hiddenTLS hiddenExternal blockHidden tupleHidden colonHidden; do
        check_symbol "$name" HIDDEN
    done
    # Template names are D-mangled, so match their identifiers and suffixes.
    check_symbol 'ordinaryTemplate.*' "$ordinary"
    check_symbol 'hiddenTemplate.*' HIDDEN
    if [[ "$OS" == linux ]]; then
        # Inspect the actual dynamic symbol table as well as relocatable objects.
        provider="${OUTPUT_BASE}_provider${OBJ}"
        library="${OUTPUT_BASE}.so"
        $DMD -c -betterC -fPIC -m${MODEL} -of"$provider" "${EXTRA_FILES}/${TEST_NAME}_provider.d"
        $DMD -c -betterC -fPIC -I"${EXTRA_FILES}" -m${MODEL} "${flags[@]}" -of"$objfile" "${EXTRA_FILES}/${TEST_NAME}.d"
        cc -m${MODEL} -shared -nostdlib -o "$library" "$objfile" "$provider"
        readelf --dyn-syms -W "$library" > "$symbols"
        check_symbol exportedFunction DEFAULT
        check_symbol exportedData DEFAULT
        check_symbol exportedBSS DEFAULT
        check_symbol exportedTLS DEFAULT
        check_symbol hiddenExportedFunction DEFAULT
        check_symbol hiddenExportedData DEFAULT
        if [[ "$mode" != hidden ]]; then
            check_symbol ordinaryFunction DEFAULT
            check_symbol ordinaryData DEFAULT
        fi
        if awk '$NF ~ /^(hiddenFunction|hiddenData|hiddenBSS|hiddenTLS|hiddenExternal)$/ { found = 1 }
                END { exit !found }' "$symbols"; then
            echo "Hidden symbols leaked into the dynamic symbol table"
            exit 1
        fi
        if [[ "$mode" == hidden ]] && awk '$NF ~ /^ordinary(Function|Data|BSS|TLS)$/ { found = 1 }
                END { exit !found }' "$symbols"; then
            echo "-visibility=hidden symbols leaked into the dynamic symbol table"
            exit 1
        fi
        rm_retry "$provider" "$library"
    fi
done

rm_retry "$objfile" "$symbols"
