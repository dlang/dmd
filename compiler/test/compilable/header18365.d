/*
REQUIRED_ARGS: -c -o- -Hf${RESULTS_DIR}/compilable/header18365.di
PERMUTE_ARGS:
OUTPUT_FILES: ${RESULTS_DIR}/compilable/header18365.di

TEST_OUTPUT:
---
=== ${RESULTS_DIR}/compilable/header18365.di
// D import file generated from 'compilable/header18365.d'
struct FullCaseEntry
{
	dchar[3] seq;
	ubyte n;
	ubyte size;
	ubyte entry_len;
	@property const(dchar)[] value() const pure nothrow @nogc return @trusted
	{
		return this.seq[0..cast(ulong)this.entry_len];
	}
}
---
*/

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
