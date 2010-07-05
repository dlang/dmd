// EXTRA_SOURCES: imports/Other.d
// PERMUTE_ARGS:

module Same; // makes no difference if removed
import std.c.stdio;
class Same
{
this()
{
printf("Same\n");
}
}
