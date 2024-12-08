/*
REQUIRED_ARGS: -preview=systemVariables
TEST_OUTPUT:
---
fail_compilation/systemvariables.d(75): Error: cannot access `@system` variable `gInt` in @safe code
    gInt = 0; // error
    ^
fail_compilation/systemvariables.d(65):        `gInt` is declared here
@system int gInt;
            ^
fail_compilation/systemvariables.d(76): Error: cannot access `@system` variable `gInt` in @safe code
    gInt++; // error
    ^
fail_compilation/systemvariables.d(65):        `gInt` is declared here
@system int gInt;
            ^
fail_compilation/systemvariables.d(77): Error: cannot access `@system` variable `gArr` in @safe code
    gArr ~= 30; // error
    ^
fail_compilation/systemvariables.d(67):        `gArr` is declared here
@system { int[] gArr; }
                ^
fail_compilation/systemvariables.d(78): Error: cannot access `@system` variable `gArr` in @safe code
    const c = gArr[0]; // error
              ^
fail_compilation/systemvariables.d(67):        `gArr` is declared here
@system { int[] gArr; }
                ^
fail_compilation/systemvariables.d(79): Error: cannot access `@system` variable `gInt` in @safe code
    aliasToSys++; // error
    ^
fail_compilation/systemvariables.d(65):        `gInt` is declared here
@system int gInt;
            ^
fail_compilation/systemvariables.d(82): Error: cannot access `@system` variable `lSys` in @safe code
    lSys = 0; // error
    ^
fail_compilation/systemvariables.d(81):        `lSys` is declared here
    @system int lSys = 0;
                ^
fail_compilation/systemvariables.d(83): Error: cannot access `@system` variable `lSys` in @safe code
    increment(lSys); // error
              ^
fail_compilation/systemvariables.d(81):        `lSys` is declared here
    @system int lSys = 0;
                ^
fail_compilation/systemvariables.d(84): Error: cannot access `@system` variable `lSys` in @safe code
    incrementP(&lSys); // error
                ^
fail_compilation/systemvariables.d(81):        `lSys` is declared here
    @system int lSys = 0;
                ^
fail_compilation/systemvariables.d(86): Error: cannot access `@system` variable `eInt` in @safe code
    int a = eInt; // error
            ^
fail_compilation/systemvariables.d(66):        `eInt` is declared here
@system enum int eInt = 3;
                 ^
---
*/

// http://dlang.org/dips/1035


@system int gInt;
@system enum int eInt = 3;
@system { int[] gArr; }
alias aliasToSys = gInt;

void increment(ref int x) @safe { x++; }
void incrementP(int* x) @safe { (*x)++; }

void basic() @safe
{
    gInt = 0; // error
    gInt++; // error
    gArr ~= 30; // error
    const c = gArr[0]; // error
    aliasToSys++; // error

    @system int lSys = 0;
    lSys = 0; // error
    increment(lSys); // error
    incrementP(&lSys); // error

    int a = eInt; // error
    int b = typeof(eInt).max; // allowed

    void f() @trusted
    {
        lSys = 0; // allowed
    }
}
