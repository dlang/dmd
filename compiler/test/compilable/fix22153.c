// REQUIRED_ARGS: -lib
// DISABLED: wasm

// https://github.com/dlang/dmd/issues/22153


static void static_fun();

void (*funcptr)() = &static_fun;

void lib_fun()
{
	static_fun();
}

static void static_fun()
{
}
