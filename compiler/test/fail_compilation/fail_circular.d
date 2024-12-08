/*
TEST_OUTPUT:
---
fail_compilation/fail_circular.d(111): Error: circular reference to variable `fail_circular.a1`
auto a1 =  a1;          // semantic error (cannot determine expression type)
           ^
fail_compilation/fail_circular.d(112): Error: circular reference to variable `fail_circular.a2`
auto a2 = .a2;          // semantic error
          ^
fail_compilation/fail_circular.d(114): Error: circular reference to variable `fail_circular.b1`
const b1 =  b1;         // semantic error
            ^
fail_compilation/fail_circular.d(115): Error: circular reference to variable `fail_circular.b2`
const b2 = .b2;         // semantic error
           ^
fail_compilation/fail_circular.d(117): Error: circular reference to variable `fail_circular.c1`
enum c1 =  c1;          // semantic error
           ^
fail_compilation/fail_circular.d(118): Error: circular reference to variable `fail_circular.c2`
enum c2 = .c2;          // semantic error
          ^
fail_compilation/fail_circular.d(120): Error: circular initialization of variable `fail_circular.d1`
const int d1 =  d1;     // CTFE error (expression type is determined to int)
                ^
fail_compilation/fail_circular.d(121): Error: circular initialization of variable `fail_circular.d2`
const int d2 = .d2;     // CTFE error
               ^
fail_compilation/fail_circular.d(123): Error: circular initialization of variable `fail_circular.e1`
enum int e1 =  e1;      // CTFE error
               ^
fail_compilation/fail_circular.d(124): Error: circular initialization of variable `fail_circular.e2`
enum int e2 = .e2;      // CTFE error
              ^
fail_compilation/fail_circular.d(127): Error: circular reference to variable `fail_circular.a1a`
auto a1b =  a1a;        // semantic error
            ^
fail_compilation/fail_circular.d(129): Error: circular reference to variable `fail_circular.a2a`
auto a2b = .a2a;        // semantic error
           ^
fail_compilation/fail_circular.d(132): Error: circular reference to variable `fail_circular.b1a`
const b1b =  b1a;       // semantic error
             ^
fail_compilation/fail_circular.d(134): Error: circular reference to variable `fail_circular.b2a`
const b2b = .b2a;       // semantic error
            ^
fail_compilation/fail_circular.d(137): Error: circular reference to variable `fail_circular.c1a`
enum c1b =  c1a;        // semantic error
            ^
fail_compilation/fail_circular.d(139): Error: circular reference to variable `fail_circular.c2a`
enum c2b = .c2a;        // semantic error
           ^
fail_compilation/fail_circular.d(142): Error: circular initialization of variable `fail_circular.d1a`
const int d1b =  d1a;   // CTFE error
                 ^
fail_compilation/fail_circular.d(144): Error: circular initialization of variable `fail_circular.d2a`
const int d2b = .d2a;   // CTFE error
                ^
fail_compilation/fail_circular.d(147): Error: circular initialization of variable `fail_circular.e1a`
enum int e1b =  e1a;    // CTFE error
                ^
fail_compilation/fail_circular.d(149): Error: circular initialization of variable `fail_circular.e2a`
enum int e2b = .e2a;    // CTFE error
               ^
fail_compilation/fail_circular.d(153): Error: circular reference to variable `fail_circular.S1.a1`
    static a1 = S1.a1;          // semantic error
                ^
fail_compilation/fail_circular.d(157): Error: circular reference to variable `fail_circular.S2.b1`
    static const b1 = S2.b1;     // semantic error
                      ^
fail_compilation/fail_circular.d(161): Error: circular reference to variable `fail_circular.S3.c1`
    enum c1 = S3.c1;             // semantic error
              ^
fail_compilation/fail_circular.d(166): Error: circular reference to variable `fail_circular.S4.a1a`
    static a1b = S4.a1a;         // semantic error
                 ^
fail_compilation/fail_circular.d(171): Error: circular reference to variable `fail_circular.S5.b1a`
    static const b1b = S5.b1a;   // semantic error
                       ^
fail_compilation/fail_circular.d(176): Error: circular reference to variable `fail_circular.S6.c1a`
    enum c1b = S6.c1a;           // semantic error
               ^
fail_compilation/fail_circular.d(181): Error: circular reference to variable `fail_circular.C.a1`
    static a1 = C.a1;           // semantic error
                ^
fail_compilation/fail_circular.d(183): Error: circular reference to variable `fail_circular.C.b1`
    static const b1 = C.b1;     // semantic error
                      ^
fail_compilation/fail_circular.d(185): Error: circular reference to variable `fail_circular.C.c1`
    enum c1 = C.c1;             // semantic error
              ^
fail_compilation/fail_circular.d(188): Error: circular reference to variable `fail_circular.C.a1a`
    static a1b = C.a1a;         // semantic error
                 ^
fail_compilation/fail_circular.d(187): Error: type of variable `fail_circular.C.a1b` has errors
    static a1a = C.a1b;
                 ^
fail_compilation/fail_circular.d(191): Error: circular reference to variable `fail_circular.C.b1a`
    static const b1b = C.b1a;   // semantic error
                       ^
fail_compilation/fail_circular.d(190): Error: type of variable `fail_circular.C.b1b` has errors
    static const b1a = C.b1b;
                       ^
fail_compilation/fail_circular.d(194): Error: circular reference to variable `fail_circular.C.c1a`
    enum c1b = C.c1a;           // semantic error
               ^
fail_compilation/fail_circular.d(193): Error: type of variable `fail_circular.C.c1b` has errors
    enum c1a = C.c1b;
               ^
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
