/**
TEST_OUTPUT:
---
fail_compilation/standalone_modctor.d(11): Error: `@__standalone` can only be used on shared static constructors
fail_compilation/standalone_modctor.d(12): Error: a module constructor using `@__standalone` must be `@system` or `@trusted`
fail_compilation/standalone_modctor.d(13): Error: a module constructor using `@__standalone` must be `@system` or `@trusted`
---
*/
import core.attribute : __standalone;

@__standalone        static this() {}
@__standalone shared static this() {}
@__standalone shared static this() @safe {}
@__standalone shared static this() @trusted {}
@__standalone shared static this() @system {}
