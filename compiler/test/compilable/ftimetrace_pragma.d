/**
REQUIRED_ARGS: -ftime-trace -ftime-trace-file=- -ftime-trace-granularity=0
TRANSFORM_OUTPUT: sanitize_timetrace
TEST_OUTPUT:
---
Code generation,
Codegen: function cube, object.cube
Codegen: function square, object.square
Codegen: function uses, object.uses
Codegen: module object, object
Import object.object, object.object
Inline: cube, object.cube
Inline: uses, object.uses
Inlining,
Parse: Module object, object
Parsing,
Sema1: Function cube, object.cube
Sema1: Function square, object.square
Sema1: Function uses, object.uses
Sema1: Module object, object
Sema2: cube, object.cube
Sema2: square, object.square
Sema2: uses, object.uses
Sema3: cube, object.cube
Sema3: square, object.square
Sema3: uses, object.uses
Semantic analysis,
---
*/

module object; // Don't clutter time trace output with object.d

pragma(inline, true)
int square(int x) { return x * x; }

pragma(inline, true)
int cube(int x) { return x * square(x); }

void uses()
{
    int a = cube(3);
    int b = square(4);
}
