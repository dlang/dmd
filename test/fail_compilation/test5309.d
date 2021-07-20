/**
  TEST_OUTPUT:
  ---
fail_compilation/test5309.d(14): Error: fully-qualified module name expected for `extern(D)` declaration, not `ref`
fail_compilation/test5309.d(14): Error: found `ref` when expecting `)`
fail_compilation/test5309.d(14): Error: declaration expected, not `)`
fail_compilation/test5309.d(15): Error: fully-qualified module name expected for `extern(D)` declaration, not `)`
fail_compilation/test5309.d(16): Error: fully-qualified module name expected for `extern(D)` declaration, not `,`
fail_compilation/test5309.d(16): Error: found `,` when expecting `)`
fail_compilation/test5309.d(16): Error: no identifier for declarator `foo.bar`
fail_compilation/test5309.d(16): Error: declaration expected, not `)`
  ---
 */
extern(D, ref) void invalid();
extern(D, pkg.mod.) void also();
extern(D, pkg.mod, foo.bar) void nope();
