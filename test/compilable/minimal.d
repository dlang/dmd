// PERMUTE_ARGS:
// POST_SCRIPT: compilable/extra-files/minimal/verify_symbols.sh
// REQUIRED_ARGS: -c -defaultlib= runnable/extra-files/minimal/object.d

// This test ensures an empty main built with a minimal runtime does not generate
// ModuleInfo and exception handling code

void main() { }
