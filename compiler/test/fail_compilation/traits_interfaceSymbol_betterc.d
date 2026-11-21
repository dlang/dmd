/*
REQUIRED_ARGS: -betterC
TEST_OUTPUT:
---
fail_compilation/traits_interfaceSymbol_betterc.d(12): Error: __traits(interfaceSymbol) needs the ClassInfo of class `traits_interfaceSymbol_betterc.C`, which is not generated
---
*/

extern(C++) interface I {}
extern(C++) class C : I {}

enum i = __traits(interfaceSymbol, C);
