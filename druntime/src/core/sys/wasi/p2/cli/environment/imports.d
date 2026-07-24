/++

+/
module core.sys.wasi.p2.cli.environment.imports;

import core.sys.wasi.wit_common;

public import core.sys.wasi.p2.cli.environment.common;


package (core.sys.wasi.p2) void __wit_bindgen_component_type_force_link() pure @nogc nothrow => imported!"core.sys.wasi.p2.cli.imports".__wit_bindgen_component_type_force_link();

/++
Get the POSIX-style environment variables.

Each environment variable is provided as a pair of string variable names
and string value.

Morally, these are a value import, but until value imports are available
in the component model, this import function should return the same
values each time it is called.
+/
WitList!(Tuple!(WitString, WitString)) getEnvironment() @nogc nothrow {
  align(size_t.sizeof) void[(2*size_t.sizeof)] _retArea = void;
  __import_getEnvironment(_retArea.ptr);
  auto _listSrcPtr4 = *(cast(void**)(_retArea.ptr + 0));
  auto _listLen4 = *(cast(size_t*)(_retArea.ptr + size_t.sizeof));
  auto _list4 = core.sys.wasi.wit_common.mallocSlice!(Tuple!(WitString, WitString))(_listLen4);
  foreach (_elem0_idx, ref _elem0; _list4) {
    const auto _base0 = _listSrcPtr4 + _elem0_idx * (4*size_t.sizeof);
    auto _ptr1 = cast(char*)(*(cast(void**)(_base0 + 0)));
    auto _len1 = *(cast(size_t*)(_base0 + size_t.sizeof));
    auto _ptr2 = cast(char*)(*(cast(void**)(_base0 + (2*size_t.sizeof))));
    auto _len2 = *(cast(size_t*)(_base0 + (3*size_t.sizeof)));
    auto _tuple3 = Tuple!(WitString, WitString)(
    WitString(_ptr1[0.._len1]),
    WitString(_ptr2[0.._len2]),
    );
    _elem0 = _tuple3;
  }
  auto _flush5 = WitList!(Tuple!(WitString, WitString))(_list4);
  return _flush5;
}
/// ditto
@wasmImport!("wasi:cli/environment@0.2.12", "get-environment")
pragma(mangle, "__wit_import_wasi:cli__environment@0.2.12__get_environment")
private extern(C) void __import_getEnvironment(void*) @nogc nothrow;

/++
Get the POSIX-style arguments to the program.
+/
WitList!(WitString) getArguments() @nogc nothrow {
  align(size_t.sizeof) void[(2*size_t.sizeof)] _retArea = void;
  __import_getArguments(_retArea.ptr);
  auto _listSrcPtr2 = *(cast(void**)(_retArea.ptr + 0));
  auto _listLen2 = *(cast(size_t*)(_retArea.ptr + size_t.sizeof));
  auto _list2 = core.sys.wasi.wit_common.mallocSlice!(WitString)(_listLen2);
  foreach (_elem0_idx, ref _elem0; _list2) {
    const auto _base0 = _listSrcPtr2 + _elem0_idx * (2*size_t.sizeof);
    auto _ptr1 = cast(char*)(*(cast(void**)(_base0 + 0)));
    auto _len1 = *(cast(size_t*)(_base0 + size_t.sizeof));
    _elem0 = WitString(_ptr1[0.._len1]);
  }
  auto _flush3 = WitList!(WitString)(_list2);
  return _flush3;
}
/// ditto
@wasmImport!("wasi:cli/environment@0.2.12", "get-arguments")
pragma(mangle, "__wit_import_wasi:cli__environment@0.2.12__get_arguments")
private extern(C) void __import_getArguments(void*) @nogc nothrow;

/++
Return a path that programs should use as their initial current working
directory, interpreting `.` as shorthand for this.
+/
Option!(WitString) initialCwd() @nogc nothrow {
  align(size_t.sizeof) void[(3*size_t.sizeof)] _retArea = void;
  __import_initialCwd(_retArea.ptr);
  Option!(WitString) _option3 = void;
  bool _isSome3 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
  if (_isSome3) {
    auto _ptr2 = cast(char*)(*(cast(void**)(_retArea.ptr + size_t.sizeof)));
    auto _len2 = *(cast(size_t*)(_retArea.ptr + (2*size_t.sizeof)));

    _option3 = Option!(WitString).some(WitString(_ptr2[0.._len2]));
  } else {
    _option3 = Option!(WitString).none;
  }
  auto _flush4 = _option3;
  return _flush4;
}
/// ditto
@wasmImport!("wasi:cli/environment@0.2.12", "initial-cwd")
pragma(mangle, "__wit_import_wasi:cli__environment@0.2.12__initial_cwd")
private extern(C) void __import_initialCwd(void*) @nogc nothrow;
