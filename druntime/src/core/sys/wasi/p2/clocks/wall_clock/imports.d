/++

+/
module core.sys.wasi.p2.clocks.wall_clock.imports;

import core.sys.wasi.wit_common;

public import core.sys.wasi.p2.clocks.wall_clock.common;


package (core.sys.wasi.p2) void __wit_bindgen_component_type_force_link() pure @nogc nothrow => imported!"core.sys.wasi.p2.cli.imports".__wit_bindgen_component_type_force_link();

/++

+/
Datetime now() @nogc nothrow {
  align(8) void[16] _retArea = void;
  __import_now(_retArea.ptr);
  Datetime _record0 = {
    seconds: *(cast(ulong*)(_retArea.ptr + 0)),
    nanoseconds: *(cast(uint*)(_retArea.ptr + 8)),
  };
  auto _flush1 = _record0;
  return _flush1;
}
/// ditto
@wasmImport!("wasi:clocks/wall-clock@0.2.12", "now")
pragma(mangle, "__wit_import_wasi:clocks__wall_clock@0.2.12__now")
private extern(C) void __import_now(void*) @nogc nothrow;

/++

+/
Datetime resolution() @nogc nothrow {
  align(8) void[16] _retArea = void;
  __import_resolution(_retArea.ptr);
  Datetime _record0 = {
    seconds: *(cast(ulong*)(_retArea.ptr + 0)),
    nanoseconds: *(cast(uint*)(_retArea.ptr + 8)),
  };
  auto _flush1 = _record0;
  return _flush1;
}
/// ditto
@wasmImport!("wasi:clocks/wall-clock@0.2.12", "resolution")
pragma(mangle, "__wit_import_wasi:clocks__wall_clock@0.2.12__resolution")
private extern(C) void __import_resolution(void*) @nogc nothrow;
