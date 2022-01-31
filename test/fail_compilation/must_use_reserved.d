/+
TEST_OUTPUT:
---
fail_compilation/must_use_reserved.d(14): Error: `@mustUse` on `class` types is reserved for future use
fail_compilation/must_use_reserved.d(15): Error: `@mustUse` on `interface` types is reserved for future use
fail_compilation/must_use_reserved.d(16): Error: `@mustUse` on `enum` types is reserved for future use
fail_compilation/must_use_reserved.d(17): Error: `@mustUse` on functions is reserved for future use
fail_compilation/must_use_reserved.d(19): Error: `@mustUse` on `class` types is reserved for future use
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
