/*
PERMUTE_ARGS:
REQUIRED_ARGS: -deps
EXTRA_SOURCES: imports/depsOutput9948a.d imports/depsOutput9948b.d
TRANSFORM_OUTPUT: remove_lines("druntime")
TEST_OUTPUT:
---
depsImport depsOutput9948 (compilable$?:windows=\\|/$depsOutput9948.d) : private : imports.depsOutput9948a (compilable$?:windows=\\|/$imports$?:windows=\\|/$depsOutput9948a.d)
depsImport depsOutput9948 (compilable$?:windows=\\|/$depsOutput9948.d) : private : imports.depsOutput9948b (compilable$?:windows=\\|/$imports$?:windows=\\|/$depsOutput9948b.d)
---
*/

module depsOutput9948;

import imports.depsOutput9948a;

void main()
{
   templateFunc!(q{
      import imports.depsOutput9948b;
      foo();
   })();
}
