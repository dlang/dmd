/++

+/
module core.sys.wasi.p2.io.error.imports;

import core.sys.wasi.wit_common;

public import core.sys.wasi.p2.io.error.common;


package (core.sys.wasi.p2) void __wit_bindgen_component_type_force_link() pure @nogc nothrow => imported!"core.sys.wasi.p2.cli.imports".__wit_bindgen_component_type_force_link();

/++

+/
struct Error_ {
  @nogc nothrow:

  package(core.sys.wasi.p2) uint __handle = 0;

  package(core.sys.wasi.p2) this(uint handle) {
    __handle = handle;
  }

  @disable this();


  void drop() {
    __import_drop(__handle);
  }
  @wasmImport!("wasi:io/error@0.2.12", "[resource-drop]error")
  pragma(mangle, "__wit_import_wasi:io__error@0.2.12__:resource_drop:error")
  static private extern(C) void __import_drop(uint);

  alias witFree = drop;
  // TODO: make RAII? disable copy for the own

  Borrow borrow() => Borrow(__handle);
  alias borrow this;

  struct Borrow {
    @nogc nothrow:

    package(core.sys.wasi.p2) uint __handle = 0;

    package(core.sys.wasi.p2) this(uint handle) {
      __handle = handle;
    }

    @disable this();

    void witFree() {}
    Borrow witClone() const { return Borrow(__handle); }

    /++

    +/
    WitString toDebugString() @nogc nothrow {
      align(size_t.sizeof) void[(2*size_t.sizeof)] _retArea = void;
      __import_toDebugString(this.__handle, _retArea.ptr);
      auto _ptr0 = cast(char*)(*(cast(void**)(_retArea.ptr + 0)));
      auto _len0 = *(cast(size_t*)(_retArea.ptr + size_t.sizeof));
      auto _flush1 = WitString(_ptr0[0.._len0]);
      return _flush1;
    }
    /// ditto
    @wasmImport!("wasi:io/error@0.2.12", "[method]error.to-debug-string")
    pragma(mangle, "__wit_import_wasi:io__error@0.2.12__:method:error.to_debug_string")
    static private extern(C) void __import_toDebugString(uint, void*) @nogc nothrow;
  }
}
