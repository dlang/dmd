/**
REQUIRED_ARGS: -makedeps -Jcompilable/extra-files
TRANSFORM_OUTPUT: remove_lines(druntime)
TEST_OUTPUT:
---
$r:.*makedeps_obj_$0.o$?:windows=bj$: \
  $p:makedeps_obj.d$ \
  $p:makedeps_a.d$ \
  $p:makedeps-import-codemixin.txt$ \
  $p:makedeps-import.txt$ \
---
**/
module makedeps_obj;

// Test import statement
import imports.makedeps_a;

// Test mixin import expression
enum text = import("makedeps-import-codemixin.txt");
mixin(text);
static assert(text2 == "Imported text");

void func()
{
    a_func();
}
