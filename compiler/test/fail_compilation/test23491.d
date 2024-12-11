/**
REQUIRED_ARGS: -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/test23491.d(22): Error: reference to local variable `buffer` assigned to non-scope anonymous parameter
    sink(buffer[]);
               ^
fail_compilation/test23491.d(23): Error: reference to local variable `buffer` assigned to non-scope anonymous parameter calling `sinkF`
	sinkF(buffer[]);
             ^
fail_compilation/test23491.d(24): Error: reference to local variable `buffer` assigned to non-scope parameter `buf`
	sinkNamed(buffer[]);
                 ^
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
