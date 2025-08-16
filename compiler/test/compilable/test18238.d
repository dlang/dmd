// REQUIRED_ARGS: -preview=bitfields
// EXTRA_FILES: imports/imp18238.c
import imports.imp18238;

align(1)        // not packed
struct L18238
{
    long x : 8;
}

struct M18238
{
    align(1)    // not packed
    long x : 8;
}

version (Windows)
{
    static assert(A18238.sizeof == long.sizeof);
    static assert(A18238.alignof == long.alignof);

    static assert(B18238.sizeof == long.sizeof);
    static assert(B18238.alignof == 1);

    static assert(C18238.sizeof == long.sizeof);
    static assert(C18238.alignof == 1);

    static assert(D18238.sizeof == long.sizeof);
    static assert(D18238.alignof == 1);

    static assert(E18238.sizeof == long.sizeof);
    static assert(E18238.alignof == 1);

    static assert(F18238.sizeof == long.sizeof);
    static assert(F18238.alignof == 1);

    static assert(G18238.sizeof == long.sizeof);
    static assert(G18238.alignof == 1);

    static assert(H18238.sizeof == long.sizeof);
    static assert(H18238.alignof == 1);

    static assert(I18238.sizeof == long.sizeof);
    static assert(I18238.alignof == long.alignof);

    static assert(J18238.sizeof == long.sizeof);
    static assert(J18238.alignof == long.alignof);

    static assert(K18238.sizeof == long.sizeof);
    static assert(K18238.alignof == long.alignof);

    static assert(L18238.sizeof == long.sizeof);
    static assert(L18238.alignof == long.alignof);

    static assert(M18238.sizeof == long.sizeof);
    static assert(M18238.alignof == long.alignof);
}
else
{
    static assert(A18238.sizeof == long.sizeof);
    static assert(A18238.alignof == long.alignof);

    static assert(B18238.sizeof == 1);
    static assert(B18238.alignof == 1);

    static assert(C18238.sizeof == 1);
    static assert(C18238.alignof == 1);

    static assert(D18238.sizeof == 1);
    static assert(D18238.alignof == 1);

    static assert(E18238.sizeof == 1);
    static assert(E18238.alignof == 1);

    static assert(F18238.sizeof == 2);
    static assert(F18238.alignof == 2);

    static assert(G18238.sizeof == 4);
    static assert(G18238.alignof == 4);

    static assert(H18238.sizeof == long.sizeof);
    static assert(H18238.alignof == long.alignof);

    static assert(I18238.sizeof == long.sizeof);
    static assert(I18238.alignof == long.alignof);

    static assert(J18238.sizeof == long.sizeof);
    static assert(J18238.alignof == long.alignof);

    static assert(K18238.sizeof == long.sizeof);
    static assert(K18238.alignof == long.alignof);

    static assert(L18238.sizeof == long.sizeof);
    static assert(L18238.alignof == long.alignof);

    static assert(M18238.sizeof == long.sizeof);
    static assert(M18238.alignof == long.alignof);
}
