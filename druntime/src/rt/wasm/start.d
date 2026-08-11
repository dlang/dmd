/**
 * WASM runtime entry point.
 *
 * `_start` runs the wasm module constructors, invokes the wasi-libc `main`
 * wrapper (which fetches argc/argv and calls the compiler-generated C `main`,
 * forwarding to `rt.dmain2._d_run_main`), then runs the destructors.  All the
 * runtime setup/teardown lives in the shared `rt.dmain2` path.
 *
 * Copyright: Copyright (C) 1999-2026 by The D Language Foundation, All Rights Reserved
 * License:   $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */
module rt.wasm.start;

nothrow:
extern (C):

private extern(C) void __wasm_call_ctors() @nogc nothrow;
private extern(C) void __wasm_call_dtors() @nogc nothrow;

private extern(C) int __main_void() nothrow;

export void _start() nothrow
{
    __wasm_call_ctors();
    initCwd();
    int rc = __main_void();
    __wasm_call_dtors();
    proc_exit(rc);
    while (true) {}
}

// WASI has no working directory of its own, a host that preopens one passes
// its path as $PWD
private void initCwd() @nogc nothrow
{
    import core.stdc.stdlib : getenv;
    if (auto pwd = getenv("PWD"))
        chdir(pwd);
}

private extern(C) int chdir(const(char)* path) @nogc nothrow;

import core.attribute : wasmImportModule;

@wasmImportModule("wasi_snapshot_preview1")
private extern(C) void proc_exit(int code) @nogc nothrow;

private extern(C) int fflush(void* stream) @nogc nothrow;

noreturn _wasm_trap(int code) @nogc nothrow
{
    fflush(null);
    proc_exit(code);
    while (true) {}
}
