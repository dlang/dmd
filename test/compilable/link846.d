/*
Build library with -release
EXTRA_ARTIFACT: lib846${LIBEXT} = ${DMD} -of=$@ -release -boundscheck=off -lib compilable/imports/lib846.d

Use lib with -debug
REQUIRED_ARGS: -debug $@[0]
LINK:
*/

import imports.lib846;

void main()
{
    auto num = removeIf("abcdef".dup, (char c){ return c == 'c'; });
}
