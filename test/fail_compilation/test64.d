/*
TEST_OUTPUT:
---
fail_compilation/imports/test64a.d(1): Error: module `imports` from file fail_compilation/imports/test64a.d conflicts with package name imports
fail_compilation/test64.d(13): Deprecation: module `imports` from file fail_compilation/imports/test64a.d must be imported with 'import imports;'
---
*/

// PERMUTE_ARGS:

//import std.stdio;

import imports.test64a;

int main(string[] args)
{
    //writefln(file1);
    return 0;
}

