// https://github.com/dlang/dmd/issues/20345
// REQUIRED_ARGS: -D -w -Dd${RESULTS_DIR}/compilable

/// Params:
void foo(int) {}

/// Params:
///     x = description
void bar(int x, int) {}
