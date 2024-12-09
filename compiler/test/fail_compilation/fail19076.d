/*
TEST_OUTPUT:
---
fail_compilation/fail19076.d(18): Error: no property `V` for type `fail19076.I`
auto F = __traits(getVirtualMethods, I, "V");
         ^
fail_compilation/fail19076.d(17):        interface `I` defined here
interface I : P { }
^
fail_compilation/fail19076.d(18): Error: `(I).V` cannot be resolved
auto F = __traits(getVirtualMethods, I, "V");
         ^
---
*/

interface P { }
interface I : P { }
auto F = __traits(getVirtualMethods, I, "V");
