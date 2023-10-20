/* https://issues.dlang.org/show_bug.cgi?id=22976
 */

struct {
    void(*init)();
    void(*stringof)();
    void(*offsetof)();
    void(*mangleof)();
} *sp;

union {
    void(*init)();
    void(*stringof)();
    void(*offsetof)();
    void(*mangleof)();
} *up;

void fn()
{
    sp->init();
    sp->stringof();
    sp->offsetof();
    sp->mangleof();

    up->init();
    up->stringof();
    up->offsetof();
    sp->mangleof();
}

struct S { int alignof, mangleof; };
union U { int alignof, mangleof; };
enum E { alignof, mangleof };
