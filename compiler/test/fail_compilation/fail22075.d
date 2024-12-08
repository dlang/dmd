// https://issues.dlang.org/show_bug.cgi?id=22075

/*
TEST_OUTPUT:
---
fail_compilation/fail22075.d(29): Error: AA key type `S` should have `extern (D) size_t toHash() const nothrow @safe` if `opEquals` defined
int[S!HasAliasThis] aa1; // Compiles but should not.
                    ^
fail_compilation/fail22075.d(30): Error: AA key type `S` should have `extern (D) size_t toHash() const nothrow @safe` if `opEquals` defined
int[S!LacksAliasThis] aa2; // Correctly fails to compile with "Error: AA key
                      ^
---
*/

struct HasAliasThis { int a; alias a this; }

struct LacksAliasThis { int a; }

struct S(T)
{
    private T a;

    bool opEquals(const S rhs) const @nogc nothrow @safe
    {
        return rhs is this;
    }
}

int[S!HasAliasThis] aa1; // Compiles but should not.
int[S!LacksAliasThis] aa2; // Correctly fails to compile with "Error: AA key
     // type `S` should have `extern (D) size_t toHash() const nothrow @safe`
     // if `opEquals` defined"".

void main() {}
