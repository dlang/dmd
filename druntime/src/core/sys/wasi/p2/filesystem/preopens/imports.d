/++

+/
module core.sys.wasi.p2.filesystem.preopens.imports;

import core.sys.wasi.wit_common;

public import core.sys.wasi.p2.filesystem.preopens.common;

static import core.sys.wasi.p2.filesystem.types.imports;

package (core.sys.wasi.p2) void __wit_bindgen_component_type_force_link() pure @nogc nothrow => imported!"core.sys.wasi.p2.cli.imports".__wit_bindgen_component_type_force_link();

/++

+/
alias Descriptor = core.sys.wasi.p2.filesystem.types.imports.Descriptor;

/++

+/
WitList!(Tuple!(Descriptor, WitString)) getDirectories() @nogc nothrow {
  align(size_t.sizeof) void[(2*size_t.sizeof)] _retArea = void;
  __import_getDirectories(_retArea.ptr);
  auto _listSrcPtr3 = *(cast(void**)(_retArea.ptr + 0));
  auto _listLen3 = *(cast(size_t*)(_retArea.ptr + size_t.sizeof));
  auto _list3 = core.sys.wasi.wit_common.mallocSlice!(Tuple!(Descriptor, WitString))(_listLen3);
  foreach (_elem0_idx, ref _elem0; _list3) {
    const auto _base0 = _listSrcPtr3 + _elem0_idx * (3*size_t.sizeof);
    auto _ptr1 = cast(char*)(*(cast(void**)(_base0 + size_t.sizeof)));
    auto _len1 = *(cast(size_t*)(_base0 + (2*size_t.sizeof)));
    auto _tuple2 = Tuple!(Descriptor, WitString)(
    Descriptor(*(cast(uint*)(_base0 + 0))),
    WitString(_ptr1[0.._len1]),
    );
    _elem0 = _tuple2;
  }
  auto _flush4 = WitList!(Tuple!(Descriptor, WitString))(_list3);
  return _flush4;
}
/// ditto
@wasmImport!("wasi:filesystem/preopens@0.2.12", "get-directories")
pragma(mangle, "__wit_import_wasi:filesystem__preopens@0.2.12__get_directories")
private extern(C) void __import_getDirectories(void*) @nogc nothrow;
