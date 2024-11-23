/*
REQUIRED_ARGS: -de
EXTRA_FILES: imports/deprecatedImporta.d imports/deprecatedImportb.d

TEST_OUTPUT:
----
fail_compilation/deprecatedImports.d(33): Deprecation: alias `deprecatedImporta.foo` is deprecated - Please import deprecatedImportb directly!
alias f = foo;
          ^
fail_compilation/deprecatedImports.d(35): Deprecation: alias `deprecatedImporta.bar` is deprecated - Please import deprecatedImportb directly!
alias b = bar!(int);
          ^
fail_compilation/deprecatedImports.d(37): Deprecation: alias `deprecatedImporta.AliasSeq` is deprecated - Please import deprecatedImportb directly!
alias Types = AliasSeq!(int);
              ^
fail_compilation/deprecatedImports.d(41): Deprecation: alias `deprecatedImporta.S` is deprecated - Please import deprecatedImportb directly!
S s;
  ^
fail_compilation/deprecatedImports.d(43): Deprecation: alias `deprecatedImporta.C` is deprecated - Please import deprecatedImportb directly!
C c;
  ^
fail_compilation/deprecatedImports.d(45): Deprecation: alias `deprecatedImporta.I` is deprecated - Please import deprecatedImportb directly!
I i;
  ^
fail_compilation/deprecatedImports.d(39): Deprecation: alias `deprecatedImporta.E` is deprecated - Please import deprecatedImportb directly!
int x = E;
        ^
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
