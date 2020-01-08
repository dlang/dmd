// REQUIRED_ARGS: -transition=safe
/*
TEST_OUTPUT:
---
compilable/transitionSafe.d(15): function `transitionSafe.pointers` is implicitly `@system` but not marked as `@system`
compilable/transitionSafe.d(27): function `transitionSafe.implicitUnsafe` is implicitly `@system` but not marked as `@system`
---
*/

extern(C) void main() @safe
{
    call();
}

void pointers()
{
    int* ip = cast(int*) (void*).init;
    char* cp = cast(char*) 2;
    ip++;
}

void implicitSafe()
{
    call();
}

void implicitUnsafe()
{
    pointers();
}

void unions() @system
{
    static union U {
        int a;
        int* b;
    }
    *U.init.b = 2;
}

void call() @trusted
{
    pointers();
    catchThrowable();
    inlineAsm();
    qualifiers();
}

void catchThrowable()()
{
    try {}
    catch (Throwable) {}

    int* ptr = cast(int*) 2;
}

void inlineAsm()() @system
{
    asm {
        nop;
    }
}

void qualifiers()() @trusted
{
    immutable int* imip;
    int* mip = cast(int*) imip;
    shared(int)* sip = cast(shared) mip;
    mip = cast(int*) sip;
}
