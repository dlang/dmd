/*
REQUIRED_ARGS: -HC -c -o-
PERMUTE_ARGS:
TEST_OUTPUT:
---
// Automatically generated by Digital Mars D Compiler v$n$

#pragma once

#include <stddef.h>
#include <stdint.h>


struct S;
struct S2;
class C;
class C2;

typedef int32_t T;

extern "C" int32_t x;

// ignored variable dtoh_AliasDeclaration.x
extern "C" int32_t foo(int32_t x);

// ignored function dtoh_AliasDeclaration.foo
extern int32_t foo2(int32_t x);

// ignored function dtoh_AliasDeclaration.foo2
struct S;

typedef S aliasS;

struct S2;

typedef S2 aliasS2;

// ignoring non-cpp class C
typedef C* aliasC;

class C2;

typedef C2* aliasC2;

typedef size_t(*F)(size_t x);

---
*/

alias T = int;

extern (C) int x;

alias u = x;

extern (C) int foo(int x)
{
    return x * 42;
}

alias fun = foo;

extern (C++) int foo2(int x)
{
    return x * 42;
}

alias fun2 = foo2;

extern (C) struct S;

alias aliasS = S;

extern (C++) struct S2;

alias aliasS2 = S2;

extern (C) class C;

alias aliasC = C;

extern (C++) class C2;

alias aliasC2 = C2;

alias F = size_t function (size_t x);
