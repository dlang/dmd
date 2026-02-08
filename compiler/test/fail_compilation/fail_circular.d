/*
TEST_OUTPUT:
---
fail_compilation/fail_circular.d(22): Error: circular reference to variable `fail_circular.a1`
fail_compilation/fail_circular.d(22):        while resolving `fail_circular.a1`
fail_compilation/fail_circular.d(23): Error: circular reference to variable `fail_circular.a2`
fail_compilation/fail_circular.d(23):        while resolving `fail_circular.a2`
fail_compilation/fail_circular.d(25): Error: circular reference to variable `fail_circular.b1`
fail_compilation/fail_circular.d(25):        while resolving `fail_circular.b1`
fail_compilation/fail_circular.d(26): Error: circular reference to variable `fail_circular.b2`
fail_compilation/fail_circular.d(26):        while resolving `fail_circular.b2`
fail_compilation/fail_circular.d(28): Error: circular reference to variable `fail_circular.c1`
fail_compilation/fail_circular.d(28):        while resolving `fail_circular.c1`
fail_compilation/fail_circular.d(29): Error: circular reference to variable `fail_circular.c2`
fail_compilation/fail_circular.d(29):        while resolving `fail_circular.c2`
fail_compilation/fail_circular.d(31): Error: circular initialization of variable `fail_circular.d1`
fail_compilation/fail_circular.d(32): Error: circular initialization of variable `fail_circular.d2`
fail_compilation/fail_circular.d(34): Error: circular initialization of variable `fail_circular.e1`
fail_compilation/fail_circular.d(35): Error: circular initialization of variable `fail_circular.e2`
---
*/
auto a1 =  a1;          // semantic error (cannot determine expression type)
auto a2 = .a2;          // semantic error

const b1 =  b1;         // semantic error
const b2 = .b2;         // semantic error

enum c1 =  c1;          // semantic error
enum c2 = .c2;          // semantic error

const int d1 =  d1;     // CTFE error (expression type is determined to int)
const int d2 = .d2;     // CTFE error

enum int e1 =  e1;      // CTFE error
enum int e2 = .e2;      // CTFE error

/*
TEST_OUTPUT:
---
fail_compilation/fail_circular.d(65): Error: circular reference to variable `fail_circular.a1a`
fail_compilation/fail_circular.d(65):        while resolving `fail_circular.a1b`
fail_compilation/fail_circular.d(64):        while resolving `fail_circular.a1a`
fail_compilation/fail_circular.d(67): Error: circular reference to variable `fail_circular.a2a`
fail_compilation/fail_circular.d(67):        while resolving `fail_circular.a2b`
fail_compilation/fail_circular.d(66):        while resolving `fail_circular.a2a`
fail_compilation/fail_circular.d(70): Error: circular reference to variable `fail_circular.b1a`
fail_compilation/fail_circular.d(70):        while resolving `fail_circular.b1b`
fail_compilation/fail_circular.d(69):        while resolving `fail_circular.b1a`
fail_compilation/fail_circular.d(72): Error: circular reference to variable `fail_circular.b2a`
fail_compilation/fail_circular.d(72):        while resolving `fail_circular.b2b`
fail_compilation/fail_circular.d(71):        while resolving `fail_circular.b2a`
fail_compilation/fail_circular.d(75): Error: circular reference to variable `fail_circular.c1a`
fail_compilation/fail_circular.d(75):        while resolving `fail_circular.c1b`
fail_compilation/fail_circular.d(74):        while resolving `fail_circular.c1a`
fail_compilation/fail_circular.d(77): Error: circular reference to variable `fail_circular.c2a`
fail_compilation/fail_circular.d(77):        while resolving `fail_circular.c2b`
fail_compilation/fail_circular.d(76):        while resolving `fail_circular.c2a`
fail_compilation/fail_circular.d(80): Error: circular initialization of variable `fail_circular.d1a`
fail_compilation/fail_circular.d(82): Error: circular initialization of variable `fail_circular.d2a`
fail_compilation/fail_circular.d(85): Error: circular initialization of variable `fail_circular.e1a`
fail_compilation/fail_circular.d(87): Error: circular initialization of variable `fail_circular.e2a`
---
*/
auto a1a =  a1b;
auto a1b =  a1a;        // semantic error
auto a2a =  a2b;
auto a2b = .a2a;        // semantic error

const b1a =  b1b;
const b1b =  b1a;       // semantic error
const b2a =  b2b;
const b2b = .b2a;       // semantic error

enum c1a =  c1b;
enum c1b =  c1a;        // semantic error
enum c2a =  c2b;
enum c2b = .c2a;        // semantic error

const int d1a =  d1b;
const int d1b =  d1a;   // CTFE error
const int d2a =  d2b;
const int d2b = .d2a;   // CTFE error

enum int e1a =  e1b;
enum int e1b =  e1a;    // CTFE error
enum int e2a =  e2b;
enum int e2b = .e2a;    // CTFE error

/*
TEST_OUTPUT:
---
fail_compilation/fail_circular.d(102): Error: circular reference to variable `fail_circular.S1.a1`
fail_compilation/fail_circular.d(106): Error: circular reference to variable `fail_circular.S2.b1`
fail_compilation/fail_circular.d(110): Error: circular reference to variable `fail_circular.S3.c1`
fail_compilation/fail_circular.d(115): Error: circular reference to variable `fail_circular.S4.a1a`
fail_compilation/fail_circular.d(120): Error: circular reference to variable `fail_circular.S5.b1a`
fail_compilation/fail_circular.d(125): Error: circular reference to variable `fail_circular.S6.c1a`
---
*/
struct S1
{
    static a1 = S1.a1;          // semantic error
}
struct S2
{
    static const b1 = S2.b1;     // semantic error
}
struct S3
{
    enum c1 = S3.c1;             // semantic error
}
struct S4
{
    static a1a = S4.a1b;
    static a1b = S4.a1a;         // semantic error
}
struct S5
{
    static const b1a = S5.b1b;
    static const b1b = S5.b1a;   // semantic error
}
struct S6
{
    enum c1a = S6.c1b;
    enum c1b = S6.c1a;           // semantic error
}

/*
TEST_OUTPUT:
---
fail_compilation/fail_circular.d(144): Error: circular reference to variable `fail_circular.C.a1`
fail_compilation/fail_circular.d(146): Error: circular reference to variable `fail_circular.C.b1`
fail_compilation/fail_circular.d(148): Error: circular reference to variable `fail_circular.C.c1`
fail_compilation/fail_circular.d(151): Error: circular reference to variable `fail_circular.C.a1a`
fail_compilation/fail_circular.d(150): Error: type of variable `fail_circular.C.a1b` has errors
fail_compilation/fail_circular.d(154): Error: circular reference to variable `fail_circular.C.b1a`
fail_compilation/fail_circular.d(153): Error: type of variable `fail_circular.C.b1b` has errors
fail_compilation/fail_circular.d(157): Error: circular reference to variable `fail_circular.C.c1a`
fail_compilation/fail_circular.d(156): Error: type of variable `fail_circular.C.c1b` has errors
---
*/
class C
{
    static a1 = C.a1;           // semantic error

    static const b1 = C.b1;     // semantic error

    enum c1 = C.c1;             // semantic error

    static a1a = C.a1b;
    static a1b = C.a1a;         // semantic error

    static const b1a = C.b1b;
    static const b1b = C.b1a;   // semantic error

    enum c1a = C.c1b;
    enum c1b = C.c1a;           // semantic error
}
