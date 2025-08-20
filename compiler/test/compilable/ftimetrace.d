/**
REQUIRED_ARGS: -ftime-trace -ftime-trace-file=- -ftime-trace-granularity=0
TRANSFORM_OUTPUT: sanitize_timetrace
TEST_OUTPUT:
---
Code generation,
Codegen: function add, object.add
Codegen: function fun, object.fun
Codegen: function id, object.id!int.id
Codegen: function uses, object.uses
Codegen: module object, object
Ctfe: add(4, 8), add(4, 8)
Ctfe: call add, object.add(4, 8)
Import object.object, object.object
Parse: Module object, object
Parsing,
Sema1: Function add, object.add
Sema1: Function fun, object.fun
Sema1: Function id, object.id!int.id
Sema1: Function uses, object.uses
Sema1: Module object, object
Sema1: Template Declaration id(T)(T t), object.id(T)(T t)
Sema1: Template Instance id!int, object.id!int
Sema2: add, object.add
Sema2: fun, object.fun
Sema2: id, object.id!int.id
Sema2: uses, object.uses
Sema3: add, object.add
Sema3: fun, object.fun
Sema3: id, object.id!int.id
Sema3: uses, object.uses
Semantic analysis,
---
*/

module object; // Don't clutter time trace output with object.d

void fun()
{
    enum z = add(4, 8);
}

int add(int x, int y)
{
    return x + y;
}

T id(T)(T t) { return T.init; }

void uses()
{
    int a = id!int(42);
}
