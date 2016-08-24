// REQUIRED_ARGS: -transition=import
// PERMUTE_ARGS:
import imports.imp15907;

struct S
{
    private int a;
}

static assert(allMembers!S == ["a"]);
