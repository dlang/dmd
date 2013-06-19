/*
TEST_OUTPUT:
---
Error: module imports from file fail_compilation/imports/test64a.d conflicts with package name imports
---
*/

// PERMUTE_ARGS:

import std.stdio;

import imports.test64a;

int main(char[][] args)
{
    writefln(file1);
    return 0;
}

