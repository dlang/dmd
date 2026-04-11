/**
REQUIRED_ARGS: -ftime-trace -ftime-trace-file=- -ftime-trace-granularity=0 -inline
TRANSFORM_OUTPUT: sanitize_timetrace
TEST_OUTPUT:
---
Code generation,
Codegen: function add, object.add
Codegen: function uses, object.uses
Codegen: module object, object
Import object.object, object.object
Inline: add, object.add
Inline: uses, object.uses
Inlining,
Parse: Module object, object
Parsing,
Sema1: Function add, object.add
Sema1: Function uses, object.uses
Sema1: Module object, object
Sema2: add, object.add
Sema2: uses, object.uses
Sema3: add, object.add
Sema3: uses, object.uses
Semantic analysis,
---
*/

module object; // Don't clutter time trace output with object.d

int add(int x, int y)
{
    return x + y;
}

void uses()
{
    int a = add(1, 2);
}
