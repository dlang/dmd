// DFLAGS:
// PERMUTE_ARGS:
// POST_SCRIPT: compilable/extra-files/minimal/verify_symbols.sh
// REQUIRED_ARGS: -defaultlib= runnable/extra-files/minimal/object.d

// This test ensures an empty main with a struct, built with a minimal runtime,
// does not generate ModuleInfo or exception handling code, and does not
// require TypeInfo

struct S { }

void main() { }
