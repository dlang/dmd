/*
PERMUTE_ARGS:
REQUIRED_ARGS: -deps -Jcompilable/imports
EXTRA_SOURCES: imports/depsOutput21238_bar.d imports/depsOutput21238_baz_moduleimport.d imports/depsOutput21238_baz_stringimport.d imports/depsOutput21238_qux.d
TRANSFORM_OUTPUT: remove_lines("druntime")
TEST_OUTPUT:
---
depsImport depsOutput21238_foo (compilable$?:windows=\\|/$depsOutput21238_foo.d) : private : imports.depsOutput21238_baz_moduleimport (compilable$?:windows=\\|/$imports$?:windows=\\|/$depsOutput21238_baz_moduleimport.d)
depsImport imports.depsOutput21238_baz_moduleimport (compilable$?:windows=\\|/$imports$?:windows=\\|/$depsOutput21238_baz_moduleimport.d) : private : imports.depsOutput21238_qux (compilable$?:windows=\\|/$imports$?:windows=\\|/$depsOutput21238_qux.d)
depsImport depsOutput21238_foo (compilable$?:windows=\\|/$depsOutput21238_foo.d) : private : imports.depsOutput21238_baz_stringimport (compilable$?:windows=\\|/$imports$?:windows=\\|/$depsOutput21238_baz_stringimport.d)
depsFile imports.depsOutput21238_baz_stringimport (compilable$?:windows=\\|/$imports$?:windows=\\|/$depsOutput21238_baz_stringimport.d) : depsOutput21238_qux.d $r:\(.*depsOutput21238_qux.d\)$
depsImport depsOutput21238_foo (compilable$?:windows=\\|/$depsOutput21238_foo.d) : private : imports.depsOutput21238_baz_cond (compilable$?:windows=\\|/$imports$?:windows=\\|/$depsOutput21238_baz_cond.d)
depsVersion imports.depsOutput21238_baz_cond (compilable$?:windows=\\|/$imports$?:windows=\\|/$depsOutput21238_baz_cond.d) : qux
depsImport depsOutput21238_foo (compilable$?:windows=\\|/$depsOutput21238_foo.d) : private : imports.depsOutput21238_baz_pragmalib (compilable$?:windows=\\|/$imports$?:windows=\\|/$depsOutput21238_baz_pragmalib.d)
depsLib imports.depsOutput21238_baz_pragmalib (compilable$?:windows=\\|/$imports$?:windows=\\|/$depsOutput21238_baz_pragmalib.d) : qux
depsImport imports.depsOutput21238_bar (compilable$?:windows=\\|/$imports$?:windows=\\|/$depsOutput21238_bar.d) : private : imports.depsOutput21238_baz_moduleimport (compilable$?:windows=\\|/$imports$?:windows=\\|/$depsOutput21238_baz_moduleimport.d)
depsImport imports.depsOutput21238_bar (compilable$?:windows=\\|/$imports$?:windows=\\|/$depsOutput21238_bar.d) : private : imports.depsOutput21238_baz_stringimport (compilable$?:windows=\\|/$imports$?:windows=\\|/$depsOutput21238_baz_stringimport.d)
depsImport imports.depsOutput21238_bar (compilable$?:windows=\\|/$imports$?:windows=\\|/$depsOutput21238_bar.d) : private : imports.depsOutput21238_baz_cond (compilable$?:windows=\\|/$imports$?:windows=\\|/$depsOutput21238_baz_cond.d)
depsImport imports.depsOutput21238_bar (compilable$?:windows=\\|/$imports$?:windows=\\|/$depsOutput21238_bar.d) : private : imports.depsOutput21238_baz_pragmalib (compilable$?:windows=\\|/$imports$?:windows=\\|/$depsOutput21238_baz_pragmalib.d)
---
*/

module depsOutput21238_foo;

import imports.depsOutput21238_baz_moduleimport;
alias x_moduleimport = t_moduleimport!();

import imports.depsOutput21238_baz_stringimport;
alias x_stringimport = t_stringimport!();

import imports.depsOutput21238_baz_cond;
alias x_cond = t_cond!();

import imports.depsOutput21238_baz_pragmalib;
alias x_pragmalib = t_pragmalib!();
