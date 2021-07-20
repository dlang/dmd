/*
TEST_OUTPUT:
----
fail_compilation/issue12652.d(21): Error: Associative array literals currently cannot be initialized globally, in structs or in classes; try using 'enum' or a module constructor instead
---
*/

import std.range;
import std.stdio;
import std.traits;

enum A
{
    x,
    y,
    z
}

struct S
{
    string[A] t = [A.x : "aaa", A.y : "bbb"];
}

void main ()
{
    S s;
}