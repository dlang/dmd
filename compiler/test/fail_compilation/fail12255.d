/*
TEST_OUTPUT:
---
fail_compilation/fail12255.d(77): Error: AA key type `SC1` does not have `bool opEquals(ref const SC1) const`
    int[SC1] c1;    // NG
             ^
fail_compilation/fail12255.d(78): Error: AA key type `SC2` does not support const equality
    int[SC2] c2;    // NG
             ^
fail_compilation/fail12255.d(83): Error: AA key type `SD1` should have `extern (D) size_t toHash() const nothrow @safe` if `opEquals` defined
    int[SD1] d1;    // NG
             ^
fail_compilation/fail12255.d(84): Error: AA key type `SD2` supports const equality but doesn't support const hashing
    int[SD2] d2;    // NG
             ^
fail_compilation/fail12255.d(88): Error: AA key type `SE1` should have `extern (D) size_t toHash() const nothrow @safe` if `opEquals` defined
    int[SE1] e1;    // NG
             ^
fail_compilation/fail12255.d(89): Error: AA key type `SE2` supports const equality but doesn't support const hashing
    int[SE2] e2;    // NG
             ^
fail_compilation/fail12255.d(145): Error: bottom of AA key type `SC1` does not have `bool opEquals(ref const SC1) const`
    int[SC1[1]] c1;    // NG
                ^
fail_compilation/fail12255.d(146): Error: bottom of AA key type `SC2` does not support const equality
    int[SC2[1]] c2;    // NG
                ^
fail_compilation/fail12255.d(147): Error: bottom of AA key type `SD1` should have `extern (D) size_t toHash() const nothrow @safe` if `opEquals` defined
    int[SD1[1]] d1;    // NG
                ^
fail_compilation/fail12255.d(148): Error: bottom of AA key type `SD2` supports const equality but doesn't support const hashing
    int[SD2[1]] d2;    // NG
                ^
fail_compilation/fail12255.d(149): Error: bottom of AA key type `SE1` should have `extern (D) size_t toHash() const nothrow @safe` if `opEquals` defined
    int[SE1[1]] e1;    // NG
                ^
fail_compilation/fail12255.d(150): Error: bottom of AA key type `SE2` supports const equality but doesn't support const hashing
    int[SE2[1]] e2;    // NG
                ^
fail_compilation/fail12255.d(159): Error: bottom of AA key type `SC1` does not have `bool opEquals(ref const SC1) const`
    int[SC1[]] c1;    // NG
               ^
fail_compilation/fail12255.d(160): Error: bottom of AA key type `SC2` does not support const equality
    int[SC2[]] c2;    // NG
               ^
fail_compilation/fail12255.d(161): Error: bottom of AA key type `SD1` should have `extern (D) size_t toHash() const nothrow @safe` if `opEquals` defined
    int[SD1[]] d1;    // NG
               ^
fail_compilation/fail12255.d(162): Error: bottom of AA key type `SD2` supports const equality but doesn't support const hashing
    int[SD2[]] d2;    // NG
               ^
fail_compilation/fail12255.d(163): Error: bottom of AA key type `SE1` should have `extern (D) size_t toHash() const nothrow @safe` if `opEquals` defined
    int[SE1[]] e1;    // NG
               ^
fail_compilation/fail12255.d(164): Error: bottom of AA key type `SE2` supports const equality but doesn't support const hashing
    int[SE2[]] e2;    // NG
               ^
---
*/

void main()
{
    /* Key comparison and hashing are based on object bit representation,
     * and they fully supported in runtime (TypeInfo.equals and TypeInfo.getHash)
     */
    int[SA1] a1;    // OK
    int[SA2] a2;    // OK

    /* If only toHash is defined, AA assumes that is customized object hashing.
     */
    int[SB1] b1;    // OK
    int[SB2] b2;    // OK

    /* If key does not support const equality,
     * it is disallowed, because TypeInfo.equals will throw Error.
     */
    int[SC1] c1;    // NG
    int[SC2] c2;    // NG

    /* If opEquals defined for const equality, corresponding toHash method
     * is required to guarantee (a != b || a.toHash() == b.toHash()).
     */
    int[SD1] d1;    // NG
    int[SD2] d2;    // NG

    /* same as SD cases
     */
    int[SE1] e1;    // NG
    int[SE2] e2;    // NG
}

struct SA1 { int val; }
struct SA2 { SA1 s; }

struct SB1
{
    // AA assumes this is specialized hashing (?)
    size_t toHash() const nothrow @safe { return 0; }
}
struct SB2
{
    SB1 s;
    // implicit generated toHash() calls s.toHash().
}

struct SC1
{
    // does not support const equality
    bool opEquals(typeof(this)) /*const*/ { return true; }
}
struct SC2
{
    SC1 s;
}

struct SD1
{
    // Supports const equality, but
    // does not have corresponding toHash()
    bool opEquals(typeof(this)) const { return true; }
}
struct SD2
{
    SD1 s;
}

struct SE1
{
    // Supports const equality, but
    // does not have corresponding valid toHash()
    bool opEquals(typeof(this)) const { return true; }
    size_t toHash() @system { return 0; }
}
struct SE2
{
    SE1 s;
}

void testSArray()
{
    int[SA1[1]] a1;    // OK
    int[SA2[1]] a2;    // OK
    int[SB1[1]] b1;    // OK
    int[SB2[1]] b2;    // OK
    int[SC1[1]] c1;    // NG
    int[SC2[1]] c2;    // NG
    int[SD1[1]] d1;    // NG
    int[SD2[1]] d2;    // NG
    int[SE1[1]] e1;    // NG
    int[SE2[1]] e2;    // NG
}

void testDArray()
{
    int[SA1[]] a1;    // OK
    int[SA2[]] a2;    // OK
    int[SB1[]] b1;    // OK
    int[SB2[]] b2;    // OK
    int[SC1[]] c1;    // NG
    int[SC2[]] c2;    // NG
    int[SD1[]] d1;    // NG
    int[SD2[]] d2;    // NG
    int[SE1[]] e1;    // NG
    int[SE2[]] e2;    // NG
}
