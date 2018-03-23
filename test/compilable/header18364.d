// REQUIRED_ARGS: -o- -Hf${RESULTS_DIR}/compilable/header18364.di
// POST_SCRIPT: compilable/extra-files/header-postscript.sh header18364
module foo.bar.ba;
@safe pure nothrow @nogc package(foo):
void foo();

@safe pure nothrow @nogc package(foo.bar):
void foo2();
