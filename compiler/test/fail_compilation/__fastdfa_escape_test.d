// DO NOT RENAME THIS MODULE, name enables __FastDFAEscapeTest UDA

/*
REQUIRED_ARGS: -preview=fastdfa
TEST_OUTPUT:
---
fail_compilation/__fastdfa_escape_test.d(1006): Error: Parameter is required to be scope but escapes
fail_compilation/__fastdfa_escape_test.d(1006):        Escapes directly
fail_compilation/__fastdfa_escape_test.d(1014): Error: Escape of unknown lifetime via throw
fail_compilation/__fastdfa_escape_test.d(1013):        Pointer stored in variable `myEx` has potentially escaped
fail_compilation/__fastdfa_escape_test.d(1020): Error: Escape of unknown lifetime via throw
fail_compilation/__fastdfa_escape_test.d(1018):        Pointer stored in variable `e` has potentially escaped
fail_compilation/__fastdfa_escape_test.d(1032): Error: Stack variable stores a lifetime that exceeds its own
fail_compilation/__fastdfa_escape_test.d(1026):        For variable `ptr`
fail_compilation/__fastdfa_escape_test.d(1030):        A pointer to the cell of the variable `buf` has potentially escaped
fail_compilation/__fastdfa_escape_test.d(1040): Error: Stack variable exceeds its lifetime by being returned
fail_compilation/__fastdfa_escape_test.d(1038):        Pointer stored in variable `ptr` has potentially escaped
---
*/
module __fastdfa_escape_test;

struct __FastDFAEscapeTest {
    Param[] params;
}

struct Param {
    bool escapeIntoNothing;
    ulong escapeInto;

    this(bool escapeIntoNothing, ulong escapeInto) {
        this.escapeIntoNothing = escapeIntoNothing;
        this.escapeInto = escapeInto;
    }
}

struct Base {
    int* field;
}

enum Nothing = __FastDFAEscapeTest(null);
enum NoWhere001 = __FastDFAEscapeTest([Param(true, 0)]);
enum Returns001Ptr = __FastDFAEscapeTest([Param(false, 2)]);

#line 1000

//
//
//

@Returns001Ptr
int** argValueScopeReturnError(scope Base* base) @safe { // error
    return &base.field;
}

@Nothing
void unsafeThrowOfStack2()
{
    scope Exception myEx = new Exception("myText");
    throw myEx; // error
}

@NoWhere001
void unsafeThrowOfStack3(scope Exception e)
{
    throw e; // error
}

@Nothing
void trackEscape6()
{
    int* ptr;

    foreach (i; 0 .. 2)
    {
        int buf;
        ptr = &buf;
    } // error
} // no error

@Nothing
int* trackEscape9()
{
    scope int* ptr = new int;
    return ptr;
} // error
