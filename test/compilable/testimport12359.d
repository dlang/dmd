// PERMUTE_ARGS: -o-
module a12359;

import imports.b12359 : isDigit1a;
int isDigit1a(char c) { return 1; }

//import imports.b12359 : isDigit1b;
//alias isDigit1b = imports.b12359.isDigit1b;
//int isDigit1b(char c) { return 1; }

import imports.b12359 : isDigit2a;
int isDigit2a(dchar c) { return 1; }

//import imports.b12359 : isDigit2b;
//alias isDigit2b = imports.b12359.isDigit2b;
//int isDigit2b(dchar c) { return 1; }

bool test()
{
    dchar d = 'a';
    char c = 'a';

    assert(isDigit1a(d) == 2);
    // head:    OK       (b.isDigit1a is called)
    // changed: still OK (b.isDigit1a is called), but deprecated
    // finally: error    (b.isDigit1a is not callable using argument types (char))

    //assert(isDigit1b(d) == 2);
    // continuously OK   (b.isDigit1a is called)

    assert(isDigit2a(c) == 2);
    // head:    OK       (b.isDigit2a was called)
    // changed: still OK (b.isDigit2a is called), but deprecated
    // finally: changed  (a.isDigit2a is callable usiing argument types (char))

    //assert(isDigit2b(c) == 2);
    // continuously OK   (b.isDigit1a is called)

    return true;
}
static assert(test());
