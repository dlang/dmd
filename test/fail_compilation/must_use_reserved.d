/+
TEST_OUTPUT:
---
fail_compilation/must_use_reserved.d(14): Error: class `must_use_reserved.C` `@mustUse` on `class` types is reserved for future use
fail_compilation/must_use_reserved.d(15): Error: interface `must_use_reserved.I` `@mustUse` on `interface` types is reserved for future use
fail_compilation/must_use_reserved.d(16): Error: enum `must_use_reserved.E` `@mustUse` on `enum` types is reserved for future use
fail_compilation/must_use_reserved.d(17): Error: function `must_use_reserved.fun` `@mustUse` on functions is reserved for future use
fail_compilation/must_use_reserved.d(19): Error: class `must_use_reserved.CT!int.CT` `@mustUse` on `class` types is reserved for future use
fail_compilation/must_use_reserved.d(20): Error: template instance `must_use_reserved.CT!int` error instantiating
---
+/
import core.attribute;

@mustUse class C {}
@mustUse interface I {}
@mustUse enum E { x }
@mustUse int fun() { return 0; }

@mustUse class CT(T) {}
alias _ = CT!int;
