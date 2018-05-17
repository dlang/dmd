// REQUIRED_ARGS: -c -o- -Hf${RESULTS_DIR}/compilable/header18365.di
// POST_SCRIPT: compilable/extra-files/header-postscript.sh
struct FullCaseEntry
{
    dchar[3] seq;
    ubyte n, size;
    ubyte entry_len;

    @property auto value() const @trusted pure nothrow @nogc return
    {
        return seq[0 .. entry_len];
    }
}
