/*
REQUIRED_ARGS: -de
EXTRA_FILES: imports/deprecatedImporta.d imports/deprecatedImportb.d

TEST_OUTPUT:
----
fail_compilation/deprecatedImports.d(26): Deprecation: alias `deprecatedImporta.foo` is deprecated - Please import deprecatedImportb directly!
fail_compilation/imports/deprecatedImporta.d(2):        `foo` is declared here
fail_compilation/deprecatedImports.d(28): Deprecation: alias `deprecatedImporta.bar` is deprecated - Please import deprecatedImportb directly!
fail_compilation/imports/deprecatedImporta.d(2):        `bar` is declared here
fail_compilation/deprecatedImports.d(30): Deprecation: alias `deprecatedImporta.AliasSeq` is deprecated - Please import deprecatedImportb directly!
fail_compilation/imports/deprecatedImporta.d(2):        `AliasSeq` is declared here
fail_compilation/deprecatedImports.d(34): Deprecation: alias `deprecatedImporta.S` is deprecated - Please import deprecatedImportb directly!
fail_compilation/imports/deprecatedImporta.d(2):        `S` is declared here
fail_compilation/deprecatedImports.d(36): Deprecation: alias `deprecatedImporta.C` is deprecated - Please import deprecatedImportb directly!
fail_compilation/imports/deprecatedImporta.d(2):        `C` is declared here
fail_compilation/deprecatedImports.d(38): Deprecation: alias `deprecatedImporta.I` is deprecated - Please import deprecatedImportb directly!
fail_compilation/imports/deprecatedImporta.d(2):        `I` is declared here
fail_compilation/deprecatedImports.d(32): Deprecation: alias `deprecatedImporta.E` is deprecated - Please import deprecatedImportb directly!
fail_compilation/imports/deprecatedImporta.d(2):        `E` is declared here
----
*/

import imports.deprecatedImporta;

alias f = foo;

alias b = bar!(int);

alias Types = AliasSeq!(int);

int x = E;

S s;

C c;

I i;
