/++

+/
module core.sys.wasi.p2.cli.stdout.imports;

import core.sys.wasi.wit_common;

public import core.sys.wasi.p2.cli.stdout.common;

static import core.sys.wasi.p2.io.streams.imports;

package (core.sys.wasi.p2) void __wit_bindgen_component_type_force_link() pure @nogc nothrow => imported!"core.sys.wasi.p2.cli.imports".__wit_bindgen_component_type_force_link();

/++

+/
alias OutputStream = core.sys.wasi.p2.io.streams.imports.OutputStream;

/++

+/
OutputStream getStdout() @nogc nothrow {
  auto _ret = __import_getStdout();
  return OutputStream(_ret);
}
/// ditto
@wasmImport!("wasi:cli/stdout@0.2.12", "get-stdout")
pragma(mangle, "__wit_import_wasi:cli__stdout@0.2.12__get_stdout")
private extern(C) uint __import_getStdout() @nogc nothrow;
