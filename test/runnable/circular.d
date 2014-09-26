// REQUIRED_ARGS: -d
// PERMUTE_ARGS: -dw
// EXTRA_SOURCES: imports/circularA.d
// This bug is typedef-specific.

// Bugzilla 4543

import std.c.stdio;
import imports.circularA;

class bclass {};
alias bclass Tclass;

struct bstruct {}
alias bstruct Tstruct;


/************************************/

int main()
{
    printf("Success\n");
    return 0;
}

