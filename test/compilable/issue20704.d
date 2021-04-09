/*
https://issues.dlang.org/show_bug.cgi?id=20704
REQUIRED_ARGS: -preview=rvaluerefparam
 */

void foo (T) (const auto ref T arg = T.init) {}
void bar (T) (const      ref T arg = T.init) {}

void main ()
{
    int i;
    foo!int();
    bar!int(i);
}
