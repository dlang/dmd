# Regression test: ld rejects a Mach-O archive whose members are not 8-byte
# aligned ("ld: 64-bit mach-o member 'x' not 8-byte aligned"), so `dmd -lib`
# must align every member. Only the Mach-O archive writer is affected.
[[ "$OS" == "osx" ]] || exit 0

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# The first member is placed right after the symbol table: 8 (archive magic) +
# 60 (member header) + the symbol table size. That size depends on the symbol
# names, and each iteration below makes the unused symbol one byte longer, so
# the eight iterations walk through every possible remainder mod 8. With the
# old 4-byte rounding, half of those remainders end up at 4, which ld rejects.
for k in 1 2 3 4 5 6 7 8; do
    pad=$(printf "%${k}s" "" | tr ' ' p)
    cat > "$tmp/lib.d" <<EOF
extern (C) int foo() { return 42; }
extern (C) __gshared int $pad;
EOF
    "$DMD" -lib -of="$tmp/lib.a" "$tmp/lib.d"

    # size field of the first member (__.SYMDEF) is at offset 8 + 48
    symsize=$(dd if="$tmp/lib.a" bs=1 skip=56 count=10 2>/dev/null | tr -dc '0-9')
    offset=$((8 + 60 + symsize))
    if (( offset % 8 != 0 )); then
        echo "lib.d: first archive member at offset $offset is not 8-byte aligned" >&2
        exit 1
    fi
done

# The resulting archive must also actually link.
cat > "$tmp/prog.d" <<'EOF'
extern (C) int foo();
void main() { assert(foo() == 42); }
EOF
"$DMD" "$tmp/prog.d" "$tmp/lib.a" -of="$tmp/prog"
"$tmp/prog"
