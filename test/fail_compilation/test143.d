// REQUIRED_ARGS: -de
module test143; // https://issues.dlang.org/show_bug.cgi?id=143

import imports.test143;

void bar(int)
{
}

void foo()
{
    bar(x);
}
