/*
TEST_OUTPUT:
---
// D import file generated from 'issue22342.d'
debug
{
	import core.stdc.stdio;
}
void main();
---
*/

// https://issues.dlang.org/show_bug.cgi?id=22342
// PERMUTE_ARGS:
// REQUIRED_ARGS: -H -o- -Hf=-

debug import core.stdc.stdio;
void main() { }
