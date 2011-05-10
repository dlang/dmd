// EXTRA_SOURCES: imports/circularA.d

// Bugzilla 4543

import std.c.stdio;
import imports.circularA;

class bclass {};
typedef bclass Tclass;

struct bstruct {}
typedef bstruct Tstruct;


/************************************/

int main()
{
    printf("Success\n");
    return 0;
}

