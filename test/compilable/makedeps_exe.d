/**
REQUIRED_ARGS: -makedeps -Jcompilable/extra-files
EXTRA_SOURCES: imports/makedeps_a.d
LINK:
TRANSFORM_OUTPUT: remove_lines(druntime)
TEST_OUTPUT:
---
$r:.*makedeps_exe_$0$?:windows=.exe$: \
  $p:makedeps_exe.d$ \
  $p:makedeps_a.d$ \
  $p:makedeps-import.txt$ \
---
**/
module makedeps_exe;

// Test import statement
import imports.makedeps_a;

// Test import expression
enum text = import("makedeps-import.txt");
static assert(text == "Imported text");

void main()
{
    a_func();
}
