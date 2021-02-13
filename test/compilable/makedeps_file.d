/**
REQUIRED_ARGS: -makedeps=${RESULTS_DIR}/compilable/makedeps_file.dep -Jcompilable/extra-files
OUTPUT_FILES: ${RESULTS_DIR}/compilable/makedeps_file.dep
TRANSFORM_OUTPUT: remove_lines(druntime)
TEST_OUTPUT:
---
=== ${RESULTS_DIR}/compilable/makedeps_file.dep
$r:.*makedeps_file_$0.o$?:windows=bj$: \
  $p:makedeps_file.d$ \
  $p:makedeps_a.d$ \
  $p:makedeps-import.txt$ \
---
**/
module makedeps_file;

// Test import statement
import imports.makedeps_a;

// CTFE file selector
string selectImport(bool flag)
{
    return flag ? "nonexisting.txt" : "makedeps-import.txt";
}

enum selection = selectImport(false);

// Test CTFE import expression
enum text = import(selection);
static assert(text == "Imported text");

void func()
{
    a_func();
}
