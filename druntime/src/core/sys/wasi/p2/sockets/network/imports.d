/++

+/
module core.sys.wasi.p2.sockets.network.imports;

import core.sys.wasi.wit_common;

public import core.sys.wasi.p2.sockets.network.common;

static import core.sys.wasi.p2.io.error.imports;

package (core.sys.wasi.p2) void __wit_bindgen_component_type_force_link() pure @nogc nothrow => imported!"core.sys.wasi.p2.cli.imports".__wit_bindgen_component_type_force_link();

/++

+/
alias Error_ = core.sys.wasi.p2.io.error.imports.Error_;

/++

+/
struct Network {
  @nogc nothrow:

  package(core.sys.wasi.p2) uint __handle = 0;

  package(core.sys.wasi.p2) this(uint handle) {
    __handle = handle;
  }

  @disable this();


  void drop() {
    __import_drop(__handle);
  }
  @wasmImport!("wasi:sockets/network@0.2.12", "[resource-drop]network")
  pragma(mangle, "__wit_import_wasi:sockets__network@0.2.12__:resource_drop:network")
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
  }
}

/++

+/
Option!(ErrorCode) networkErrorCode(in Error_.Borrow err) @nogc nothrow {
  align(1) void[2] _retArea = void;
  __import_networkErrorCode(err.__handle, _retArea.ptr);
  Option!(ErrorCode) _option2 = void;
  bool _isSome2 = (cast(uint)(*(cast(ubyte*)(_retArea.ptr + 0)))) != 0;
  if (_isSome2) {

    _option2 = Option!(ErrorCode).some(cast(ErrorCode)(cast(uint)(*(cast(ubyte*)(_retArea.ptr + 1)))));
  } else {
    _option2 = Option!(ErrorCode).none;
  }
  auto _flush3 = _option2;
  return _flush3;
}
/// ditto
@wasmImport!("wasi:sockets/network@0.2.12", "network-error-code")
pragma(mangle, "__wit_import_wasi:sockets__network@0.2.12__network_error_code")
private extern(C) void __import_networkErrorCode(uint, void*) @nogc nothrow;
