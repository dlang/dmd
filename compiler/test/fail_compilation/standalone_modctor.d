/**
TEST_OUTPUT:
---
fail_compilation/standalone_modctor.d(17): Error: `@standalone` can only be used on shared static constructors
@standalone        static this() {}
 ^
fail_compilation/standalone_modctor.d(18): Error: a module constructor using `@standalone` must be `@system` or `@trusted`
@standalone shared static this() {}
 ^
fail_compilation/standalone_modctor.d(19): Error: a module constructor using `@standalone` must be `@system` or `@trusted`
@standalone shared static this() @safe {}
 ^
---
*/
import core.attribute : standalone;

@standalone        static this() {}
@standalone shared static this() {}
@standalone shared static this() @safe {}
@standalone shared static this() @trusted {}
@standalone shared static this() @system {}
