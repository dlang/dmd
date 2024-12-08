/+
TEST_OUTPUT:
---
fail_compilation/must_use_reserved.d(26): Error: `@mustuse` on `class` types is reserved for future use
@mustuse class C {}
         ^
fail_compilation/must_use_reserved.d(27): Error: `@mustuse` on `interface` types is reserved for future use
@mustuse interface I {}
         ^
fail_compilation/must_use_reserved.d(28): Error: `@mustuse` on `enum` types is reserved for future use
@mustuse enum E { x }
         ^
fail_compilation/must_use_reserved.d(29): Error: `@mustuse` on functions is reserved for future use
@mustuse int fun() { return 0; }
             ^
fail_compilation/must_use_reserved.d(31): Error: `@mustuse` on `class` types is reserved for future use
@mustuse class CT(T) {}
         ^
fail_compilation/must_use_reserved.d(32): Error: template instance `must_use_reserved.CT!int` error instantiating
alias _ = CT!int;
          ^
---
+/
import core.attribute;

@mustuse class C {}
@mustuse interface I {}
@mustuse enum E { x }
@mustuse int fun() { return 0; }

@mustuse class CT(T) {}
alias _ = CT!int;
