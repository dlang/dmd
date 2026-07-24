/++

+/
module core.sys.wasi.p2.cli.stderr.imports;

import core.sys.wasi.wit_common;

public import core.sys.wasi.p2.cli.stderr.common;

static import core.sys.wasi.p2.io.streams.imports;

package (core.sys.wasi.p2) void __wit_bindgen_component_type_force_link() pure @nogc nothrow => imported!"core.sys.wasi.p2.cli.imports".__wit_bindgen_component_type_force_link();

/++

+/
alias OutputStream = core.sys.wasi.p2.io.streams.imports.OutputStream;

/++

+/
OutputStream getStderr() @nogc nothrow {
  auto _ret = __import_getStderr();
  return OutputStream(_ret);
}
/// ditto
@wasmImport!("wasi:cli/stderr@0.2.12", "get-stderr")
pragma(mangle, "__wit_import_wasi:cli__stderr@0.2.12__get_stderr")
private extern(C) uint __import_getStderr() @nogc nothrow;
