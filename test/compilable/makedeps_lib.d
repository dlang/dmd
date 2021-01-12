/**
DISABLED: win
REQUIRED_ARGS: -makedeps -Jcompilable/extra-files -lib
LINK:
TRANSFORM_OUTPUT: remove_lines(druntime)
TEST_OUTPUT:
---
$r:.*makedeps_lib_$0.$?:windows=lib|a$: \
  $p:makedeps_lib.d$ \
  $p:imports/makedeps_a.d$ \
  $p:makedeps-import.txt$ \
---
**/
// Disabling on windows because default naming of -lib seems broken (names to .exe)
module makedeps_lib;

// Test import statement
import imports.makedeps_a;

// Test import expression
enum text = import("makedeps-import.txt");
static assert(text == "Imported text");

void func()
{
    a_func();
}
