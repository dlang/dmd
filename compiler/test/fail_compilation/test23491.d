/**
REQUIRED_ARGS: -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/test23491.d(16): Error: reference to local variable `buffer` assigned to non-scope anonymous parameter is not allowed in a `@safe` function
fail_compilation/test23491.d(17): Error: assigning reference to local variable `buffer` to non-scope anonymous parameter calling `sinkF` is not allowed in a `@safe` function
fail_compilation/test23491.d(18): Error: assigning reference to local variable `buffer` to non-scope parameter `buf` is not allowed in a `@safe` function
---
*/

void sinkF(char[]) @safe;

void toString(void delegate (char[]) @safe sink, void delegate(char[] buf) @safe sinkNamed) @safe
{
    char[20] buffer = void;
    sink(buffer[]);
	sinkF(buffer[]);
	sinkNamed(buffer[]);
}
